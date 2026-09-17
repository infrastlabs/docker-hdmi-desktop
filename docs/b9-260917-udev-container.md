# b9-260917 | 容器内 udev 热插拔感知与调试（Netlink 隔离 + 排查流程）

> 主题：容器内的 udev 如何感知宿主机热插拔事件；`--net=host` / `/run/udev` 挂载 / `--privileged` 三者作用与取舍；udev → Xorg 两层排查步骤。文末附本项目（docker-hdmi-desktop）现状对照。

## 一、核心原理：Netlink 与网络命名空间

- uevents 经内核 Netlink 套接字（`NETLINK_KOBJECT_UEVENT`）广播，内核**只会把事件发送到同一网络命名空间内的监听者**
- 容器默认独立网络命名空间 → 宿主机热插拔事件无法"穿透"到容器内
- 要让容器内 udev 收到 uevent，必须共享网络命名空间（或通过其它机制转发）

## 二、主流配置方案

### 1 共享网络命名空间（--net=host）

最直接，容器直接用宿主机网络栈，即可监听同一 Netlink 套接字：

```bash
docker run --net=host \
  -v /run/udev/control:/run/udev/control \
  ...
```

- **关键挂载 `/run/udev/control`**：udev monitor 用它检查 udevd 是否运行；不挂载则监控功能被禁用
- 注意：`--net=host` 只解决 Netlink 可达性，设备节点还需 `/dev` 直通

### 2 挂载必要目录并修改启动脚本（保持网络隔离）

若要保持网络隔离：

- 挂载 `/run/udev/`（或至少 control 文件）
- 编辑容器内 `/etc/init.d/udev`，注释掉检测容器环境的代码块（如提示 "udev does not support containers" 的部分），确保 `/run/udev/` 存在

### 3 使用特权模式（谨慎）

`--privileged` 可绕过大部分隔离，使 udev 访问所有设备与 Netlink。安全风险高，生产环境不建议。

## 三、替代方案与注意事项（容器友好的 udev 方案全景）

### 1 容器运行时集成方案（宿主机侧接管，最成熟）

#### 1.1 LXD/Incus unix-hotplug

容器配置指定 vendor/product ID，设备在宿主机出现/消失时 LXD 自动添加/移除到容器——最优雅、隔离性好

#### 1.2 container-hotplug

包装 runc，监听宿主 udev 事件，直接操作容器 cgroup 动态授予/撤销设备访问权限；支持 Docker/Podman/K8s

#### 1.3 Proxmox VE

LXC 容器已实现设备热插拔，可向运行中容器添加设备

#### 1.4 宿主机转发守护进程

宿主监听原始 uevent，按策略转发到指定容器网络命名空间，通常需内核支持（如 kobject_uevent_forward 补丁）

### 2 用户空间设备管理器（容器内轻量替代 udevd）

#### 2.1 vdev

即插即用 udev 替代品，容器友好；提供 libudev-compat 兼容库（依赖 libudev 的软件免重编译），支持每进程独立 /dev 视图、精细访问控制

#### 2.2 rust_udev

Rust 编写的简化 udev，不依赖 systemd/原生 udev，事件监听 + 规则响应，适用容器与嵌入式

#### 2.3 dumb-udev

极简 Python 工具，容器内替代 udevd，主要桥接键盘鼠标等输入设备——**非完整 udevd 替代品**

### 3 兼容库与变体

#### 3.1 eudev

systemd-udev 分支（详见 b8 文档），但启动脚本含容器检测，默认容器内不启动，需改脚本强跑

#### 3.2 libudev-zero

libudev 的直接替代品（drop-in），可与任何设备管理器协作，用于替换容器内对 libudev 的依赖

### 4 安全与兼容注意

- 共享网络栈/特权模式削弱隔离；部分发行版 udev 启动脚本会检测容器环境并拒绝启动，需相应修改

> 总结：简单场景 `--net=host` + 挂载 `/run/udev/control` 最快；重安全场景优先 unix-hotplug / container-hotplug；容器内需完整设备管理能力 → vdev / rust_udev；仅替换 libudev 依赖 → libudev-zero。

## 四、容器内 udev 层排查（udevadm 三板斧）

### 1 确认 udev 服务与关键文件

- `ps aux | grep udev`：确认 systemd-udevd / eudev 进程存在
- `ls -l /run/udev/control`：udevadm monitor 检查 udevd 是否运行的关键；缺失则监控被禁用

### 2 udevadm monitor 实时监控（最核心）

```bash
udevadm monitor --kernel --udev   # KERNEL=内核事件, UDEV=udev 处理后事件
```

容器内执行后插拔 USB 设备，三种结果对应三种定位：

| 输出 | 结论 | 下一步 |
|------|------|--------|
| 无任何输出 | 容器收不到内核 Netlink uevent | 检查是否 --net=host + --privileged |
| 只有 KERNEL，无 UDEV | 内核事件到达但 udevd 未处理 | 查 /run/udev/control 是否存在 |
| 有 UDEV 事件 | udev 层正常 | 转向 Xorg 层排查 |

> 若显示 `The udev service seems not to be active, disabling the monitor.` → 即 control 文件缺失。

### 3 udevadm info 查询设备属性

```bash
udevadm info --query=all --name=/dev/input/event5
```

重点关注 `ID_INPUT=1`、`ID_INPUT_KEYBOARD=1`、`ID_INPUT_MOUSE=1`——Xorg 识别设备类型的关键标签。

## 五、Xorg 层排查

### 1 确认 udev 后端启用

检查 `xorg.conf` / `xorg.conf.d/`，确认没有禁用 `AutoAddDevices` / `AutoEnableDevices`。

### 2 xinput list 观察设备列表

```bash
xinput list   # 插拔前后各跑一次，对比设备列表
```

列表不变 → Xorg 没收到 udev 设备添加事件。

### 3 xinput test-xi2 事件级调试

```bash
xinput list          # 找到设备 ID
xinput test-xi2 <id> # 实时打印该设备事件
```

有输出 → Xorg 已识别并处理该设备。

### 4 Xorg 日志

`/var/log/Xorg.0.log` 或 `~/.local/share/xorg/Xorg.0.log`，搜 udev / input 相关行。

## 六、容器配置修正要点

推荐启动命令（宿主 udevd 转发场景）：

```bash
docker run --net=host --privileged \
  -v /run/udev:/run/udev \           # 关键：udev 运行时目录
  -v /dev:/dev \                     # 设备节点可见
  -v /tmp/.X11-unix:/tmp/.X11-unix \ # 如需 X11 套接字
  -e DISPLAY=$DISPLAY ...
```

**为什么必须挂 /run/udev**：`/run/udev/control` 是 udev 监控机制"开关"；缺失时 `udevadm monitor` 直接禁用，Xorg 的 udev 后端也依赖此路径获取设备信息。

### 1 排查顺序建议

1. 修正配置：确保挂载 /run/udev
2. 验证 udev：`udevadm monitor` 插拔测试，确认 KERNEL + UDEV 事件；`udevadm info` 查 ID_INPUT
3. 验证 Xorg：`xinput list` 看插拔变化；功能异常再 `xinput test-xi2 <id>`
4. 查日志：Xorg 日志 + `dmesg` 找 udev / 输入设备错误

## 七、Docker Compose 热插拔配置（privileged + bind + rshared）

### 1 配置示例

```yaml
version: '3.8'
services:
  your-app:
    image: your-image:latest
    privileged: true          # 关键：/sys 默认只读，udev 需写 /sys/devices/*/uevent 触发事件处理
    volumes:
      - type: bind            # 挂整个 /dev 而非单节点（热插拔会分配新次设备号，静态映射失效）
        source: /dev
        target: /dev
        bind:
          propagation: rshared # 关键：挂载事件双向递归传播（宿主↔容器）
      - type: bind            # /sys 供 udev 获取设备属性
        source: /sys
        target: /sys
        bind:
          propagation: rshared
    network_mode: host
    restart: always
    # 替代 privileged 的精细授权（compose 版本需 ≥2.3）
    # device_cgroup_rules:
    #   - 'c 188:* rmw'   # ttyUSB*（USB 串口主设备号 188）
    #   - 'c 166:* rmw'   # ttyACM*（主设备号 166）
```

### 2 Compose 语法（长/短/流式）

#### 2.1 version: '2.4'

rshared 依赖 Compose 格式 ≥2.3，本项目 `docker-compose.yml:1` 即 2.4 ✅

#### 2.2 长语法（推荐）

`propagation` 必须写在 `bind:` 块内；写进 `volume:` 块会报 `volume options are incompatible with type bind`

#### 2.3 短语法

路径末尾加 `:rshared`，如 `/dev:/dev:rshared`、`/sys:/sys:rshared`；同时要 SELinux 标签可写 `/dev:/dev:rshared,z`

#### 2.4 流式映射（一行版长语法）

```yaml
volumes:
  - { type: bind, source: /dev, target: /dev, bind: { propagation: rshared } }
  - { type: bind, source: /sys, target: /sys, bind: { propagation: rshared } }
```

> 流式映射里冒号后保留空格避免 YAML 解析歧义；缩进与同级 volumes 列表项一致。

### 3 关键配置详解

#### 3.1 privileged: true

Docker 默认只读挂载 /sys，而 udev 需要写 `/sys/devices/*/uevent` 触发设备事件处理——热插拔的必要条件

#### 3.2 挂载整个 /dev 目录

不要用 `devices:` 映射单节点；USB 热插拔后内核可能分配新的次设备号，静态映射会失效

#### 3.3 propagation: rshared

挂载事件双向递归传播——宿主新增节点容器内及时可见，容器内变化也传回宿主

#### 3.4 device_cgroup_rules

不想用 privileged 时的精细方案，基于主设备号 + 通配 `*` 动态授权（`c` 字符设备 / `b` 块设备 / `rwm` 读-写-创建设备节点；compose ≥2.3 支持）

### 4 注意事项

#### 4.1 安全

privileged 禁用 seccomp/AppArmor 等机制，接近宿主机 root；生产优先 device_cgroup_rules 或受控环境

#### 4.2 /run/udev 挂载与两条路线互斥

容器内独立跑 systemd-udevd 时**不应**挂 /run/udev（双 udev 实例争抢状态数据库）；无独立 udevd 时可挂载与宿主 udevd 通信（详见第九节）

#### 4.3 宿主侧也要 rshared

Compose 的 rshared 只控制容器内传播；要让宿主的挂载事件（新 USB 节点）传播进容器，宿主 /dev、/sys 本身须为 shared/rshared：
  - 检查：`findmnt -T /dev -o PROPAGATION`
  - 非 shared/rshared 时：`mount --make-rshared /dev`

#### 4.4 privileged 依然需要

无论长短/流式语法，容器内 udev 与 Xorg 正常工作仍需特权模式

#### 4.5 Windows 兼容

`propagation: rshared` 仅 Linux 有效，Windows 上报错

## 八、设备授权：--device 静态绑定 vs --device-cgroup-rule 动态授权

### 1 为何 --device 无法应对热插拔

`--device` 把**启动时已存在**的设备节点映射进容器（如 /dev/ttyUSB0），是**静态绑定**：绑定创建时的主/次设备号。拔插后内核很可能分配新次设备号，容器启动时基于旧设备号建立的权限规则失效 → 设备在容器内不可用。

### 2 --device-cgroup-rule 的原理

为动态设备设计，基于**主设备号 + 类型**制定规则，次设备号用通配符 `*` 匹配：

```bash
docker run --device-cgroup-rule='c 188:* rwm' ...
```

它直接修改容器所属的 **device cgroup**："允许访问所有主设备号为 X 的设备，无论次设备号多少"。USB 无论拿到什么新次设备号，容器都能动态获得访问权限。

### 3 Kubernetes 场景

Pod `securityContext` 无法直接用 --device-cgroup-rule；需 `privileged: true`（不推荐）或 Device Plugin；社区工具（如 container-hotplug）监听 udev 事件动态更新容器 cgroup 授权。

### 4 与 --privileged 的关系

- privileged 自动授予访问**所有**设备权限 → 已用 privileged 则无需再配 --device-cgroup-rule
- 安全对比：--device-cgroup-rule 把授权限定在特定设备类型，比 privileged 更安全

## 九、两条互斥路线（二选一，勿混用）

### 1 路线一（推荐/标准做法）：容器内不跑 udevd，挂载宿主机 /run/udev

- 操作：容器内停止并禁用 systemd-udevd（本项目即 x2-udev），挂载 `/run/udev` 目录
- Xorg 直接与宿主机 udevd 通信，稳定性最高（官方标准做法）

### 2 路线二：保留容器内独立 udevd，不挂 /run/udev

- 前提：必须挂载 /dev 和 /sys，并给予足够权限（--privileged 或特定 --device-cgroup-rule）
- 代价：接受容器与宿主机设备视图可能不一致的风险，且需保证容器内 udevd 正常工作

### 3 为何不能同时挂载（容器内 udevd 存在时）

#### 3.1 双守护进程争抢控制权

容器内 udevd 启动时管理 /dev 节点，若再挂宿主 /run/udev，会试图写入宿主机状态数据库 → 数据库损坏、规则执行混乱，甚至影响宿主稳定性

#### 3.2 数据库版本兼容性风险

容器与宿主 libudev/udevd 版本很可能不同，客户端读到不兼容数据库 → 难以排查的故障

#### 3.3 官方不支持

udev 非为容器环境设计，--privileged 强跑属非标准操作

### 4 路线二调试步骤（保留容器内 udevd）

1. 确认 udevd 运行：`ps aux | grep udevd`；未运行则手动 `systemd-udevd --debug &` 观察
2. 内核事件：`udevadm monitor --kernel`，插拔必须有 `KERNEL[...] add /devices/...`；没有 → 容器收不到 uevent（查 --net=host）
3. 用户空间事件：`udevadm monitor --udev`，应有 `UDEV[...]` 事件；只有 KERNEL 无 UDEV → 容器内 udevd 未处理
4. 属性：`udevadm info --query=all --name=/dev/input/eventX`，确认 ID_INPUT / ID_INPUT_KEYBOARD / ID_INPUT_MOUSE
5. Xorg：`xinput list` 看插拔变化；功能异常再 `xinput test-xi2 <id>`
6. 日志：`/var/log/Xorg.0.log` 搜 udev / input

### 5 容器内强跑 udev 的七大问题（路线二风险清单）

容器内 udevd 与隔离机制的根本冲突（udev 假设自己是宿主唯一设备管理守护进程，需要全局 /sys、/dev、IPC 命名空间）：

1. **进程风暴/资源耗尽**：多特权容器同时跑 udev 时各自处理全系统事件；实测两个容器启动时 systemd-udevd 进程数从 2 暴增到 146，CPU/内存瞬时高压
2. **IPC 命名空间死锁**：libdevmapper（LVM/cryptsetup 依赖）创建 System V 信号量与 udevd 同步；容器独立 IPC 命名空间 → 宿主 udevd 看不到容器内信号量，`semop()` 永久阻塞，cryptsetup luksOpen/luksClose 挂起
3. **用户命名空间破坏事件接收**：`--userns=keep-id` 下宿主 root 映射为 overflowuid(65534)，libudev 内部检测拒绝所有宿主事件（日志 `Sender uid=65534, message ignored`）→ 热插拔完全失效
4. **设备节点/挂载点竞争**：mdadm 组装 RAID 时 sysfs_add_disk 前的 change 事件可能把设备错误加入多个容器；udev 规则建的稳定符号链接（如 /dev/myCustomLink）重插后容器内挂载点仍指旧节点，实际设备已换 → 容器内访问不到
5. **权限不足**：即使 --privileged 也非全部权限，容器内 `udevadm trigger` 常因缺 CAP_SYS_ADMIN 失败，导致依赖它的安装后脚本中断
6. **系统不稳定/网络风险**：容器网络命名空间内设备改名而 sysfs 未同步 → systemd-udevd 收到混乱事件，systemd 可能禁用无关设备（如 eth0）导致容器断网；多容器都监听全局 sysfs，任一 uevent 触发所有容器 udev 活动，拖累整体性能
7. **安全漏洞**：内核无"设备命名空间"，容器内 mknod 直接危及宿主；允许写 /sys 打开巨大漏洞（/sys 只读是重要安全边界）；挂宿主 /run/udev 或 /dev 泄露整个设备清单给攻击者

> 结论：官方与最佳实践强烈建议**不要在容器内运行 udev**，让容器内进程直接与宿主 udev 协作，或走 unix-hotplug 等机制。

## 十、进程风暴机制拆解（udev-worker 与 children-max）

"七大问题"第 1 条的机制细节，基于 systemd 源码（`src/udev/udevd.c` 的 `event_run()` / `worker_spawn()`）。

### 1 多出来的进程是什么

#### 1.1 架构

`systemd-udevd` 是 1 个主守护进程（监听 netlink），每个 uevent 交给一个 **worker 进程**处理，主进程按需 fork worker，上限 `children-max`

#### 1.2 进程名

主进程显示为 `systemd-udevd`；fork 出的 worker 会 rename 成 **`udev-worker`**（内核 OOM 日志可见 `Killed process xxx ((udev-worker))`）

#### 1.3 fork 逻辑

（`udevd.c event_run()`）：事件到达 → 找空闲 worker → 没有则 `worker_spawn()` fork 新的，直到达上限

### 2 为何一次能涨到 146 个

#### 2.1 默认上限与 CPU 核数正相关

（systemd PR #12497 的默认值表：`children-max = C×CPU + O`）：

| CPU 核数 | v240 前 (C=2,O=8) | v240 后 (C=8,O=8) | PR12497 后 (C=2,O=16) |
|---|---|---|---|
| 16 | 40 | **136** | 48 |
| 64 | 136 | **520** | 144 |
| 上限 | — | — | 2048 |

146 ≈ 十几核机器 v240+ 的默认上限——一次 trigger 把全系统几百上千个设备事件灌入，udevd 直接 fork 到上限

#### 2.2 worker 处理完不立刻退

处理完一个事件回到 **IDLE 状态等下一个**，不会马上退出；事件量大时所有 worker 挂着，`ps` 里一片 `udev-worker`

#### 2.3 容器内累积更严重

规则里的 RUN 程序、firmware 加载、`settle` 等待等若被阻塞，worker 处理不完 → 一直占着 → 越积越多（对应 `xvnc2.sh:51` 注释："pulse启失败后sv不断重试,导致sysd-udev产生多个进程/累加(导致机器卡)"——每次重试/触发叠加一批不回收的 worker）

### 3 udevadm trigger 会产生新进程吗

#### 3.1 trigger 本身是短命 CLI，不常驻、不直接 fork

`udevadm trigger --type=devices --action=add` 遍历 /sys 往每个设备的 `uevent` 文件写 `add`，让**内核重新广播**这些设备的 uevent，随后自身退出

#### 3.2 真正产进程的是连锁反应

内核广播 → 主 udevd 收到 → 无空闲 worker 则 **fork `udev-worker`** 批量处理

#### 3.3 全系统扫描式

`--type=devices --action=add` 是"全系统扫描式"，一次触发上千事件，最容易引爆 worker 数量

### 4 缓解手段

#### 4.1 调小上限

`udev.children_max=8`（内核 cmdline）或 `udevadm control --children-max=8`（`/etc/udev/udev.conf` 配 `ChildrenMax=8`），事件接近串行化，防爆

#### 4.2 trigger 后紧跟 settle

`udevadm settle` 等队列排空再继续（本项目已有，`xvnc2.sh:57`）

#### 4.3 避免反复 trigger

本项目用 `/tmp/udev-trigger.lock` 保证重启容器才触发一次，方向正确；注意 sv 对 pulse 的无限重试可能绕过 lock 逻辑叠加 worker（`xvnc2.sh:51-52` 注释记录的坑）

### 5 容器内外双跑 udevd 时的边界（设置隔离 vs 事件共享）

容器内外**各自跑一个 udevd**（本项目即此场景：宿主 udevd + 容器内 x2-udev）时，隔离边界如下：

#### 5.1 children-max 设置（各管各的，互不影响）

- `udevadm control --children-max=N` 走 Unix socket `/run/udev/control`，**每个 udevd 实例各建各的**：宿主 udevd 用宿主 `/run/udev/control`，容器内 udevd 用自己的（本项目 `xvnc2.sh:89` 还特意 `rm -rf` 再让 udevd 重建，避免碰宿主的）
- 容器内执行 `udevadm control --children-max=8` 只发给容器内那个 udevd；宿主机 udevd 毫无感知
- `/etc/udev/udev.conf` 同理：每个实例启动时读**自己**那份配置（前提是没把宿主配置挂进容器）

#### 5.2 trigger / 热插拔事件（广播式共享，双方都会收到）

1. `udevadm trigger --type=devices` 遍历 `/sys`——容器内挂的 /sys 就是**宿主机 sysfs 同一份**（bind mount）
2. 向设备 `uevent` 文件写 `add` → 内核 `kobject_uevent()` 广播，发给**同一网络命名空间内所有** netlink 监听者
3. 本项目 `network_mode: host` → 宿主 udevd 和容器内 udevd **都在宿主 netns 监听同一个事件流** → **双方 udevd 同时收到**，各自按自己的 children-max fork 自己的 worker

#### 5.3 各触发各的？不，是同一批事件各自处理

| 层面 | 隔离？ | 说明 |
|------|--------|------|
| children-max 设置 | ✅ 隔离 | control socket 各实例各一个 |
| udev.conf 读取 | ✅ 隔离 | 各读各的文件 |
| 事件源（trigger/热插拔） | ❌ 共享 | 写共享 /sys + net=host → 同一广播 |
| worker fork | 各自独立 | 双方各自按自己的 children-max fork 自己的 worker |

#### 5.4 对本项目的实际影响

- 容器内 `udevadm trigger --type=devices`（`xvnc2.sh:53-58`）会让**宿主机 udevd 也 fork 一批 worker**——低配宿主机（如本项目 xm 设备）上，这就是"进程风暴"传导到宿主的一条路径，比容器内自身更隐蔽
- lock 防重复 trigger（`/tmp/udev-trigger.lock`）的意义不只省容器内资源，**也保护宿主机 udevd**
- 容器内 `ChildrenMax` 只约束容器内 worker，**约束不了宿主机**——要限制宿主侧，须在宿主 udev.conf / 内核 cmdline 设 `udev.children_max=`

### 6 trigger 过滤：只补发 xorg/pulse 所需子系统

> 用户问题原文："那可以限制trigger只获取xorg pulseaudio所需的事件项？trigger的目的是容器内新启udev后 让内核开机已发过的事件再发一遍？ 内核重发时是所有udev实例都收到一遍咯？"

#### 6.1 trigger 的目的确认

✅ 内核在开机枚举设备时广播过一遍 uevent；容器内 udevd 是容器启动后才拉起，**错过了那批事件**，数据库为空。`udevadm trigger --type=devices --action=add` 遍历 /sys 现有设备、往各自 `uevent` 文件写 `add`，让内核**补发一遍**现有设备事件，udevd 借此建库（本项目 `xvnc2.sh:53-58` 正为此）。

#### 6.2 内核重发时所有实例都收到

✅ netlink 广播无定向，同 netns 内所有监听者各收一份——`--net=host` 下宿主 udevd + 容器内 udevd **双方各处理一遍**（风暴传导根源）。

#### 6.3 可以限制（subsystem-match 过滤）

`udevadm trigger` 原生支持子系统过滤，多个 `--subsystem-match` 是**并集（OR）**：

```bash
# 只补发 input（Xorg 键鼠）+ sound（PulseAudio 声卡）
udevadm trigger --type=devices --action=add \
  --subsystem-match=input \
  --subsystem-match=sound
```

#### 6.4 对本项目的好处

- **容器内**：udevd 只处理 input/sound 两类设备（几个节点），而非全系统上千设备 → worker 不爆
- **宿主机**：同一条广播宿主 udevd 也只收到 input/sound 补发 → **风暴传导面从全系统缩到几台设备**，比单纯调 children-max 更治本
- Xorg 输入链路（`ID_INPUT_*` 属性）与 PulseAudio 声卡链路（`/dev/snd/controlC*`）恰好就是这两个子系统划分

#### 6.5 更细的过滤（一般用不上）

`--attr-match=KEY=VAL`（sysfs 属性）、`--property-match=`（udev 属性）、`--tag-match=`（udev 规则打的 tag）、`--name-match=`（设备名）。

#### 6.6 注意

`--subsystem-match=input` 匹配设备 `SUBSYSTEM=` 值；input 设备在 input 子系统、声卡在 sound 子系统，均已覆盖；以后要加蓝牙/网卡再扩 match 即可。

### 7 屏蔽非 input/sound 事件的响应（规则白名单）

> 用户问题："容器内udev除了input sound，能屏蔽其他事件的响应吗？"

**核心结论：事件"接收"无法过滤，但"响应"可以屏蔽**——udev 是"无匹配规则则无动作"的引擎，屏蔽规则即屏蔽副作用（mdadm RAID 组装、稳定符号链接等全部是规则驱动的）。

**两个层面要分开**：

| 层面 | 能否屏蔽 | 说明 |
|------|----------|------|
| 接收层（netlink） | ❌ 无法过滤 | 内核 uevent 全量广播，udevd 无 `--subsystem-match` 参数（`xvnc2.sh:94` 裸启 `systemd-udevd`）；`udevadm monitor --subsystem-match=` 是 monitor 客户端的 BPF socket 过滤，非 udevd 守护进程 |
| 响应层（规则引擎） | ✅ 可以屏蔽 | 不匹配 = 无动作（不 RUN、不建符号链接、不改权限）；md-raid/storage/net/firmware 副作用全在规则层 |

#### 7.1 三种屏蔽手段

1. **删/清不需要的规则文件（最干净，推荐）**：保留 input/sound 相关（`60-persistent-input.rules` 打 ID_INPUT 标签、声卡规则），其余删除：
   ```bash
   # Dockerfile 或 entry 中
   rm -f /lib/udev/rules.d/{64-md-raid,60-persistent-storage,80-net-setup,90-modprobe}.rules ...
   ```
   > udev 无"全局忽略其余"指令，`GOTO/LABEL` 只跳**同一文件内**，无法用一个文件屏蔽所有其他文件——删文件是唯一彻底途径。
2. **白名单跳转（不删文件，保守）**：逐个非 input/sound 规则文件头部加：
   ```
   SUBSYSTEM!="input", SUBSYSTEM!="sound", GOTO="end"
   LABEL="end"
   ```
   维护成本高，需逐文件处理。
3. **换轻量实现（最彻底）**：dumb-udev / vdev（见三节），只监听+响应需要的子系统。

#### 7.2 屏蔽不掉的固有行为

以下 udevd 收到事件后的基础动作**不在规则层**，屏蔽不了（也无害）：更新数据库 `/run/udev/data/`、维护 /dev 节点（devtmpfs 由内核建节点，udev 只调权限/链接）。

#### 7.3 结合本项目现状与落地建议

| 项 | 现状 | 结论 |
|----|------|------|
| 规则加载 | 仓库 Dockerfile 未做规则清理 → 容器内 udevd **加载发行版全部规则**（md-raid/storage/net/firmware 全响应） | ⚠️ "设备节点/挂载点竞争"风险真实存在 |
| trigger 补发 | `xvnc2.sh:55-56` 全量 `--type=devices` | 建议配合 6 节收窄为 input+sound |
| 现有防护 | 仅 `/tmp/udev-trigger.lock` 防重复 | 不防规则副作用 |

**落地建议（双管齐下）**：

1. Dockerfile 加一步规则白名单（删 md-raid/storage/net 等规则文件），让 udevd 对非 input/sound 事件"零响应"
2. `xvnc2.sh:55-56` trigger 加 `--subsystem-match=input --subsystem-match=sound`，减少补发事件量（同时保护宿主 udevd）

### 8 两条最深机制的源码级细化（IPC 死锁 / userns 拒收）

> 对应九节 5 七大问题的第 2、3 条。这两条都是"单机假设 vs 命名空间隔离"的典型冲突。

#### 8.1 IPC 命名空间死锁：libdevmapper 的 cookie 信号量握手

**正常机制**（LVM/cryptsetup 保证"udev 规则建好节点再继续"的 5 步协议，依据 `cryptsetup/lib/libdevmapper.c` 的 `_dm_create_device()`、lvm2 `udev/10-dm.rules.in`、`dmsetup udevcreatecookie`）：

```
① cryptsetup luksOpen
    → dm_task_set_cookie()  用 semget() 创建 System V 信号量，semid 存入 cookie
② dm_task_run()            内核创建 dm-crypt 设备 → 广播 uevent，env 带 DM_COOKIE=<semid>
③ _dm_udev_wait(cookie)    调用方 semop() 阻塞等待该信号量归零（等 udev 处理完）
④ udevd 收 uevent → 10-dm.rules 规则尾部
    RUN+="/sbin/dmsetup udevnotify $env{DM_COOKIE}"  → 释放/删除该信号量
⑤ 信号量归零 → ③ 的 semop 返回 → luksOpen 完成
```

关键：**DM_COOKIE 是一个 System V 信号量 ID**（`dmsetup udevcookies` 可列出，文档明说 "system-wide semaphores"）。

**容器里怎么坏**：System V 信号量按 **IPC 命名空间隔离**，semid 每 ns 独立编号：

| 角色 | 进程位置 | 能否看到容器内信号量 |
|------|----------|----------------------|
| 创建者（cryptsetup） | 容器内 | ✅ 同一 IPC ns |
| 等待者（_dm_udev_wait） | 容器内 | ✅ 同一 IPC ns |
| 释放者（udevnotify 规则） | **宿主 udevd**（net=host 也会收到该 uevent） | ❌ **semid 在宿主 ns 不存在** |

- **无容器内 udevd（致命）**：宿主 udevd 处理该 uevent → `dmsetup udevnotify <semid>` 在宿主 IPC ns 找这个 semid → 不存在（EINVAL）或**恰好命中宿主同名信号量（误操作）** → 容器内 cryptsetup `semop()` 等不到归零 → **luksOpen/luksClose 永久挂起**
- **双 udevd（本项目场景）**：容器内 udevd 正确释放 → 容器侧不挂；宿主 udevd 也处理同一事件尝试 udevnotify → 报错/误碰宿主信号量，宿主侧噪声

**附加风险**：信号量泄漏耗尽。moby PR #33732 实锤——`setCookie` 后漏调 `UdevWait` → LVM 代码信号量泄漏 → 最终 semaphore 耗尽，devicemapper 长期运行后无法创建容器。

**本项目相关性**：`xvnc2.sh` 无 dm/cryptsetup 服务，容器内不跑 LVM → 触发面小；风险仅在容器内执行 luksOpen/luksClose 类操作时。

#### 8.2 用户命名空间破坏事件接收：libudev 的发送者检查

**检查机制**（`sd-device-monitor.c` 源码实锤）：

```
① device_monitor_new_full(): setsockopt(SO_PASSCRED)   # 开启发送者凭据接收
② check_sender_uid(uid):                               # 收到消息时逐条判定
     uid==0                        → 信任（内核事件发送者是 root）
     uid==getuid()/geteuid()       → 信任（unicast 自身消息）
     uid 不在本 userns 映射范围内  → 信任（判定为"userns 外部"）
     否则                          → 拒绝，打印 "Sender uid=X, message ignored"
```

**uid 翻译链**（凭据 uid 按**发送侧 netns 归属的 userns** 生成）：

```
net=host → netlink socket 在宿主 netns → 该 netns 属于初始 userns
→ 内核广播 uevent 时凭据 uid 按初始 userns 生成 = 0（root）
→ 容器在 userns 里 recvmsg 时，内核把 uid 0 按容器 userns 映射翻译
→ 容器 userns 未映射 host 0 → 翻译为 overflowuid = 65534
→ check_sender_uid(65534): ≠0 ≠自身 → 查映射范围 → 见下
```

**为什么"必死"**：toolbox/distrobox 的 `--userns=keep-id` 默认映射 `size=65536/65537`，**把 overflowuid(65534) 也划进映射范围** → `uid_range_contains(65534)` 返回 true → 判定为"userns 内部伪造" → 拒绝。实测日志（podman #27898、toolbox #1203）：

```
sd-device-monitor(kernel): Sender uid=65534, message ignored.   ← 刷屏
```

**修复**：映射范围**不包含 65534**，如 `--userns=keep-id:size=1000` → 65534 落在映射外 → 判定"来自 userns 外部" → 信任 ✅

**附带**（Brauner netdev 补丁 2018）：若 netns 由**非初始 userns** 拥有（`unshare(CLONE_NEWUSER|CLONE_NEWNET)`），则**根本收不到**硬件 uevent（只收 per-netns 网络设备事件）——比"拒收"更早一层就断了。

**本项目相关性**：`privileged + network_mode: host`，**无 userns 配置** → 容器在初始 userns 运行，uid 0 映射正常 → 不触发；若未来改 rootless/keep-id 部署会直接命中，需按上述修复。

#### 8.3 两条本质对比

第 2 条是"**跨 IPC 命名空间引用了不存在的信号量**"（调用方等待、宿主释放、可见性错位）；第 3 条是"**跨用户命名空间的 uid 翻译把合法 root 变成可疑 65534 被安全机制拒收**"（内核发送、userns 翻译、libudev 误判）。

## 十一、本项目（docker-hdmi-desktop）现状对照

> 本文档描述的是"宿主 udevd 转发 / 容器共享其 control 文件"场景；本项目走的是**另一条路线：容器内自跑独立 udevd**，对照如下：

| 项目 | 资料建议 | 本项目实际 |
|------|----------|------------|
| 网络命名空间 | --net=host | ✅ 已满足 `docker-compose.yml:9 network_mode: host` |
| 特权 | --privileged | ✅ 已满足 `docker-compose.yml:8 privileged: true` |
| /dev 直通 | -v /dev:/dev | ✅ 已满足 `docker-compose.yml:14-15 devices: - /dev:/dev` |
| /run/udev | 挂载宿主目录 | ⚠️ **未挂载，且不应挂载**——见下 |

### 1 为何本项目不挂 /run/udev

- 容器内自跑独立 udevd（`xvnc2.sh:86-99` x2-udev 分支：`mkdir -p /run/udev`、删 `rm -rf /run/udev/control` 再 `exec su-exec root systemd-udevd`；Alpine 回退 `/sbin/udevd`）
- 容器内 udevd 启动时会在自己的 `/run/udev` 下重建 control 文件；挂载宿主的 `/run/udev/control`（Unix socket）会与容器内 udevd 冲突，这正是 `xvnc2.sh:89` 主动删除它的原因
- 网络命名空间已共享，Netlink 事件天然可达，无需依赖宿主的 control 文件做"转发开关"

### 2 若遇"容器收不到事件"的调试路径

1. 确认 x2-udev 服务 up：`sv s /etc/perp/x2-udev`（perp 服务见 `src/entry-x11base.sh:139` 注册）
2. `udevadm monitor --kernel --udev` 后插拔，确认事件到达（本项目 net=host 下 KERNEL 事件应直接可见）
3. 若只有 KERNEL 无 UDEV：查容器内 `/run/udev/control` 是否被 udevd 重建；必要时 `udevadm trigger --type=devices --action=add` 补发（`xvnc2.sh:53-58` 已有，受 `/tmp/udev-trigger.lock` 保护，重启容器才重置）
4. Xorg 层：`xinput list` 对比插拔；注意本项目 `src/bin/input.sh` 生成 `AutoAddDevices False` + 显式 evdev（见 b7），热插拔新设备不会自动出现属预期行为，需重启 Xorg 或按 b7 建议路径演进

### 3 热插拔可识别性判断（结合仓库代码）

> 已验证：USB 鼠标插入/拔除，`udevadm monitor --kernel --udev` 可实时感知。

**结论：能识别**。逐链路核对，四个必要条件全部满足，且热插拔路径与 trigger 无关（trigger 只是补发历史事件）：

| # | 链路环节 | 判断 | 代码依据 |
|---|----------|------|----------|
| 1 | Netlink 可达 | ✅ | `docker-compose.yml:9 network_mode: host`——共享宿主 netns，内核 uevent 广播容器内 udevd 与宿主 udevd **同时收到** |
| 2 | 有处理者 | ✅ | `src/xvnc2.sh:86-99` udev 分支：容器内独立拉起常驻 udevd（`mkdir -p /run/udev` → 删 control → `exec su-exec root systemd-udevd`，Alpine 回退 `/sbin/udevd`），perp 托管（`src/entry-x11base.sh:139`） |
| 3 | 权限 | ✅ | `docker-compose.yml:8 privileged: true`——udevd 处理事件需 mknod/chmod 等全部 capability |
| 4 | 设备节点可见 | ✅ | `docker-compose.yml:14-15 devices: /dev:/dev`——devtmpfs 整目录直通，热插拔新节点（如 `/dev/input/eventN`）容器内直接可见 |

**验证命令**（进容器）：

```bash
udevadm monitor --kernel --udev   # 插拔 USB，应看到 KERNEL[...] + UDEV[...] add
udevadm info --query=all --name=/dev/input/eventX  # 查 ID_INPUT 等属性
```

**三个注意点（不影响"识别"，但影响"用得上"）**：

1. **Xorg 层收不到新设备**：`src/bin/input.sh` 生成 `AutoAddDevices False` + 显式 evdev（`xvnc2.sh:13-14`），即使 udev 识别到热插拔新设备，**Xorg 也不会自动加载**，需重启 Xorg 或按 b7 文档路径演进——预期行为，不是识别失败
2. **双 udevd 争抢**：宿主 udevd + 容器内 udevd 各处理一遍同一事件（见十节 5），对宿主有轻微干扰，但容器内识别完整
3. **/sys 未显式挂载**（`docker-compose.yml` volumes 无 /sys，Docker 默认只读）：影响 `xvnc2.sh:55-56` 的 `udevadm trigger`（写 `/sys/.../uevent` 补发**历史**事件，/sys 只读时可能报错）；但**热插拔是内核实时广播，不依赖 trigger**，识别不受影响。若 trigger 确实失败，可 `mount -o remount,rw /sys`（privileged 下可写）

> 一句话：**识别链路完整可用**——热插拔 → 内核广播 uevent → net=host 下容器内 udevd 收到 → privileged 处理 → /dev 直通节点可见。短板在 Xorg 消费端（AutoAddDevices False）与 trigger 补发（/sys 只读），均不属于"识别"环节。
### 4 规则清理实测清单（容器内 54 个规则文件分类）

> 基于当前容器（hdmi-desktop）`/lib/udev/rules.d/` 实测 54 个规则文件，按"容器只需 input 键鼠 + sound 声卡 + 基础节点"原则分类。

#### 4.1 必须保留（17 个）——动了键鼠/声卡/基础就废

**核心基础（删了 udev 整体不工作）**：

- `50-udev-default.rules` —— **绝不能删**，所有子系统的基础节点/权限/符号链接
- `50-firmware.rules` —— 固件加载（保守保留）
- `99-systemd.rules` —— systemd 设备单元标记

**input 链路（Xorg 键鼠识别，对应 3 节 ID_INPUT 标签）**：

- `60-input-id.rules`（input_id 打 `ID_INPUT_*` 标签，核心）
- `60-persistent-input.rules` / `60-evdev.rules`（持久化命名 / evdev 属性）
- `70-mouse.rules` / `70-touchpad.rules` / `70-joystick.rules` / `65-libwacom.rules`（设备类型识别）
- `70-power-switch.rules` / `71-power-switch-proliant.rules`（input 电源键）
- `80-libinput-device-groups.rules` / `90-libinput-fuzz-override.rules`（libinput 设备分组）
- `64-xorg-xkb.rules` / `66-xorg-synaptics-quirks.rules`（Xorg 布局）

**sound 链路（PulseAudio 声卡，对应 module-udev-detect）**：

- `78-sound-card.rules` / `60-persistent-alsa.rules` / `90-alsa-restore.rules` / `90-pulseaudio.rules`

#### 4.2 推荐清理（24 个）——网络/存储/其他设备，容器内用不到

```bash
# 网络（NM 未启用，容器无网卡管理需求）
rm -f /lib/udev/rules.d/{73-special-net-names,75-net-description,80-net-setup-link,81-net-dhcp,84-nm-drivers,85-nm-unmanaged,90-nm-thunderbolt}.rules
# 存储/块设备（devtmpfs 仍建节点，仅不建 /dev/disk/by-uuid 等符号链接）
rm -f /lib/udev/rules.d/{60-block,60-persistent-storage,60-persistent-storage-tape,61-persistent-storage-android,64-btrfs,96-e2scrub}.rules
# 其他设备（光驱/串口/摄像头/传感器/内存/闪存/老接口/upower）
rm -f /lib/udev/rules.d/{60-autosuspend,60-cdrom_id,60-fido-id,60-persistent-v4l,60-sensor,60-serial,70-memory,75-probe_mtd,80-drivers,95-upower-hid,95-upower-wup}.rules
```

#### 4.3 可留可删（13 个）——保守建议保留

| 文件 | 说明 | 建议 |
|------|------|------|
| `40-vm-hotadd.rules` | VM cpu/memory 热插拔，容器内无感但无害 | 留 |
| `60-drm.rules` / `78-graphics-card.rules` | 显卡节点权限 | 留（HDMI 物理输出可能要） |
| `71-seat.rules` / `73-seat-late.rules` | seat 概念 | 留（Xorg/lightdm 会话） |
| `70-uaccess.rules` | 桌面 uaccess 授权 | 可删（单用户容器） |
| `70-pcspkr-beep.rules` | 蜂鸣器（input 子类） | 可删 |
| `80-debian-compat.rules` | Debian 兼容 | 留 |
| `90-console-setup.rules` | tty 控制台 | 可删 |

#### 4.4 关键提醒

1. **删完必须重载**：`udevadm control --reload-rules`（或重启容器），否则已加载规则仍生效
2. **双保险验证**：删后插拔 USB 鼠标，`udevadm monitor --kernel --udev` 仍应看到 input 事件，`udevadm info` 仍有 `ID_INPUT=1`
3. **与 trigger 收窄配套**：删规则文件（响应层）+ `--subsystem-match=input --subsystem-match=sound`（事件层）——b9 十节 7 的完整落地
4. 若以后要 USB 存储/U 盘直通，再把 `60-persistent-storage.rules` 加回来即可

### 5 非 host 网络下容器内 udev 的运行方式

> 核心结论：**非 host 网络下，容器内 udevd 收不到任何硬件热插拔事件——内核硬限制，非配置问题**。但"运行"仍可行，能力降级为"静态识别"。

#### 5.1 为什么收不到：内核广播只发给初始 netns

`lib/kobject_uevent.c` 的 `kobject_uevent_net_broadcast()`：

```c
ops = kobj_ns_ops(kobj);        // 取 kobject 的网络命名空间操作
...
if (ops) { net = ops->netlink_ns(...); }   // 网络设备 → 所属 netns
if (!net)
    net = &init_net;            // 非网络设备 → 硬编码初始 netns！
retval = uevent_net_broadcast(net, ...);   // 只发到 init_net 的 socket
```

非网络设备（input/sound/block 全部硬件）的 uevent 只广播到**初始网络命名空间（init_net）**的监听 socket。容器独立 netns → 容器内 udevd 的 socket 不在 init_net → 一条硬件事件都收不到。

唯一例外：**网络设备**（有 net ns ops）广播到其所属 netns——容器自己的 veth/lo 事件能收到，与键鼠声卡无关。

#### 5.2 非 host 下 udev 能力降级

| 能力 | 非 host | host |
|------|---------|------|
| 启动时 trigger 建库（静态识别现有设备） | ✅ 可用 | ✅ |
| 热插拔实时感知 | ❌ **失效** | ✅ |
| `udevadm monitor` 插拔可见 | ❌ 无输出 | ✅ |
| Xorg/PulseAudio 启动时识别键鼠声卡 | ✅（靠 trigger 补发） | ✅ |

`udevadm trigger` 仍有效：写 `/sys/.../uevent` 让**内核**重新广播——但广播照样发到 init_net，容器内还是收不到。非 host 下容器内 udevd **只能靠 trigger 建一次库**，之后的事件全部丢失。

#### 5.3 三种可行运行方式

**方案一（务实，本项目现状的退化版）**：照常跑 udevd + 启动时 trigger

- 容器内 udevd 正常启动（privileged + /dev + /sys 直通），`xvnc2.sh:53-58` trigger 建库
- 效果：**启动时已插着的键鼠/声卡可识别**（Xorg/PulseAudio 能用），之后插拔无感知
- 适合本项目：`input.sh` 本来就是 `AutoAddDevices False` + 显式声明，**本来就不依赖热插拔**

**方案二（要热插拔，最简单）**：net=host

- 容器进宿主 netns → udevd socket 在 init_net → 一切正常（当前项目即此）

**方案三（隔离 + 热插拔都要）**：宿主 uevent 转发注入

- 宿主机跑转发守护进程：宿主 netns 收 uevent → 经 netlink 向**容器 netns 的 uevent socket** 注入（内核支持 UEVENT_SEND 用户态注入，Brauner 实验 `uevent-container-forwarder` 思路）
- 容器内 udevd 照常监听自己 netns 的 socket，转发器把宿主事件灌进来
- 需要：宿主 root + 容器 netns 权限；比 host 网络隔离性好，但复杂度高

#### 5.4 补充细节

1. **"udev does not support containers" 检测**：`/etc/init.d/udev` 里 `[ ! -w /sys ]` 才拒绝启动——非 host 但 **privileged 时 /sys 可写，仍能启动** udevd（`xvnc2.sh:86-99` 特权直启，不受 init 脚本影响）
2. **网络设备特例**：容器自己的 veth 事件能收到（所属 netns 广播），NM 类容器服务在 bridge 下可正常工作，但这是唯一能收到的
3. **LXD unix-hotplug** 是设备节点映射方案（非 uevent 转发），解决的是节点可见性而非事件到达

#### 5.5 对本项目的判断

`docker-compose.yml:9 network_mode: host` 是本项目热插拔感知（本章 3 节实测验证）的**根本前提**。若为隔离改成 bridge：

- x2-udev、Xorg、PulseAudio **照常能启动**（trigger 建库）
- 但 3 节的实测（monitor 插拔可见）会失效
- 除非上方案三的转发器，否则热插拔不可用

#### 5.6 方案三实操：compose 支持性 + 转发器搭建

**结论：Docker/Compose 原生不支持 uevent 转发——没有对应字段**。netlink socket 是内核 socket 而非 Unix socket，无法 bind-mount（Docker 官方立场：要热插拔就用 `--network=host`）。方案三必须拆成"compose 管容器 + 宿主侧补转发器"。

**为什么 compose 原生不支持**：

- 内核 uevent 注入（`UEVENT_SEND` netlink 消息，Brauner commit `692ec06`）是**宿主 root 进程**调 `setns()` 进容器 netns → 打开 `NETLINK_KOBJECT_UEVENT` socket → 发 `UEVENT_SEND`，内核收到后在**该 netns** 内广播
- 跨容器边界操作，属宿主侧能力，compose 的 `network_mode`/`volumes` 字段管不到
- 完整实现目前只有 LXD/Incus（`incusd forkuevent`）；Docker 生态无内置等价物

**compose 能配置的部分**（目标容器，非 host）：

```yaml
services:
  desktop:
    privileged: true          # 容器内 udevd 仍需特权
    network_mode: bridge      # 默认即可，关键：非 host
    devices:
      - "/dev:/dev"           # 节点可见
    volumes:
      - /sys:/sys             # rw，trigger 用
```

**宿主侧转发器两种搭法**：

1. **宿主机跑现成工具 `udevfw`**（eiz/udevfw，专为此场景）：
   ```bash
   udevfw /proc/<容器PID>/ns/net   # 监听宿主 uevent → setns 容器 netns → 注入
   ```
2. **compose 加转发器容器**（可行但绕，本质自实现 `forkuevent`）：
   ```yaml
   services:
     udev-forwarder:
       image: ubuntu:24.04
       network_mode: host        # 在宿主 netns 收 uevent
       privileged: true          # CAP_SYS_ADMIN 才能 setns 到目标容器
       volumes:
         - /proc:/proc           # 访问目标容器 /proc/<pid>/ns/net
       entrypoint: ["/usr/local/bin/forward.sh"]  # 自写转发脚本
   ```

**硬性前提**：

| 项 | 要求 |
|----|------|
| 内核 | ≥4.15 且含 `netns: send uevent messages`（`UEVENT_SEND`=16） |
| 权限 | 注入者需在**目标 netns 的 owning userns** 里有 CAP_SYS_ADMIN |
| seqnum | 注入前需**去掉原 uevent 的 SEQNUM** 字段，内核会重新分配（`uevent_net_rcv()` 逻辑） |
| 事件内容 | 转发器只传事件，设备节点靠 /dev 直通 + 容器内 udevd 处理 |

**务实建议（对本项目）**：方案三性价比低——实现成本高（依赖 `udevfw` 的 libudev 内部消息格式，"somewhat hacky"，或复刻 Incus `forkuevent` 约 200 行 cgo），而本项目 `input.sh` 是 `AutoAddDevices False` + 显式 evdev，热插拔本就不驱动 Xorg；维持 `network_mode: host` 即可获完整热插拔。若目标是"网络隔离 + 热插拔"，更现实是整体换 LXD/Incus（内置 `forkuevent`），而非在 Docker 上自己造轮子。

## 十二、实测排障记录：热插拔事件可达但 /dev 节点不生成（2026-09-19）

> 记录时间：2026-09-19 22:00 CST。本文档全篇的"热插拔可识别性"实测结论在本节被修正——此前结论（十一节 3）默认 /dev 节点由内核自动创建，实测发现容器内并非如此。

### 1 现象

- 宿主机插拔 USB 鼠标，**容器内** `udevadm monitor --kernel --udev` 可实时收到 KERNEL + UDEV 事件
- 但容器内 `/dev/input/event11` 节点**未生成**；宿主机则有对应节点

### 2 根因：容器内 /dev 是 tmpfs 而非 devtmpfs

| 环境 | mount 输出 | 节点创建者 |
|------|-----------|-----------|
| 容器内 | `tmpfs on /dev type tmpfs (rw,nosuid,size=65536k,mode=755,inode64)` | 需用户态 mknod |
| 宿主机 | `udev on /dev type devtmpfs (rw,nosuid,relatime,size=16078736k,nr_inodes=4019684,mode=755,inode64)` | **内核自动创建** |

- **devtmpfs**：内核在设备出现时自动创建节点，udevd 只改权限/符号链接
- **tmpfs**：纯内存文件系统，无节点自动创建能力；udevd 收得到事件，但节点必须靠 mknod 显式创建，且规则/权限常失败 → 表现为"事件有、节点无"

Docker 默认给容器挂 tmpfs /dev，`devices: /dev:/dev` 只是把设备挂进去，不改 /dev 文件系统类型。

### 3 失败尝试：xvnc2.sh 里 mount devtmpfs（已回滚）

在 `xvnc2.sh` udev 分支加 `sudo mount -t devtmpfs devtmpfs /dev` 想直接覆盖：

- 结果：**容器无法 exec**，报 `open /dev/ptmx: no such device`
- 原因：`mount -t devtmpfs` 会**清空原 tmpfs 的全部节点**（含 /dev/ptmx、/dev/null、/dev/zero 等基础节点），且 devtmpfs 新挂载尚未填充这些节点 → entry 脚本里任何用到 /dev/ptmx 的进程全部失败
- 处置：立即回滚该改动（commit `12a3267`），保留 `xvnc2.sh` 原样

### 4 正确修复：compose 用 volumes bind 宿主 devtmpfs（已验证）

`docker-compose.yml` 把 `devices: - /dev:/dev` 改为 `volumes: - /dev:/dev`：

```yaml
    # devices:  # 移除（只挂设备，不改 /dev 文件系统类型）
    #   - "/dev:/dev"
    volumes:
      - /dev:/dev   # bind 宿主 devtmpfs → 容器内 /dev 即 devtmpfs
      - ./src/bin/:/usr/local/bin/
      ...
```

原理：bind mount 后容器内 `/dev` 直接就是宿主的 devtmpfs 视图，节点由内核自动创建，容器内 udevd 收到事件时节点已在——无需 systemd、无需改 udevd。

**实测结果**：改后热插拔 USB 鼠标，容器内 `/dev/input/event*` 节点正常生成，`udevadm monitor` 事件与节点同步 ✅

### 5 结论与注意事项

- **正确路径**：容器热插拔要可用，/dev 必须是 devtmpfs（bind 宿主 /dev 最简单）；Docker 默认 tmpfs 无法满足
- **不用 systemd**：bind 方案不依赖 systemd，`xvnc2.sh` 的 udev 分支原样保留
- **副作用**：bind 整个 /dev 后容器与宿主共享设备视图，/dev/pts 可能指宿主 pts；本项目 privileged + HDMI 直通定位本就如此，可接受（详见 6 节）
- **文档修正**：十一节 3 的"识别链路完整可用"结论需补充前提——事件可达（net=host）与节点可见（/dev 必须 devtmpfs）是两条独立链路，缺一不可

### 6 bind 整个 /dev 的副作用表现与解决思路

#### 6.1 副作用表现

bind 后容器 `/dev` 与宿主是**同一文件系统视图**（热插拔能修复正是靠这个"同一"），但带来四类副作用：

1. **/dev/pts 冲突（最典型）**：Docker 默认每容器独立 devpts 实例（newinstance），bind 后宿主 `/dev/pts` 覆盖容器挂载点：
   - `ls /dev/pts` 看到**宿主的** ssh/tmux 会话编号（0,1,2…）
   - 容器内 `tmux`/`script` 开新 pty 编号与宿主混在一起（`openpty()` 落在宿主 pts 上）
   - 容器内 pty 节点权限 620 属 `root:tty`，非 root 进程可能打不开
   - **pty 双向可见**：容器 pty 出现在宿主 `ls /dev/pts`，反之亦然
2. **/dev/shm、/dev/mqueue 共享**：宿主 `/dev/shm` 大小/内容与容器共用，容器独立 shm 隔离失效
3. **设备权限被容器 udevd 改写**（最隐蔽）：容器内 udevd 处理事件时，规则里的 `MODE=`/`OWNER=`（如 `50-udev-default.rules` 设 `mode="0660", group="video"`）会直接 chmod/chown **宿主**设备节点——因为是同一文件
4. **信息泄露**：宿主 `/dev/disk/by-id`、`/dev/mapper`、`/dev/vd*` 全部可见（本项目 privileged 本就全暴露，此处仅列举）

#### 6.2 解决思路（三方案）

**方案 A：bind 后重挂容器私有 pts/shm（保住完整 /dev）**

`src/entry-x11base.sh` 开头加：

```bash
# bind /dev 后重建容器私有挂载点
mount -t devpts -o newinstance,ptmxmode=0666,mode=620 devpts /dev/pts
mount -t tmpfs -o size=64m,mode=1777 tmpfs /dev/shm
ln -sf pts/ptmx /dev/ptmx
```

保留 devtmpfs 节点视图（热插拔正常），pts/shm 恢复容器隔离。需要 privileged（本项目 ✅）。

**方案 B：细粒度 bind，不 bind 整个 /dev（副作用面最小）**

只 bind 需要热插拔的子目录，pts/shm 保持 Docker 默认隔离：

```yaml
volumes:
  - /dev/input:/dev/input   # 键鼠热插拔
  - /dev/snd:/dev/snd       # 声卡（若需）
  # /dev/pts、/dev/shm 保持 Docker 默认私有
```

bind 目录内容是实时视图 → 新 input 节点照样可见；配合十节 7 的规则白名单（udevd 只响应 input/sound），副作用面最小。

**方案 C：组合（本项目推荐）**

- bind `/dev/input` + `/dev/snd`（方案 B）
- udev 规则白名单（十节 7 落地，清理清单见十一节 4）
- 不需要碰 pts/shm——它们保持 Docker 默认

#### 6.3 本项目建议

| 目标 | 方案 |
|------|------|
| 热插拔键鼠可用 | B（bind /dev/input）即可，无需整个 /dev |
| 声卡直通 | B 加 `/dev/snd` |
| 保持 pts/shm 隔离 | B 天然满足（没 bind 它们） |
| 现状（已 bind 整个 /dev） | 如需恢复隔离，entry 加方案 A 两条 mount |

## 十三、容器内 udev 如何操作 PulseAudio/Xorg 识别设备（云 VM 实测分析）

> 记录时间：2026-09-19 22:10 CST。基于当前容器（hdmi-desktop，宿主为云 VM 无真实设备）实测观察 + 机制梳理。

### 1 当前容器实测事实

| 观察 | 说明 |
|------|------|
| `udevd` 在跑（root） | x2-udev 服务正常 |
| `/dev/input` 有 event0-3 | VM 虚拟键鼠（i8042 模拟），非真实 USB |
| `/dev/snd` 只有 seq/timer，**无 controlC\*** | 云 VM 无声卡硬件 → PulseAudio 无 sink 可建 |
| `udevadm trigger` 写 `/sys/.../uevent` **Permission denied** | /sys 限制 → 规则附加属性（ID_INPUT 等）未生成 |
| udev 数据库几乎空（仅 veth 的 n232） | 无真实热插拔 + trigger 失败 → 规则没跑 |

### 2 链路一：udev → Xorg 识别输入设备

```
内核创 input 设备 → 发 uevent
   ↓
udevd 收事件 → 按规则跑：
   60-input-id.rules   → input_id 内置程序检测 → 附加 ID_INPUT=1 / ID_INPUT_MOUSE / ID_INPUT_KEYBOARD
   60-evdev.rules      → 附加 EVDEV_* 属性、设置节点权限
   80-libinput-device-groups.rules → libinput 分组标签
   ↓
属性写入 udev 数据库 /run/udev/data/c13:64 等
   ↓
Xorg 消费：
   [AutoAddDevices on]  Xorg 用 libudev API 监听/查询 → 每个 eventX 读 ID_INPUT_* → 选驱动(evdev/libinput)
   [本项目 AutoAddDevices False]  Xorg 不查 udev，靠 input.sh 显式声明（见 b7）
```

**关键**：Xorg 的"识别"本质是**读 udev 数据库里的属性标签**，标签由 `60-input-id.rules` 的 input_id 程序生成。当前容器无标签 = 数据库空 = 规则没跑（trigger 失败 + 无事件）。

### 3 链路二：udev → PulseAudio 识别声卡

```
内核创声卡 → /sys/class/sound/card0 → 发 uevent（SUBSYSTEM=sound）
   ↓
udevd 收事件 → 规则：
   78-sound-card.rules  → 设置 ID_SOUND=1、节点权限
   90-pulseaudio.rules  → 附加 ID_PULSE_* 属性
   60-persistent-alsa.rules → ALSA 设备持久化
   ↓
内核 devtmpfs 创建 /dev/snd/controlC0、pcmC0D0c/p 等节点
   ↓
PulseAudio 消费：
   module-udev-detect 用 libudev 监听 sound 子系统
   → 检测到 controlC0 出现 → 认为硬件可用
   → 加载 module-alsa-card → 按 UCM/profile 建 sink/source
```

**当前容器**：`/dev/snd` 只有 seq/timer（无 controlC0）→ module-udev-detect 找不到卡 → pulseaudio 无 sink。这是**云 VM 无声卡硬件**所致，与 udev 配置无关。

### 4 云 VM 环境暴露的两个配置隐患

1. **`udevadm trigger` 失败**（Permission denied）：容器内 /sys 虽 rw 但 uevent 写入受限 → 容器重启后 udev 数据库建不起来，Xorg/Pulse 启动时查不到属性（b9 十节 7.3 已预判，解法是规则白名单 + trigger 收窄）
2. **udev 数据库空**：即使 Xorg 开 AutoAddDevices 也识别不到——当前 input.sh 显式声明方案正好绕开此缺陷（b7 结论在此印证）

### 5 一句话总结

容器内 udev 是"**中间人**"：内核发事件 → udevd 跑规则打标签（`ID_INPUT_*`/`ID_SOUND`）→ 写数据库 → Xorg/PulseAudio 用 libudev 读数据库决定建不建设备。**识别的前提是数据库里有标签**，这依赖 trigger 能跑 + 规则能执行——当前云 VM 两者都受限，只是本项目（显式声明 + 无真实声卡）恰好不受影响。

## 十四、落地实施：worker 调小 + 规则清理脚本（2026-09-20 14:28 CST）

> 记录时间：2026-09-20 14:28:00 CST。本章为十节 7（规则白名单）与十节 4（缓解手段）的实际落地——worker 调小 + 规则清理脚本化，规则**移动而非删除**，可随时恢复。

### 1 改动一：worker 调小（--children-max=8）

`src/xvnc2.sh:97-99` udev 分支：

```bash
test -s $sudev && exec su-exec root $sudev --children-max=8
exec su-exec root /sbin/udevd --children-max=8   # eudev@alpine 同样处理
```

- 容器内 udevd worker 上限从默认（C×CPU+O，十几核可达 136+）降到 **8**，防进程风暴（对应十节 4.1）
- 仅影响容器内实例，宿主不受影响（十节 5.1 设置隔离）
- 注意：若镜像 udevd 版本旧不支持该参数会启动失败，需改 `udevadm control --children-max=8`

### 2 改动二：规则清理脚本（src/bin/udev-rules-clean.sh）

新增 `src/bin/udev-rules-clean.sh`（挂载到 `/usr/local/bin/`）：

- **移动而非删除**：24 个规则 mv 到 `/lib/udev/rules.d-ex/` 备份目录（对应十一节 4.2 清单：网络 7 + 存储 6 + 其他 11）
- **可恢复**：`sudo bash /usr/local/bin/udev-rules-clean.sh --restore` 全部移回
- **自动重载**：执行后 `udevadm control --reload-rules` 立即生效，无需重启容器
- **保留 17 个必需**（十一节 4.1：udev-default/firmware/99-systemd + input 链路 + sound 链路）

容器内用法：

```bash
sudo bash /usr/local/bin/udev-rules-clean.sh         # 清理（移走24个）
sudo bash /usr/local/bin/udev-rules-clean.sh --restore  # 恢复
```

### 3 完整落地组合（b9 十节 7 的闭环）

| 层 | 措施 | 状态 |
|----|------|------|
| 事件层 | trigger 收窄 `--subsystem-match=input --subsystem-match=sound` | ⏳ 待改（xvnc2.sh:55-56） |
| 响应层 | 规则清理脚本（本改动） | ✅ 已落地 |
| worker | `--children-max=8`（本改动） | ✅ 已落地 |
| 节点层 | /dev bind 方案（十二章） | ✅ 已落地（子项挂载） |

> 事件层 trigger 收窄尚未落地——若需完整闭环，下一步改 `xvnc2.sh:55-56` 加 `--subsystem-match`。

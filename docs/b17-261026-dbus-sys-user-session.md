# b17-261026 | D-Bus：系统总线 vs 用户会话总线——链路、暴露与保活

> 日期：2026-10-26
> 环境：`/_ext/home/headless`（Linux 容器，`tini` 为 PID 1、`perpd` 管理服务；Xvnc 桌面）
> 起因：主题仓 `xm-zs01/fk-awesome-wm-theme` 的 `docs/adjustment-log-04.md` 2.2「总线地址怎么给」
>   要重写——原 2.2.4 的前提「本容器没有 systemd-logind、也没有真正开机钩子」**已不成立**
>   （`perpd` 就是）。本文先梳理链路 / 现状 / 选型，**不动代码**。

---

## 一、链路、现状与选型分析

### 1、核心链路：容器里就两条总线

| | **系统总线 (system)** | **会话总线 (session)** |
|---|---|---|
| 数量 | 全容器**一条**，root 起，**perpd 盯着**（挂了会重启） | **每个用户一条**，谁起谁管 |
| 地址 | **写死常量** `unix:path=/var/run/dbus/system_bus_socket` | **看谁起、怎么起**：`dbus-launch` 给随机地址；
  另装的一套给固定常量 `unix:abstract=/tmp/dbus-uid<uid>` |
| 谁能连 | **任何人，不用任何环境变量**（socket 是 `0777`） | **必须知道地址**（env 里带着，或者能猜到常量） |
| 管什么 | 全机共享服务（NetworkManager、bluetooth） | 一个桌面会话里的应用互认（通知、mpris、ibus、portal） |

主题仓两条**都要用**，所以这不是二选一：

- `bluetooth_widget.lua:77` `dbus.add_match("system", ...)` → **system** bus
- 通知（naughty 的 `org.freedesktop.Notifications`）、mpris（`utils.lua` 的 `dbus-send`）→ **session** bus

### 2、容器里总线是怎么起的（服务链）

```
PID 1  /usr/sbin/tini -- perpd
        └─ perpd 读 /etc/perp/<svc>/rc.main（模板 /etc/perp/tpl-rc.main，末尾 eval ${TARGET} "$@"）
             ├─ x1-dbus  →  su-exec headless bash -c "... exec /xvnc2.sh dbus 1"
             │              └─ xvnc2.sh:78-84  dbus) 分支
             │                 export DBUS_SYSTEM_BUS_ADDRESS=unix:path=/var/run/dbus/system_bus_socket
             │                 exec su-exec root dbus-daemon --system --nofork      ← 系统总线，root 起
             ├─ x1-de    →  su-exec headless bash -c "... exec dbus-launch --exit-with-session openbox-session"
             │              └─ dbus-launch 起 session 总线（随机地址）+ openbox     ← 会话总线，DE 侧
             └─ x1-chansrv / x1-pulse / x1-udev / x1-xvnc ...
```

生成点：`src/entry-x11base.sh:138`（`addPerpService "$xn" "dbus" ...`）、
`:149`（`START_SESSION2="dbus-launch --exit-with-session openbox-session"`）、`:156`（`x1-de`）。

两个已经能看出问题的地方：

- `xvnc2.sh:80` 那个 `export DBUS_SYSTEM_BUS_ADDRESS=...` **实际是无效动作**——导出的值
  和 libdbus 编译进去的默认值一模一样，而且只作用于它那一条进程树。
- `x1-de` 用 `dbus-launch --exit-with-session` 起会话总线：**地址随机**，而且
  **daemon 被 double-fork 成孤儿，perpd 的 respawn 覆盖不到它**；`--exit-with-session`
  又让它和 DE 同生死。

### 3、现状实测：会话总线「满地都是，没人共享」

| 总线 | 地址 | 状态 |
|---|---|---|
| system | `unix:path=/var/run/dbus/system_bus_socket` | ✓ 活着；`env -u DBUS_* dbus-send --system` 直接通（**零配置全员可达**） |
| uid1000（headless）session | `unix:abstract=/tmp/dbus-uid1000` | ✓ 活着，但**孤儿进程**（PPID=1，没人监督） |
| live awesome（`:311`，root）挂在上面 | `unix:abstract=/tmp/dbus-9SzWkUg6ZH,guid=...`（root 随机） | ✓ 活着 |
| DE（openbox）带的那条 | `unix:abstract=/tmp/dbus-O0MKyFIHCu,guid=...` | ✗ **已死**（`/proc/net/unix` 里 grep 不到），
  openbox 至今带着死地址在跑 |
| 另有 21 条 root 随机 session daemon | `dbus-launch` 起的历史泄漏（最早 10-23） | 挂着，没人管 |
| `dbus-launch --autolaunch=...` ×2 | root / headless 各一 | 残留监视进程，它们守护的 daemon 已不在 |

**环境暴露实测**：

| 场景 | `DBUS_SESSION_BUS_ADDRESS` |
|---|---|
| 登录 shell（`bash -lc`，ssh 交互式走这里） | ✓ `unix:abstract=/tmp/dbus-uid1000` |
| 非登录 shell（桌面里手敲的 `bash`） | ✗ **未设** |
| ssh 非交互（`ssh host 'cmd'`） | ✗ **未设**（不 source profile.d） |

### 4、两个实际诉求的根因

不是「没有会话总线」，是「**有好几条，对不上**」。

1. **桌面里打开的 shell 拿不到地址**
   终端是从 awesome spawn 的，环境就是 awesome 的。所以问题在**起 awesome 的方式**：
   - `eval $(dbus-launch)` / `dbus-run-session` 起的 → 地址被继承，桌面 shell 也有；
   - `setsid env HOME=.. DISPLAY=.. awesome` 这种**只传几个变量**的方式起的 → DBUS 被丢掉。
   实测 `:311` 的 awesome 是**带地址的**（root 随机那条），
   所以拿不到地址的终端不是从它 spawn 出来的。
2. **ssh 交互式**其实**已经有地址了**（上面的 `bash -lc` 实测）——
   是 `/etc/profile.d/99dbus-session.sh` 生效的结果；缺的是**非登录 / 非交互**那条路。
3. **更麻烦的一层**：就算地址拿到了，也可能**连的不是同一条**。
   headless 的 shell 拿到 `uid1000` 那条，`:311` 的 awesome 在 **root 的随机地址**上——
   两条不同总线，各自 `owner` 自检都 `[ok]`，但通知对不上（假阳性）。

### 5、选用考量：系统总线 vs 会话总线

其实**不是选型问题，是规范定死的**：

- 通知 / mpris / portal / ibus 这些桌面协议规范上走 **session** bus；
  桌面应用（flameshot、notify-send、系统自带）默认发 session，不会去 system 找。
- 全机共享服务（NetworkManager、bluetooth）走 **system**：要跨用户、常驻、有 policy 保护。
- 判断标准一条：**「这个东西是全机共享的，还是属于我这个桌面会话的？」** 通知属于后者。

### 6、如果统一用系统总线，要怎么调

技术上能做成，两条路，**都不推荐**。

**路 A：改主题，往 system bus 上注册名字**

- 改 `lib/naughty/dbus.lua` 的 `Gio.BusType.SESSION` → `SYSTEM`（另一个仓 + 静态重编）
- `utils.lua` 的 `dbus-send` 加 `--system`
- **结果：通知全丢**。所有发送方（flameshot / notify-send / 系统应用）默认发 session bus，
  你 own 的是 system 上的名字，没人往那儿发；除非把所有发送方也改——不可行。

**路 B：把 `DBUS_SESSION_BUS_ADDRESS` 指到 system 的 socket**

- 应用一行不改，都「以为」在连 session，实际连到 system daemon 上。
- 代价：
  1. **system socket 本来就是 `0777`**，全容器所有用户的通知 / mpris 名字全混这一条 →
     跨用户互相看见、互相调，桌面会话的隔离没了；
  2. **`/etc/dbus-1/system.conf` 有 policy deny**，一堆方法调用会被拒；要放开就得改 system
     policy，等于把系统总线的安全边界拆了；
  3. **`org.freedesktop.Notifications` 一条总线上只能一个持有者**——几个 awesome 实例 /
     几台显示器 / 几个 Xvnc 会话就互相抢名，又是假阳性；
  4. 纯 hack，dunst 之类不会照这个配。

**一句话：唯一的好处是「少一条总线」，代价是把通知链路搞断 + 拆安全边界。不建议。**

### 7、另开一条会话总线，在单用户场景下的收益

**老实说：用户隔离那个收益在本容器是 0**（只有一个 headless 用户，不需要隔离）。
真正有用的就三条：

1. **地址是常量**——`unix:abstract=/tmp/dbus-uid<uid>` 是 uid 派生的固定值，
   **任何进程不用「发现」就能直连**。这是唯一能同时解决上面两个诉求的东西：
   桌面 shell `export` 一个常量、ssh `export` 同一个常量，跟 awesome 就对上了。
   `dbus-launch` 那种随机地址天生做不到。
2. **不跟 DE 绑生死**——现在 DE 那条是 `dbus-launch --exit-with-session` 起的，
   DE 一死总线就死（**实测 openbox 现在就带着死地址**）。换成 perpd 起的 `--nofork`，
   perpd 就是看门人。
3. **符合桌面规范**——要让 awesome 的 naughty 跟 flameshot / mpris 对上，
   **必须**有一条正确的 session bus 在位。

拿不到的收益：多用户隔离、logind 语义、标准 autolaunch 自动发现
（那个要走 `/run/user/<uid>/bus`，现在 `/run/user/` 是空的）。

### 8、建议（最小改动三件）

**两条总线都留着，各管各的；把会话总线地址定死成常量，交给 perpd 看着。**

1. **起 awesome 时显式带** `DBUS_SESSION_BUS_ADDRESS=unix:abstract=/tmp/dbus-uid<uid>`，
   不要用 `dbus-launch` 临时起；**用哪个 uid 起，就连哪个 uid 的总线**
   （现在 `:311` 是 root 起的 → 连的是 uid0 那条）。
2. **非登录 shell 补地址**：`~/.bashrc` 里加一行 source（写成只 export 不 spawn 的形式，
   幂等、无副作用）。桌面手敲的 `bash` 和 ssh 非交互就都有了。
3. **会话总线交给 perpd 保活**：`xvnc2.sh` 新增分支
   ```sh
   dbus-session)
       U=$(id -u headless)
       exec su-exec headless dbus-daemon --session --nosyslog \
            --nofork --address="unix:abstract=/tmp/dbus-uid$U"
   ```
   ```sh
   # entry-x11base.sh: oneVnc() 里；名字排在 x1-de 之前（x1-dbus-session < x1-de）
   addPerpService "$xn" "dbus-session" \
     "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh dbus-session $N\""
   ```
   关键：`--nofork`、不用 pidfile、不用 `setsid &`，perpd 才能是它的父进程。
   同时建议清掉 `dbus-launch --exit-with-session`（`entry-x11base.sh:149`）。

**配套两件事，一并做**：

- **owner 必须唯一**：`/usr/local/lib/dbus/ensure-user-session-bus.sh` 现在是
  「不在就自己 spawn」。perpd 抢了 abstract 名后它再 spawn → bind 失败 → daemon
  立刻退 → **perpd 无限 respawn 自转**。所以它**不是「可以删」，是必须删**，
  起 daemon 这活全归 perp。
- **两个脚本合成一行**：`ensure-*` 的逻辑（地址常量、`--nosyslog`、abstract、判活）
  搬进 `xvnc2.sh` 的 `dbus-session` 分支后，`/etc/profile.d/99dbus-session.sh`
  就只剩 export 一行，`ensure-*` 文件删掉（见 二.2.4）。

---

## 二、拍板结果与实施方案（2026-10-26，仓库侧已实施，**验证待做**）

### 1、四条结论

| # | 问题 | 结论 |
|---|---|---|
| 1 | awesome 用哪个 uid 起 | **headless**（连 uid1000 那条固定地址总线） |
| 2 | 非登录 shell 的地址放哪 | **不塞 `~/.bashrc`**；改由 **entry / perp 任务脚本幂等注入**（见 2.2） |
| 3 | 动 `src/xvnc2.sh` + `src/entry-x11base.sh` 加 perp 保活 | **可以动** |
| 4 | 两个 rootfs 脚本怎么处理 | **`ensure-*` 删掉**（逻辑进 `xvnc2.sh`）；
  `99dbus-session.sh` 留仓外、**缩成一行 export**（见 2.4） |

### 2、逐条展开

#### 2.1、awesome 用 headless 起

- **现状**：live awesome（`:311`）是 **root** 起的，挂在 root 的**随机地址**总线上
  （`unix:abstract=/tmp/dbus-9SzWkUg6ZH`），和 headless 的 shell（uid1000）**不是同一条**。
- **改后**：awesome 由 **headless** 起，
  `DBUS_SESSION_BUS_ADDRESS=unix:abstract=/tmp/dbus-uid1000`。
  X 权限没问题——`/xvnc2.sh xvnc` 分支起 Xvnc 带 `-ac`（关闭访问控制），
  同容器内任意用户可连。
- **收益**：awesome / 桌面终端 / ssh 三者落到**同一条**总线，通知链路闭合。
- **注意**：HOME 是 `/_ext/home/headless`（挂载盘），awesome 的 rc / cache 落在挂载盘，
  权限归 headless，符合预期。

#### 2.2、地址注入点：候选矩阵与结论

先说清一个前提：**脚本本身不 source 任何 rc 文件**。
「shell 里有地址」只意味着「**从这个 shell 直接跑**脚本」能带上；
`ssh host 'cmd'`、cron、maki 工具会话这类**不在交互 shell 下**的入口，照样拿不到。

| 注入点 | 覆盖谁 | 不覆盖谁 | 幂等性 |
|---|---|---|---|
| **perp 服务命令**（entry 生成的 `/etc/perp/<svc>/rc.main`）| DE / WM 及其**所有后代**
  （awesome、桌面终端、GUI 应用）| 非该子树的进程 | **天然幂等**：entry 每次启动
  `rm -rf /etc/perp/x1-*` 后重建 |
| `/etc/profile.d/*.sh` | **登录 shell**（含 ssh 交互式）| 非登录 / 非交互 | 幂等（静态文件）|
| `$HOME/.bashrc` | 交互非登录 bash | zsh / sh / 非交互 / 脚本自身 |
  **需 marker 包裹的幂等追加** |
| `/etc/bash.bashrc` | 同上，但**覆盖所有用户**（含 xvncN）| 同上 | 同上 |
| `/etc/environment` | PAM 登录会话 | 非登录 | 幂等（静态文件）|
| DE 的 autostart `.desktop` | **无**（DE 进程不会继承 autostart 的 export）| 全部 | — |

**结论：主注入点放 perp 服务命令**（起 DE / WM 的那个服务），靠**环境继承**覆盖整个
桌面子树；`/etc/profile.d/` 继续管登录 shell；只有「非 DE 子树 + 非登录」这种残余场景
才需要 `$HOME/.bashrc` 的 marker 幂等追加——**那条暂不做**，等确认真的需要再补。

具体落点（entry 脚本里已有同类写法：`/etc/default/useradd`、`/etc/hosts`、
autostart `.desktop` 都是 entry 直接写的）：

- `src/entry-x11base.sh`：新增 `busaddr="unix:abstract=/tmp/dbus-uid$(id -u headless)"`，
  并进 **`envcmd`**（不是 `decmd`）。`envcmd` 是 `x1-de` 与各工具服务的共同前缀，
  所以 DE / awesome / 桌面终端整条子树一次覆盖，不用再给个别服务单加；
- 同一处删掉 `dbus-launch --exit-with-session` 分支。

#### 2.3、perp 保活（已批准动 `src/xvnc2.sh` + `src/entry-x11base.sh`）

要点（命令片段见 一.8 建议 3）：

1. `xvnc2.sh` 新增 `dbus-session` 分支，`exec su-exec headless dbus-daemon --session
   --nosyslog --nofork --address=...`。**必须 `--nofork`**，perpd 才能是它的父进程。
2. `entry-x11base.sh` 里 `addPerpService "$xn" "dbus-session" ...`，服务名排在
   `x1-de` 之前（`x1-dbus-session` < `x1-de`）。⚠️ perpd 的启动顺序**不保证等于
   字典序**，需实测；不放心就让 DE 侧先等总线就绪。
3. 同时删掉 `dbus-launch --exit-with-session`（否则一条新总线 + 一条死总线并存）。
4. **owner 必须唯一（关键）**：**删掉** `/usr/local/lib/dbus/ensure-user-session-bus.sh`
   （不是降级）。它现在是「不在就自己 spawn」，perpd 起了之后它再 spawn 会 bind 失败
   → daemon 立刻退 → **perpd 无限 respawn 自转**。起 daemon 这活全归 perp。
5. 顺手清理：`dbus-launch --autolaunch` 残留进程、`~/.dbus/session-bus/` 里的过期
   记录、21 条 root 随机 session daemon。

#### 2.4、两个 rootfs 脚本：合成一行，`ensure-*` 删掉

两个脚本串起来就干一件事：**让 ssh 进来能连上 session 总线**。
`ensure-*` 起 daemon，`profile.d` 那份 export 地址。

可以合成一个，而且更彻底——**合成一行，`ensure-*` 直接删掉**。

依据：同一个 abstract 名不可能有两个 daemon 绑。
perp 起来的用户总线地址是 `unix:abstract=/tmp/dbus-uid<uid>`，
`ensure-*` 要起的也是**同一条**。所以分工就清楚了：

- **起 daemon 归 perp**（`xvnc2.sh` 的 `dbus-session` 分支，`--nofork`，perpd 当看门人）；
- **`profile.d` 只剩一行 export**，daemon 已经在位，不用再 spawn：

  ```sh
  export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:abstract=/tmp/dbus-uid$(id -u)}"
  ```

- **`/usr/local/lib/dbus/ensure-user-session-bus.sh` 删掉**。
  它最有价值的两条实测约束（只绑 abstract、必须 `--nosyslog`）随逻辑一起进 `xvnc2.sh`。

最终就三处，其中两处是同一句命令：

1. `src/xvnc2.sh` + `entry-x11base.sh` —— perp 起 daemon（唯一 owner，保活）
2. `/etc/profile.d/99dbus-session.sh` —— 一行 export（ssh 登录 shell 拿到地址）
3. DE / awesome 的 perp 服务命令 —— 同一行 export（桌面子树靠继承）

**为什么 `profile.d` 那行可以留仓外**：路径是发行版标准 hook
（POSIX 登录时 `/etc/profile` 遍历 source `/etc/profile.d/*.sh`），
加载机制由 OS 提供，不需要 entry 帮忙。
而 `ensure-*` 放 `/usr/local/lib/dbus/` 既没有标准路径、也没有标准加载者，
全容器唯一调用方就是 `profile.d` 那几行——它本来就寄生在那上面，所以直接删。

**`ensure-*` 是必须删，不是可以删**：perp 起来之后它再 spawn → bind 失败
→ daemon 立刻退 → perpd 无限 respawn 自转。

落地时**由 entry 每次启动重写**这一行（`cat > /etc/profile.d/99dbus-session.sh`），
镜像重建不会丢——上表里「真嫌烦再考虑让 entry 写它」的兜底直接落掉了。
文件里写死的是 headless 的 uid（不是 `$(id -u)`）：这份文件只服务 headless 的登录 shell。

### 3、实施顺序（建议）

1. `xvnc2.sh` 加 `dbus-session` 分支 → `entry-x11base.sh` 注册服务
   → **同步删掉** `/usr/local/lib/dbus/ensure-user-session-bus.sh`，
    把 `profile.d/99dbus-session.sh` 缩成一行 export（否则 perpd 自转）。
2. `entry-x11base.sh` 改 `x1-de`：去掉 `dbus-launch --exit-with-session`，
   改成 export 固定地址。
3. 起 awesome 改成 **headless** + 带固定地址。
4. 清理残留进程与过期 autolaunch 记录。

### 4、落地后的验证清单

- [ ] `/usr/local/lib/dbus/ensure-user-session-bus.sh` 已删；
  `profile.d/99dbus-session.sh` 只剩一行 export
- [ ] `x1-dbus-session` 服务 up，daemon 父进程是 perpd（不是 1）
- [ ] 手动 kill daemon → perpd 数秒内拉起，abstract 名不变
- [ ] `bash -lc 'echo $DBUS_SESSION_BUS_ADDRESS'` → `unix:abstract=/tmp/dbus-uid1000`
- [ ] 桌面里打开的终端 `echo $DBUS_SESSION_BUS_ADDRESS` → 同上
- [ ] awesome 进程 owner 是 **headless**，environ 里地址是 uid1000 那条
- [ ] `notify_triggers.py owner` 返回的 pid == awesome 的 pid（不再假阳性）
- [ ] `notify_triggers.py` 5 形状全 `OK`，且通知真弹出（Xvnc 截图像素验证）
- [ ] `/proc/net/unix` 里 session 总线只剩 1~2 条（uid1000 + uid0），无 root 随机泄漏

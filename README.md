# docker-hdmi-desktop

将 Docker 容器变成一个完整的桌面 PC，支持 HDMI 物理显示输出和远程访问（VNC/xRDP/noVNC/SSH）。

Fork 自 [hilschernetpi/netpi-desktop-hdmi](https://hub.docker.com/r/hilschernetpi/netpi-desktop-hdmi)，扩展为多架构（amd64/arm64/armv7）和多发行版支持。

---

## 技术栈

| 分类 | 技术 |
|------|------|
| **显示服务** | X.org (物理 HDMI) + Xvnc/TigerVNC (虚拟显示) |
| **桌面环境** | Openbox（默认）、Xfce4、Fluxbox 可选 |
| **音频** | ALSA + PulseAudio，支持 HDMI 音频输出 |
| **进程管理** | perp（轻量级 supervisor，类似 runit） |
| **远程访问** | xRDP、noVNC（浏览器）、x11vnc、TigerVNC、SSH |
| **基础系统** | Debian / Ubuntu / Alpine / OpenSUSE 多发行版 |
| **CI/CD** | GitHub Actions + Docker Buildx 多架构构建 |

---

## 核心架构

```
宿主 → Docker（privileged + host network）
        │
        └── perp 进程管理器 —— 监控所有服务，崩溃自动重启
              ├── xN-xvnc     —— TigerVNC 虚拟显示
              ├── xN-org      —— X.org 物理 HDMI 显示
              ├── xN-x11vnc   —— 共享物理显示给 VNC
              ├── xN-chansrv  —— xRDP 通道服务（剪贴板/文件传输）
              ├── xN-pulse    —— PulseAudio 音频服务
              ├── xN-dbus     —— D-Bus 系统总线
              ├── xN-udev     —— 设备热插拔管理（systemd-udevd）
              ├── xN-chvt     —— F12 急救：HDMI 黑屏时切回 tty1
              ├── xN-de       —— 桌面环境（Openbox/Xfce/Fluxbox）
              └── ssh         —— SSH 远程登录
```

### 多种访问方式

| 方式 | 说明 | 默认端口 (Display :1) |
|------|------|----------------------|
| **HDMI 直连** | X.org 直接输出到物理显示器 | - |
| **TigerVNC (Xvnc)** | 虚拟显示远程桌面（标准 VNC 客户端，HEADLESS=true） | `5901` (5900+N) |
| **x11vnc** | 共享物理 HDMI 显示给 VNC（HEADLESS=false） | `5901` (5900+N) |
| **xRDP** | Windows 远程桌面 (RDP) 协议 | `51089` |
| **noVNC** | 浏览器中访问 VNC 桌面（webhookd） | `51081` |
| **SSH** | 命令行终端登录 | `51022` |

> 端口根据 Display 编号自动偏移（`host` 网络直通）：`PORT_XXX = 50000 + N*1000 + 端口号`，N 为 Display 编号（:1 → SSH 51022 / RDP 51089 / noVNC 51081）。Xvnc/x11vnc 本体为 VNC 标准端口 `5900+N`（:1 → 5901，两者不同时运行）；noVNC(webhookd) 走 PORT_VNC=51081。

---

## F12 急救通道（HDMI 黑屏救援）

物理 HDMI 模式（HEADLESS=false）下，若 X.org/桌面异常导致屏幕黑屏且键盘无法操作，可按下 **F12** 切换回 tty1 救援。

- **perp 服务**：`xN-chvt`（entry-x11base.sh `oneVnc()` 注册），以 root 运行 `while true; do sleep 1; bash /usr/local/bin/f12_to_tty1.sh; done`
- **监听脚本**：`src/bin/f12_to_tty1.sh`（并发监听所有键盘）、`src/bin/f12_single.sh`（单选一个键盘）
- **实现**：evtest 写独立日志 + 0.05s 轮询匹配 KEY_F12 + 显式 kill（不用 evtest|grep 管道，规避 SIGPIPE/挂起双坑，详见 docs/b6-260917-f12-chvt-fix.md）

---

## xRDP 集成细节

xRDP 使用 **Xvnc 后端** (`lib=libvnc.so`)，RDP 会话连接到底层 TigerVNC 服务，实现 RDP 与 VNC/noVNC 共享同一个桌面会话。

### 配置流程

1. **端口动态分配**（`entry-x11base.sh`）
   - `PORT_RDP` = `50000 + DISPLAY_NUM*1000 + 89`
   - `SES_PORT` = `PORT_RDP + 1000`（sesman 监听端口）
   - 每个 Display 自动偏移，多会话互不冲突

2. **Session 动态注入**（`oneVnc()` 函数）
   - 从 `xrdp.ini.tpl` 模板恢复初始状态
   - 每个 Display 追加 `[Xvnc$N]` 配置段到 `# [PRE_ADD_HERE]` 标记前
   - 配置项：`lib=libvnc.so`、`ip=127.0.0.1`、`port=$port1`（对应 VNC 端口）
   - 修改 `sesman.ini` 的 `ListenPort` 避免冲突

3. **通道服务**
   - `xrdp-chansrv` 以 perp 服务 `xN-chansrv` 运行
   - 提供剪贴板共享、文件传输等 RDP 通道功能

### 数据流

```
RDP Client (mstsc/FreeRDP)
        │
        ▼ port 51089
┌─────────────────────┐
│       xrdp          │── libvnc.so ──► Xvnc (:1, port 5901)
│   (xrdp.ini)        │
│                     │── chansrv ────► 剪贴板/文件传输
│   sesman (认证)      │
└─────────────────────┘
```

### 认证机制

- 默认密码：用户 `headless`，密码在 `.arg` 中通过 `VNC_PASS` / `VNC_PASS_RO` 设置
- VNC 密码文件 `/etc/xrdp/vnc_pass` 由 `vncpasswd` 生成，Xvnc 和 x11vnc 共用
- 非默认密码时自动切换 `password=ask` 模式

---

## 运行时配置（.arg 文件）

无需重建镜像，通过挂载 `.arg` 文件动态修改配置；修改后 `docker-compose restart desktop` 即可生效。值与 `.arg.sample` 默认一致：

```bash
# Desktop Configuration
#   DISPLAY default is :1 (use :3 or other values for testing)
SSH_PASS=headless           # SSH 密码（默认 headless）
VNC_PASS=headless           # VNC 读写密码
VNC_PASS_RO=View123         # VNC 只读密码
HOME=/_ext/home/headless    # 用户家目录
START_SESSION=openbox-session  # 桌面会话（openbox-session / startxfce4 / startfluxbox）
HEADLESS=true               # true=纯 Xvnc 虚拟显示; false=X.org 物理 HDMI + x11vnc
DISPLAY=:1                  # X11 Display 编号
TZ=Asia/Shanghai            # 时区
L=zh_CN                     # 语言
```

---

## 目录结构

```
├── .arg.sample              # 运行时配置模板
├── .dockerignore / .gitignore
├── AGENTS.md                # AI 助手指南
├── README.md
├── TODO.md                  # 开发待办/踩坑记录索引
├── buildx.sh                # 多架构多发行版构建脚本
├── docker-compose.yml       # Docker Compose 编排
│
├── src/
│   ├── entry-x11base.sh     # 主入口（387 行，perp 服务编排，配置热加载）
│   ├── xvnc2.sh             # 服务调度器（xvnc/xorg/x11vnc/chansrv/pulse/dbus/udev/nm）
│   ├── Dockerfile.app-ubuntu    # Ubuntu 版
│   ├── Dockerfile.app-debian    # Debian 版
│   ├── Dockerfile.app-alpine    # Alpine 精简版
│   ├── Dockerfile.zyp-opensuse  # OpenSUSE 版
│   └── bin/
│       ├── input.sh             # X11 输入设备配置（AutoAddDevices + 逐设备 evdev）
│       ├── f12_to_tty1.sh       # F12 切 tty1（并发监听所有键盘）
│       ├── f12_single.sh        # F12 切 tty1（单选一个键盘）
│       └── xrandr-1600x900.sh   # 分辨率辅助
│
├── docs/                    # 开发笔记（b 系列=调试记录，数字=主题）
│   ├── 00-0520-ref-init.md
│   ├── 01-0525-alsa-pulseaudio.md
│   ├── 02-0525-x11base-ubt2004.md
│   ├── b1-0527-host-deb1211.md
│   ├── b2-0901-ctvirter-vm-oe2203.md
│   ├── b3-260518-multiDesk.md
│   ├── b4-260611-aicoder.md
│   ├── b5-260621-项目代码分析.md
│   ├── b6-260917-f12-chvt-fix.md
│   ├── b7-260917-input-sh.md
│   ├── data/                # 调试数据/配置备份
│   └── superpowers/         # 架构设计文档
│
└── .github/workflows/
    └── docker-image-build.yml   # CI 自动构建（push dev 分支触发）
```

---

## 部署

### docker-compose（推荐）

```yaml
# 与仓库 docker-compose.yml 一致
version: "2.4"
services:
  desktop:
    image: registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:${TAG:-app-ubuntu-22.04}
    entrypoint: bash /entry-x11base.sh
    hostname: hdmi-desktop
    restart: none
    privileged: true
    network_mode: host
    devices:
      - "/dev:/dev"
    volumes:
      - ./src/bin/:/usr/local/bin/
      - ./src/entry-x11base.sh:/entry-x11base.sh
      - ./src/xvnc2.sh:/xvnc2.sh
      - ./.arg:/.arg
      - /_ext:/_ext
```

### docker run

```bash
docker run -d \
  --privileged \
  --network=host \
  --restart=always \
  -v /dev:/dev \
  -v /_ext:/_ext \
  -v ./src/bin/:/usr/local/bin/ \
  -v ./src/entry-x11base.sh:/entry-x11base.sh \
  -v ./src/xvnc2.sh:/xvnc2.sh \
  -v ./.arg:/.arg \
  registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04 \
  bash /entry-x11base.sh
```

---

## Dockerfiles 多版本说明

| Dockerfile | 基础镜像 | 特点 | 适用场景 |
|-----------|---------|------|---------|
| `Dockerfile.app-ubuntu` | `x11-base:app-ubuntu-*` | 应用型，体积较小 | 通用桌面（默认 tag=app-ubuntu-22.04） |
| `Dockerfile.app-debian` | `x11-base:core-debian-*` | 传统稳定 | 服务器/嵌入式 |
| `Dockerfile.app-alpine` | `x11-base:app-alpine-*` | 极简 | 资源受限设备 |
| `Dockerfile.zyp-opensuse` | OpenSUSE 15.x | RPM 系 | OpenSUSE 用户（构建脚本未启用） |

---

## 构建

单命令构建并推送全部发行版/架构（buildx 多平台：linux/amd64,linux/arm64）：

```bash
bash buildx.sh x11base-all
```

实际构建的 tag（`buildx.sh` 当前启用）：

| 发行版 | tag |
|--------|-----|
| Ubuntu | app-ubuntu-18.04 / 20.04 / 22.04 / 24.04 |
| Alpine | app-alpine-3.13 / 3.19 / 3.23 |
| Debian | core-debian-9 / 10 / 11 / 12 |

> `hdmi` 等单一目标分支已注释移除，统一走 `x11base-all`。

---


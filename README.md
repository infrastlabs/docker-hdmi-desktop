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
              ├── xN-udev     —— 设备热插拔管理
              ├── xN-de       —— 桌面环境（Openbox/Xfce/Fluxbox）
              └── ssh         —— SSH 远程登录
```

### 多种访问方式

| 方式 | 说明 | 默认端口 (Display :1) |
|------|------|----------------------|
| **HDMI 直连** | X.org 直接输出到物理显示器 | - |
| **TigerVNC (Xvnc)** | 虚拟显示远程桌面（标准 VNC 客户端） | `51081` |
| **x11vnc** | 共享物理 HDMI 显示给 VNC | `51082` |
| **xRDP** | Windows 远程桌面 (RDP) 协议 | `51089` |
| **noVNC** | 浏览器中访问 VNC 桌面 | `52081` |
| **SSH** | 命令行终端登录 | `51022` |

> 端口根据 Display 编号自动偏移：`base + (N-1) * 1000`

---

## xRDP 集成细节

xRDP 使用 **Xvnc 后端** (`lib=libvnc.so`)，RDP 会话连接到底层 TigerVNC 服务，实现 RDP 与 VNC/noVNC 共享同一个桌面会话。

### 配置流程

1. **端口动态分配**（`entry-x11base.sh`）
   - `PORT_RDP` = `10089 + (DISPLAY_NUM-1) * 1000`
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

无需重建镜像，通过挂载 `.arg` 文件动态修改配置。参考 `.arg.sample`：

```bash
# 基础配置
DISPLAY=:1                   # X11 Display 编号
START_SESSION=openbox-session # 桌面会话（openbox-session / startxfce4 / startfluxbox）
HOME=/_ext/home/headless     # 用户家目录

# 本地化
L=zh_CN                      # 语言
TZ=Asia/Shanghai             # 时区

# 密码
SSH_PASS=your_ssh_pass       # SSH 密码
VNC_PASS=your_vnc_pass       # VNC 读写密码
VNC_PASS_RO=your_ro_pass     # VNC 只读密码

# 扩展服务
HEADLESS=true                # 纯 VNC 模式（无物理 HDMI）
```

---

## 目录结构

```
├── .arg.sample              # 运行时配置模板
├── .env.sample              # docker-compose 环境变量
├── docker-compose.yml       # Docker Compose 编排
├── buildx.sh                # 多架构构建脚本
│
├── src/
│   ├── entry-x11base.sh     # 主入口（385行，perp 服务编排）
│   ├── entrypoint.sh        # 原版入口（Hilscher）
│   ├── entrypoint2.sh       # 过渡版入口
│   ├── xvnc2.sh             # 服务调度器（Xvnc/Xorg/x11vnc/pulse...）
│   ├── Dockerfile           # Debian Buster 版
│   ├── Dockerfile.app-ubuntu    # Ubuntu 版
│   ├── Dockerfile.app-ubuntu2   # Ubuntu 增强版
│   ├── Dockerfile.app-debian    # Debian 全系列版
│   ├── Dockerfile.app-alpine    # Alpine 精简版
│   ├── Dockerfile.zyp-opensuse  # OpenSUSE 版
│   └── bin/
│       ├── input.sh             # X11 输入设备配置
│       └── xrandr-1600x900.sh   # 分辨率辅助
│
├── docs/                    # 开发笔记
│   ├── 01-0525-alsa-pulseaudio.md
│   ├── 02-0525-x11base-ubt2004.md
│   ├── b1-0527-host-deb1211.md
│   ├── b2-0901-ctvirter-vm-oe2203.md
│   ├── b3-260518-multiDesk.md
│   ├── b4-260611-aicoder.md
│   └── superpowers/         # 架构设计文档
│       ├── plans/
│       └── specs/
│
└── .github/workflows/
    └── docker-image-build.yml   # CI 自动构建
```

---

## 部署

### docker-compose（推荐）

```yaml
version: "2.4"

services:
  desktop:
    image: registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04
    network_mode: host
    privileged: true
    entrypoint: bash /entry-x11base.sh
    volumes:
      - ./src/bin:/usr/local/bin
      - ./src/entry-x11base.sh:/entry-x11base.sh
      - ./.arg:/.arg
      - /dev:/dev
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
  -v ./.arg:/.arg \
  registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04 \
  bash /entry-x11base.sh
```

---

## Dockerfiles 多版本说明

| Dockerfile | 基础镜像 | 特点 | 适用场景 |
|-----------|---------|------|---------|
| `Dockerfile` | `balenalib/debian:buster` | 完整桌面 + VNC + AnyDesk | netPI/RPi 原始目标 |
| `Dockerfile.app-ubuntu` | `x11-base:app-ubuntu-*` | 应用型，体积较小 | 通用桌面 |
| `Dockerfile.app-debian` | `x11-base:core-debian-*` | 传统稳定 | 服务器/嵌入式 |
| `Dockerfile.app-alpine` | `x11-base:app-alpine-*` | 极简 | 资源受限设备 |
| `Dockerfile.zyp-opensuse` | OpenSUSE 15.x | RPM 系 | OpenSUSE 用户 |

---

## 构建

```bash
# 构建所有架构
bash buildx.sh x11base-all

# 仅构建 HDMI 目标
bash buildx.sh hdmi
```

---


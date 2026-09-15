# AGENTS.md — AI 助手指南

## 项目概述

Docker 容器桌面环境，支持 HDMI 物理输出 + 远程访问（VNC/xRDP/noVNC/SSH）。多架构（amd64/arm64/arm）多发行版（Debian/Ubuntu/Alpine/OpenSUSE）。

## 关键命令

```bash
# 构建
bash buildx.sh x11base-all          # 构建所有架构/发行版
bash buildx.sh hdmi                 # 仅构建 HDMI 目标

# 运行
docker-compose up -d                # 启动容器
docker-compose restart desktop      # 重启（重读 .arg 配置）

# 本地测试
docker cp src/entry-x11base.sh 容器ID:/entry-x11base.sh
docker exec -it 容器ID bash
```

## 代码风格

- **入口脚本** (`src/*.sh`)：Bash，函数名 `camelCase`，变量 `UPPER_SNAKE`（环境变量/配置）、`lower_snake`（局部），`# === N. Title ===` 分隔段落
- **添加新服务**：在 `xvnc2.sh` 的 `case` 中添加分支，在 `entry-x11base.sh` 的 `oneVnc()` 中用 `addPerpService` 注册
- **Dockerfile**：多阶段构建，`ARG TARGETARCH` 开头，`--no-install-recommends` 减体积
- **配置文件**：yaml 用 2 空格缩进
- **中文文档**：README、AGENTS、docs/ 使用中文；README.origin.md 保留原版英文

## 文件模式

| 路径 | 说明 |
|------|------|
| `src/Dockerfile` | 主 Dockerfile（Debian Buster） |
| `src/Dockerfile.app-*` | 多发行版 Dockerfile |
| `src/entry-x11base.sh` | **主入口脚本**（修改最频繁） |
| `src/xvnc2.sh` | 服务调度分发 |
| `src/bin/*.sh` | 辅助脚本 |
| `.arg.sample` | 运行时配置模板 |
| `buildx.sh` | 构建脚本 |
| `docs/` | 调试与开发记录 |

## 工作流

- **分支策略**：`dev` 为主开发分支，功能分支命名 `feat/xxx`
- **配置热加载**：修改 `.arg` 后 `docker-compose restart desktop`，无需重建镜像
- **调试**：`docker exec` 进入容器，用 `sv s /etc/perp/{x1-xvnc,x1-de,...}` 控制单个服务

## 验证

- Bash 脚本：`bash -n src/entry-x11base.sh` 检查语法
- Dockerfile：`docker build -f src/Dockerfile.app-ubuntu --no-cache --pull .` 验证构建
- 运行测试：启动容器，检查 `sv s /etc/perp/` 下所有服务均为 `up` 状态

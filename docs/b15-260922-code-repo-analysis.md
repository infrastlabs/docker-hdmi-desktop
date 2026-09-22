# b15-260922 | 代码仓库分析

> 主题：awesomeWM 生态的代码仓库分析。本文档按节展开，目前收录 **fork / 改名项目**、**上游仓库本体结构**、**静态编译改造可行性** 三节，组织仓库与方法学沉淀待后续补充。
> 背景：延续 b11 十二章"除了 Awesome，还有别的 Lua 配置平铺 WM 吗"的结论，进一步排查 **AwesomeWM 自己的 fork 与改名/移植项目**——既然没有第二个 Lua 平铺 WM，那"养在 Awesome 旁边的平行项目"能不能当后备选项？
> 说明：GitHub API 未认证限额 60 次/小时，本次已耗尽，全部结论用 `git fetch --filter=blob:none` 走 git 协议实测，数据可信。快照日期 2026-09-22。

## 一、awesomeWM fork 生态仓库分析

### 1、上游基线与方法

| 项 | 值 |
|----|----|
| 上游 | [awesomeWM/awesome](https://github.com/awesomeWM/awesome)，6960 stars、631 forks、last push 2026-08-28 |
| 上游 master tip | `0a5e50cf`（2026-08-28）`fix(awful.placement): round margins and offsets to whole pixels (#4122)` |
| 上游历史深度 | **11088 commits**（完整 unshallow 后） |
| fork 总数 | **626 个**（分 7 页拉全） |

判定方法：

```bash
git fetch --filter=blob:none https://github.com/awesomeWM/awesome.git master:refs/remotes/up
git fetch --filter=blob:none https://github.com/<owner>/<repo>.git refs/heads/<br>:refs/remotes/xf/<br>
git rev-list --count up..<br>      # ahead：fork 独有提交
git rev-list --count <br>..up      # behind：落后上游的提交
```

`--filter=blob:none` 只取提交图不取内容，11000+ commit 的仓库也能秒级完成。ahead=0 意味着**纯镜像**，没有任何独立开发。

### 2、有实质独立开发的 fork（7 个）

| 项目 | 最新提交 | ahead / behind | 分支 | 独立开发内容 |
|------|------|------|------|------|
| [GabrielHoy/awesome](https://github.com/GabrielHoy/awesome) | 2026-04-11 | **23 / 16** | master | **Lua → Luau 移植**：消灭 Lua 依赖、保持配置向后兼容、上游测试全过。提交见 "Lua rebase progress towards Luau; shimming"、"luau api docs third-party" |
| [sammy-ette/awesome](https://github.com/sammy-ette/awesome) | 2026-08-04 | 47 / 50 | `skia-with-vibes`（57 / 50） | **wibox 增加 Skia 渲染后端 + XCB bindings**。工程水平粗糙，提交信息为 "bleh"、"lol"、"full port (somewhat)" |
| [Aire-One/awesome](https://github.com/Aire-One/awesome) | 2026-08-25 | 4 / 10 | `chore/support-lua-55` | **48 个分支**，最活跃的贡献者工作台：Lua 5.5 支持、大量文档修正、issue 追踪分支。多数改动已走 PR 合入上游 |
| [curiosity-tests/awesome](https://github.com/curiosity-tests/awesome) | 2026-09-18 | **6 / 0** | master | 纯 CI 基建："linux-only testbed"、"a real observables check"、fork-testbed patch。另有 `lua54` 分支（2020 停更） |
| [corpix/awesome](https://github.com/corpix/awesome) | 2026-08-21 | 3 / 6 | `corpix`（默认）、`feature/sticky-child-windows`（5 / 6） | sticky 状态继承到 transient client、nix infra、兼容 CI |
| [shuber2/awesome](https://github.com/shuber2/awesome) | 2026-09-13 | 1 / 0 | `fix/spawn-easy-async-algorithmiccomplexity` | 单个 perf fix：`awful.spawn` 避免 O(n²) 输出累积 |
| [diyism/awesome](https://github.com/diyism/awesome) | 2026-08-28 | 24 / 50 | master | ahead 数不低但全是 `rc.lua` / `01-readme.md` 编辑，**个人配置 fork 而非开发 fork** |

### 3、已停滞但有历史价值的 fork

- [actionless/awesome](https://github.com/actionless/awesome)：`actionless` 分支 ahead=94，但最后提交 **2020-04-24**。52 个分支（wibox-shape、zaphod-mode、grow-master、next 等），当年贡献深度很大，现已无人维护。`next` 分支停在 2009-12-05。
- [Elv13/awesome-1](https://github.com/Elv13/awesome-1)：9 stars、3 forks、100+ 分支，但 master 停在 **2017-12-05**（behind=2174）。**这不是开发 fork，是镜像**——描述原文 *"Semi-official mirror of the awesome window manager from git://git.naquadah.org/awesome.git, updated hourly"*。要 naquadah.org 原始 git 仓库时这是唯一活着的 GitHub 副本入口。同门 [Elv13/awesome](https://github.com/Elv13/awesome) 也停在 2013-01-11（ahead=5 / behind=5354）。

### 4、纯镜像 / 冻结在旧 commit

ahead=0 即纯镜像。多个 fork 冻结在同一个 commit 上，说明它们只是批量创建后没同步：

| 冻结 commit | 日期 | 提交信息 | 涉及 fork |
|---|---|---|---|
| `ef525c2e` | 2026-05-19 | `chore(mergify): add lua5.5 to conditions` | harishpiyer/awesome_28、gizzye/awesome、SkrOYC/awesome、OneToughMonkey/awesome、corpix/awesome(master) |
| `c104846a` | 2026-04-24 | `doc(naughty.notification): use message instead of text (#4095)` | miranda/awesome、soderstrom-rikard/awesome-wm、furinafan69/awesome |
| `c104846a` 后 56 | 2025-11-07 | `fix(layouts: fixed): add make_widget_from_value() in fixed:insert()` | ForksMD/awesome |

有星标的 fork 全部在 9 星以下（way-cooler/awesome 9\*、Elv13/awesome-1 9\*、0xBlockchainx0/awesome-3 3\*、Thejerk400/VM-Awesome400 2\*、ODEX-TOS/awesome 2\*、actionless/awesome 2\*），**没有任何 fork 形成独立社区**。

### 5、已消失的改名 / 移植项目

```
luizluca/awesome-nodmenu         不存在/404
awesome-nodmenu/awesome-nodmenu  不存在/404
awesomeWM/awesome-nodmenu        不存在/404
nirvanaxm/nirvanaxm              不存在/404
Elv13/awesome-2                  不存在/404
Elv13/awesome-3                  不存在/404
```

值得注意的是：**当年最有名的功能型 fork——把 nodmenu 直接编进 awesome 的 `luizluca/awesome-nodmenu`——已经消失**。这是历史上最值得关注的 Awesome 衍生项目，消失得最可惜。

### 6、awesomeWM 组织本身的仓库状态

作为对照，官方组织 [awesomeWM](https://github.com/awesomeWM) 共 9 个仓库，除了主项目外**没有一个是活跃的功能分叉**：

| 仓库 | stars | 最后推送 | 性质 |
|------|------|------|------|
| [awesomeWM/awesome](https://github.com/awesomeWM/awesome) | 6960 | 2026-08-28 | 主项目 |
| [awesomeWM/apidoc](https://github.com/awesomeWM/apidoc) | 11 | 2026-08-28 | API 文档站 |
| [awesomeWM/oocairo](https://github.com/awesomeWM/oocairo) | 25 | 2025-08-10 | Lua 的 Cairo 绑定 |
| [awesomeWM/awesome-www](https://github.com/awesomeWM/awesome-www) | 61 | 2024-03-18 | 官网 |
| [awesomeWM/awesomeWM.github.io](https://github.com/awesomeWM/awesomeWM.github.io) | 2 | 2022-09-28 | 旧官网 |
| [awesomeWM/awesome-releases](https://github.com/awesomeWM/awesome-releases) | 8 | 2019-01-28 | 发布分支存档 |
| [awesomeWM/LDoc](https://github.com/awesomeWM/LDoc) | 1 | 2017-09-19 | 文档生成工具 |
| [awesomeWM/awesome-www-backup-old](https://github.com/awesomeWM/awesome-www-backup-old) | 5 | 2016-05-19 | 旧站静态镜像 |
| [awesomeWM/oopango](https://github.com/awesomeWM/oopango) | 4 | 2014-10-21 | Lua 的 Pango 绑定 |

### 7、结论

- 626 个 fork 里**真正有持续独立开发的只有 7 个**，其中算方向性改造的只有两个：
  - **[GabrielHoy/awesome](https://github.com/GabrielHoy/awesome)**——唯一的换语言移植（Lua → Luau），野心最大、风险最高，23 个独有提交。
  - **[sammy-ette/awesome](https://github.com/sammy-ette/awesome)**——唯一的渲染层改造（Skia 后端），57 个独有提交但工程水平粗糙。
- 其余都是 CI 基建、单个 perf fix、文档修正、或 Lua 5.5 支持这类小增量。
- **没有任何 fork 形成独立社区**：最高星标 9，多数 fork 是批量创建后冻结在旧 commit 的镜像。
- 历史上最有名的功能型 fork（awesome-nodmenu）已 404。

### 8、对本项目的影响

- 印证并加深了 b11 十二章的结论：想给 Lua 平铺 WM 找一个"后备平行项目"，**现状比预期更糟**——不但没有第二个 Lua 平铺 WM，连 Awesome 自己的 fork 里也找不出第二个能长期养的项目。
- 容器里的现实路径不变：Alpine/musl 只能 `apk add awesome` 用**上游本体**（见 b10），不存在更轻的替代品。
- 若真要做渲染层或 Lua 版本跟进，可直接跟踪 GabrielHoy 的 Luau 移植与 Aire-One 的 Lua 5.5 分支，但它们都不适合容器直接引入。
- 选型优先级维持 i3 > bspwm > Awesome 不变（见 b11 十一、十二、十三章）。

### 9、方法学备注

- GitHub API 未认证限额 **60 次/小时**，本次排查中途耗尽（`API rate limit exceeded for 175.178.5.200`），compare / branches 接口随后不可用。
- 改用 git 协议（`git fetch`、`git ls-remote`、`git rev-list`）绕开限额，结论不依赖 API 缓存，可复现。
- `compare/...` 的 `ahead_by` / `behind_by` 字段在未认证且超限时返回空，不能用它判定 fork 关系，必须自己算 rev-list。
- 404 判定用 `git ls-remote <url> HEAD`，比 HTTP 状态码更可靠（能区分权限与不存在）。

### 10、上游仓库本体结构（补充）

> 数据取自上游 `master` tip `0a5e50cf`（2026-08-28）全量克隆，完整历史 11088 commits。

#### 10.1 仓库体量

| 项 | 值 |
|----|----|
| 文件总数 | **1265** |
| 工作树总大小 | **5,887,759 B（约 5.89 MB）** |
| `.git` 浅克隆（depth=1） | 2.2 MB |
| 完整历史 | 11088 commits |

按扩展名（前 10）：

| 扩展名 | 文件数 | 字节数 | 均大小 |
|------|------|------|------|
| `.lua` | **883** | 3,529,652 B | 3,997 B |
| `.png` | 133 | 608,906 B | 4,578 B |
| `.txt` | 58 | 103,413 B | 1,783 B |
| `.c` | **49** | 808,388 B | 16,498 B |
| `.h` | **49** | 140,604 B | 2,869 B |
| `.md` | 14 | 153,818 B | 10,987 B |
| `.ldoc` | 14 | 59,620 B | 4,259 B |
| `.svg` | 9 | 233,649 B | 25,961 B |
| `.sh` | 9 | 20,170 B | 2,241 B |

Lua 占文件数 **69.8%**（883/1265）。

#### 10.2 行数：Lua 是 C 内核的 4.5 倍

| 语言 | 行数 | 占比 |
|------|------|------|
| `.lua` | **110,144** | 79.3% |
| `.c` | 24,641 | 17.7% |
| `.h` | 4,123 | 3.0% |

三项合计 138,908 行。

`lua : c = 110,144 : 24,641 ≈ 4.47 : 1`。C 内核平均每个文件 16.5 KB，Lua 平均每个文件仅 4 KB——**C 是密集的内核，Lua 是大量小模块**。

#### 10.3 Lua 生产代码 vs 测试代码

| 分区 | 文件数 | 行数 |
|------|------|------|
| **生产代码**（`lib/`；`objects/`、`common/`、`utils/` 下无 lua 文件） | 170 | **58,500** |
| **测试代码**（`tests/` + `spec/`） | 699 | **49,227** |

测试代码量达生产代码的 **84%**（49,227 / 58,500），是 Lua 文件总数的大头（699/883 = 79%）。这与第 7 节"fork 生态冷清"形成对比：**上游自身在测试上投入很重，但没有外部贡献者跟进**。

#### 10.4 C 内核分层

49 个 `.c` 文件的分布：

| 位置 | 数量 | 说明 |
|------|------|------|
| 仓库顶层 | 23 | 单文件模块：`awesome.c`、`banning.c`、`color.c`、`dbus.c`、`draw.c`、`event.c`、`ewmh.c`、`keygrabber.c`、`luaa.c`、`mouse.c`、`mousegrabber.c`、`options.c`、`property.c`、`root.c`、`selection.c`、`spawn.c`、`stack.c`、`strut.c`、`systray.c`、`xkb.c`、`xkb_utf32_to_keysym_compat.c`、`xrdb.c`、`xwindow.c` |
| `objects/` | 12 | 暴露给 Lua 的对象：`button.c`、`client.c`、`drawable.c`、`drawin.c`、`key.c`、`screen.c`、`selection_acquire.c`、`selection_getter.c`、`selection_transfer.c`、`selection_watcher.c`、`tag.c`、`window.c` |
| `common/` | 11 | 通用基础设施：`atoms.c`、`backtrace.c`、`buffer.c`、`luaclass.c`、`lualib.c`、`luaobject.c`、`util.c`、`version.c`、`xcursor.c`、`xembed.c`、`xutil.c` |
| `tests/` | 2 | C 层测试 |
| `build-utils/` | 1 | 构建辅助 |

内核结构清晰：**顶层 23 个模块各管一个 X11/事件/UI 子域，`objects/` 与 `common/` 是支撑层**。总量 24,641 行 + 4,123 行头文件，属于可完整读完的内核规模。

#### 10.5 Lua 模块分层

`lib/` 下 170 个 `.lua` 文件的二级分布：

| 子目录 | 文件数 | 行数 |
|------|------|------|
| `lib/awful/` | 74 | **28,041** |
| `lib/wibox/` | 42 | **15,984** |
| `lib/gears/` | 20 | 5,488 |
| `lib/naughty/` | 20 | 5,392 |
| `lib/menubar/` | 5 | 1,564 |
| `lib/beautiful/` | 4 | 1,026 |
| `lib/ruled/` | 3 | 991 |
| `lib/` 根 | 2 | 14 |

`awful`（用户态 API 层）独占 **74 个文件、28,041 行**，是 `lib/` 近一半体量（28,041 / 58,500 = 48%）；`wibox`（widget / layout 框架）紧随其后，15,984 行。两者合计占 `lib/` 的 **75%**。

单个最大的 Lua 文件（生产代码）：

| 文件 | 行数 |
|------|------|
| `lib/awful/client.lua` | 1,971 |
| `lib/awful/tag.lua` | 1,968 |
| `lib/awful/placement.lua` | 1,702 |
| `lib/wibox/layout/grid.lua` | 1,631 |
| `lib/awful/titlebar.lua` | 1,214 |
| `lib/naughty/notification.lua` | 1,142 |
| `lib/awful/widget/tasklist.lua` | 1,135 |
| `lib/awful/screen.lua` | 1,103 |
| `lib/wibox/container/border.lua` | 1,059 |

最大的 9 个文件合计 12,925 行，全部在 `awful/` 与 `wibox/`——与第 2 节中 fork 的改动面（`wibox` 加 Skia 后端、`awful.spawn` perf、`awful.widget.keyboardlayout`）高度吻合。

#### 10.6 构建与工具链

| 类别 | 文件 |
|------|------|
| 构建 | `Makefile`（47 行，**仅为 CMake 的薄封装**：建 `build/` 目录、跑 `cmake`、`make -C build`）、`CMakeLists.txt`、`AutoOption.cmake`、`Packaging.cmake`、`awesomeConfig.cmake`、`cmake/` |
| 版本注入 | `awesome-version-internal.h` |
| 测试 | `.busted`（Lua busted 运行器）、`.luacheckrc`、`.luacov`、`codecov.yml` |
| CI | `.mergify.yml`、`.github/` |
| 其他 | `.editorconfig`、`.gitignore` |

**Makefile 不是独立的第二套构建链，而是 CMake 的 47 行薄封装**（建 `build/` → 跑 `cmake` → `make -C build`）。README 主路径就是 `make` + `sudo make install`。上游只有一个真正的构建系统：CMake。

#### 10.7 对本项目的影响

- 上游"重 Lua、轻 C"的结构直接印证了 b10 的判断：**容器里难的不是编译（24,641 行 C，可完整读完），而是 Lua 运行时的依赖链**（Cairo / Pango / dbus 的 Lua 绑定，即组织仓库里的 `oocairo`、`oopango`）。C 内核本身不构成静态化障碍。
- `objects/`（12 个 `.c`）是 Lua 对象系统所在层，GabrielHoy 的 Luau 移植（第 2 节，ahead=23）如果要保持配置兼容，绕不开这一层——这也解释了该移植为何进展慢。
- `awful/` 占 `lib/` 近一半体量，任何"更轻的 Awesome 变体"都必须动这一层，风险集中。
- 容器路线结论不变：`apk add awesome` 用上游本体（见 b10），无更轻替代；选型优先级 i3 > bspwm > Awesome 不变。

## 二、静态编译改造可行性分析（对标 gitee docker-x11base）

> 参照仓库：`gitee.com/infrastlabs/docker-x11base`（HEAD `ec370b896a6e`，212 文件），已把 dwm / openbox / fluxbox / pulseaudio / xrdp / tigervnc / x11vnc / dropbear / tint2 / xcompmgr 等 20+ 组件在 musl/Alpine 上全静态编译落地。
> 结论先行：**方法论可照搬，但它的适用边界恰好卡在 dlopen 链——它做的 20 多个项目全部没有 GI 反射，awesome 是唯一做不了的那个。全静态改造 awesome 不可行；半静态可行但对容器收益 ≈ 0。**

### 0、参照仓库概况

| 项 | 值 |
|----|----|
| 仓库 | `gitee.com/infrastlabs/docker-x11base`，HEAD `ec370b896a6e` |
| 规模 | 212 文件（源码 + docs + rootfs + pkgs + compile） |
| 定位 | 跨发行版桌面容器（musl/deb/rpm 系 12+ 发行版），特色是 **suckless misc 静态编译产物可跨发行版通用** |
| 已落地静态编译 | dwm、st、dmenu、openbox、fluxbox、xcompmgr、tint2、xlunch、feh、pcmanfm、lxde、geany、tigervnc、x11vnc、xrdp、pulseaudio、dropbear、perp、n2n、tinc 等 20+ |
| 构建入口 | `compile/`（builder 镜像 + 多 stage Dockerfile + 各组件 `build.sh`） |

**关键事实：全仓 212 文件 grep 不到任何 awesome**（`grep -ril "awesome"` 返回空）。20+ 个组件全部在纯 C / 无 GI 反射范畴——见 3.1 节，这是"awesome 全静态做不到"的最直接外部佐证。

### 1、参照仓库的静态编译方法论（4 层）

| 层 | 做法 | 出处 |
|----|------|------|
| 1. 构建器 | `tonistiigi/xx` 交叉工具链 + `alpine:3.15` + UPX 4.0.1 | `builder/Dockerfile.builder` |
| 2. 依赖静态化 | 两条路：`apk add *-static` 取现成静态库；或源码自编 `--disable-shared --enable-static`（meson 项目用 `-Ddefault_library=static`） | `openbox/build.sh` 的 `pango()`、`libxrandr()`、`fontconfig()` |
| 3. 主程序链接 | `LDFLAGS="-Wl,--as-needed --static -static -Wl,--strip-all"` + `CFLAGS="-Os -fomit-frame-pointer"` + `CC=xx-clang` | `compile/src/common.sh` |
| 4. 校验压缩 | `xx-verify --static <bin>` 逐个验 + `upx` | 每个 `build.sh` 末尾 |

**两个关键技巧值得抄**：

```sh
# openbox：libtool 会重排 LDFLAGS 参数，必须用 start/end-group 包住整串库
LDFLAGS="$LDFLAGS -Wl,--start-group $OB_LIBS -Wl,--end-group"

# openbox：静态化时主动关掉一批可选功能（7 个 --disable）
--disable-nls --disable-xcursor --disable-librsvg
--disable-startup-notification --disable-session-management
--disable-xkb --disable-xinerama
```

**最关键的一行**在 openbox 编 pango 时：

```sh
abuild-meson -Ddefault_library=static \
             -Dintrospection=disabled \   # ← 就是这一行
             -Dgtk_doc=false
```

openbox 的做法是**把 introspection 整个关掉**，它有这个开关。awesome 没有。

### 2、主体需要改造的内容项（按可改造性三级）

#### A 类：可以照搬，纯工程活（5 项）

| # | 改造项 | 具体做法 | 参考 |
|---|--------|---------|------|
| 1 | builder 镜像 | 复刻 `Dockerfile.builder`：alpine + `tonistiigi/xx` 交叉工具链 + UPX | 直接抄 |
| 2 | Dockerfile 多阶段 | 仿照 `compile/Dockerfile`（374 行）的 `FROM base AS xxx` 分 stage，每个 WM 一个 stage，各自 `ARG COMPILE_XXX=yes` 开关 | `compile/Dockerfile` |
| 3 | 依赖静态化 | awesome 需 **22 个 pkg-config 依赖**（`xcb` + `glib-2.0`、`gdk-pixbuf-2.0`、`cairo`、`cairo-xcb`、`x11`、`xcb-cursor`、`xcb-randr`、`xcb-xtest`、`xcb-xinerama`、`xcb-shape`、`xcb-util`、`xcb-keysyms`、`xcb-icccm`、`xcb-xfixes`、`xcb-xkb`、`xcb-xrm`、`xkbcommon`、`xkbcommon-x11`、`libstartup-notification-1.0`、`xproto`、`libxdg-basedir`），逐个找 `*-static` 包或源码自编 | `awesomeConfig.cmake:130-165` |
| 4 | 链接参数 | `-static` + `-Wl,--start-group/--end-group` 包整套库 | `openbox/build.sh` |
| 5 | 项目集成 | 本项目侧：新增 `src/Dockerfile.app-alpine-static`、`.arg` 加 `STATIC_WMS=1`、`entry-x11base.sh` 的 `oneVnc()` 加分支 | 本仓 AGENTS.md 模式 |

#### B 类：改完也没用（1 项）

| # | 改造项 | 为什么没用 |
|---|--------|-----------|
| 6 | 静态链接整套依赖（glib/cairo/pango/gdk-pixbuf） | 就算 22 个库全部 `-static` 成功链入，`require("lgi")` 依然要 dlopen。b10 七.2 已证：`-rdynamic` / `ENABLE_EXPORTS` 恰恰证明符号必须暴露给运行时加载的 `lgi.so` |

#### C 类：真正的障碍，无改造方案（1 项）

| # | 障碍项 | 实证 |
|---|--------|------|
| 7 | **LGI → GI 反射链** | `grep -in "lgi\|introspection" CMakeLists.txt` 只返回 Lua 静态库那两行注释——**没有任何 CMake 开关能关掉** |

### 3、会失效的细节功能（按依赖链分组，均有源码实证）

#### 3.1 最先死的：`require("gears")` 就立即加载

`awesomerc.lua`（585 行）第 1 行是 `pcall(require, "luarocks.loader")`，第 4 行是 `local gears = require("gears")`。而 `lib/gears/init.lua` 是**立即加载 16 个子模块**，其中 `color`、`surface`、`object`、`timer`、`wallpaper`、`shape` 全部直接 `require("lgi")`。

即：**默认配置一个字符都跑不到**。更绝的是 C 内核自己也探 lgi：

```c
// common/version.c:51  eprint_version()
(void) luaL_dostring(L, "return require('lgi.version')");
```

连 `awesome --version` 都依赖 lgi 能加载。

#### 3.2 逐条失效清单

| 功能 | 断链点 | 实证 |
|------|--------|------|
| **所有 wibox widget 的绘制** | `wibox/drawable.lua:17` → `require("lgi").cairo` | **这一行是所有 widget 的绘制总入口** |
| **时间时钟 textclock** | `textclock.lua:51` → `require("lgi").GLib` | 定时器走 GLib main loop |
| **任务栏/布局/菜单图标** | `lgi.GdkPixbuf` | `naughty/core.lua`、`beautiful/init.lua` 均消费 `gears.surface` |
| **通知系统 naughty** | 图标 + 超时 + 布局 | `naughty/` 下 **5/6** 文件依赖 lgi；`gears.timer` 消费点 4 处 |
| **主题系统 beautiful** | 颜色全走 `gears.color` | **35 个文件**依赖 `gears.color` |
| **菜单栏 menubar** | D-Bus 菜单 + GdkPixbuf 图标 | `menubar/` 下 **3/5** 文件依赖 lgi |
| **壁纸 awful.wallpaper** | cairo surface | `gears/wallpaper.lua` → `gears.surface` |
| **对象/信号/属性系统** | `gears.object` 基类 | 消费方：awful 11 + gears 4 + naughty 3 + wibox 2 + ruled 2 + wibox/widget 1 |
| **滚动容器** | `gears.timer` | `wibox/container/scroll.lua` |
| **异步命令输出 awful.widget.watch** | `lgi.Gio` 异步流 | b10 十.2 / lgi #363 |
| **第三方模块（Lain/bling/vicious）** | `require()` 加载 C 模块 | 全要 dlopen，一个都装不上 |
| **luarocks 加载器** | `pcall(require, "luarocks.loader")` 是 awesomerc 第 1 行 | 直接死 |

#### 3.3 还能活的（纯 C 路径，无 lgi）

| 功能 | 依据 |
|------|------|
| 键盘/鼠标抓取（keygrabber/mousegrabber） | 纯 C，无 lgi |
| EWMH、窗口管理核心、tag/client/stack | C 内核 |
| `ruled` 规则引擎 | `grep -c "lgi\|gears.object" lib/ruled/init.lua` → **0** |
| D-Bus 会话总线 | 纯 C，libdbus 可静态 |
| X11 基础 / xcb 系列 | 纯 C |

`awful.placement`（窗口放置算法）仅 **1** 处引用、`wibox/layout/grid`（布局计算）也仅 **1** 处——**纯布局逻辑本身可救，救不了的是渲染**。

#### 3.4 影响面量化

- `lib/` 下 **51 / 170** 个 Lua 文件直接依赖 lgi 或 `gears.object`（**30%**）
- 加上间接依赖（`gears.color` 35 个消费方），实际影响面远超 30%
- 参照仓库对照：fluxbox 静态化只关 1 个开关（`--enable-xinerama=no`），openbox 关 7 个就成；**awesome 要关的开关数量是"整套 widget 层"，不是一个 flag 的问题**

### 4、结论：三条路径对比

| 路径 | 代价 | 保留 awesome 能力 | 结论 |
|------|------|------------------|------|
| **① 照搬方法论做 dwm/fluxbox/openbox 静态版** | 低（有现成脚本） | 不适用（换 WM） | **推荐** |
| **② awesome 半静态**（静态 liblua + 动态 lgi/GI） | 中 | 全保留 | 对容器**收益 ≈ 0**（b10 七.2.1） |
| **③ awesome 全静态** | 需放弃 GI、手写全套 C 绑定（≈ 重写半个 awesome） | 只剩纯 C 部分 | **不可行** |

参照仓库方法论本身成熟、可抄，**但它的适用边界恰好卡在 dlopen 链**——它做的 20 多个项目全部没有 GI 反射，所以它从来没碰到过这个问题。这也解释了第 0 节为什么整库 grep 不到 awesome：不是漏了，是做不到。

### 5、对本项目的影响

- **如果目标其实是"容器里跑静态 WM"，路径 ① 回报远高于 ②③**：dwm 静态化参照仓库里有现成脚本，核心就是

```sh
flags="-static -lXft -lX11 -lxcb -lXau -lfontconfig -lfreetype -lXrender -lXdmcp \
       -lpng -lexpat -lxml2 -lz -lbz2 -lbrotlidec -lbrotlicommon"
make LDFLAGS="$flags -lXinerama -lX11 -lXxf86vm -lXcursor -lm -ldl -lrt -lXext -luuid"
```

  配合 `config.mk` 里 `sed` 改 `PREFIX`，直接出单文件。
- **落地顺序建议**：先用路径 ① 在本项目做 dwm（`compile/src/suckless/build.sh` 可直接照抄，`config.mk` + `LDFLAGS` 两处改动），验证"静态 WM 走 xvnc2.sh / entry-x11base.sh 的 perp 服务模式"这条集成链；dwm 通了再考虑 fluxbox/openbox（openbox 需先自编 pango + fontconfig + libXrandr 三个依赖）。
- **awesome 侧结论不变**：b10 的"全静态不可行"判断被参照仓库的完整落地清单反证强化（见第 0 节 grep 空结果）——同一套成熟方法论，20 多个项目成了，awesome 一个都没做。容器路线仍是 `apk add awesome`，选型优先级 i3 > bspwm > Awesome 不变。

## 三、lgi 及其替代方案的静态编译适配度

> 章节二的硬边界是"lgi→GI→dlopen 链"。但**换掉 lgi** 能不能绕过去？这一节系统评估。
> 结论先行：**理论上 lgob（静态代码生成）是唯一原生支持静态的方案，但项目已不活跃；换成 LuaGObject 是维护性升级路径但对静态化收益为 0（仍是动态 GI）；LGI 自称支持静态链接但工程上仍需运行时 GI。综合来看，即便替换绑定层，awesome 全静态仍不可行——工程代价 ≈ 重写半个 awesome，且没有任何一个社区 fork 走这条路。**

### 1、lgi 是什么：技术角色

lgi 是 AwesomeWM 的**核心 Lua 绑定层**，基于 gobject-introspection（GI）自动生成 Lua 对 C 库的调用接口。它把 C 库几乎所有功能自动暴露给 Lua，无需手写胶水代码。

**面向对象风格转换**：C 的函数式 API 被映射为 Lua 命名空间 + 对象方法。例：C 的 `cairo_line_to(cr, x, y)` 在 lgi 中写作 `cr:line_to(x, y)`。

**主要优势**：

- 开发效率高：不用为每个 C 函数手写绑定
- 功能覆盖广：自动暴露 GI 已覆盖的 C 库几乎所有功能
- OOP 风格：更符合 Lua 生态习惯

**代价**：

- 文档不集中：lgi 的 Lua 侧文档零散，通常需查 C 库原文档
- 稳定性风险：直接调底层 API，参数/返回值处理不当会崩溃

### 2、lgi 项目现状

| 项 | 值 |
|---|---|
| 官方仓库 | https://github.com/lgi-devs/lgi （原 pavouk/lgi 已重定向） |
| 起始年份 | 2010（Pavel Holejšovský 发起） |
| 核心贡献者 | Uli Schlachter、Jasper Lievisse Adriaanse 等 43+ 开发者 |
| 许可证 | MIT |
| Lua 版本支持 | 5.1 / 5.2 / 5.3 / LuaJIT2 完整支持；5.4 仅**实验性** |
| 版本历史（LuaRocks） | 0.2（2011）→ 0.7.2 → **0.9.2（2017-10-09，最后正式版）** |
| 近 5 年 release 数 | **0**（最后一次正式 release 已 9 年） |
| 近 1 年活跃开发者 | 约 4 名 |
| 2026-09-20 Star 数 | **492**（实测） |

**判定**：LGI 主仓库**已基本停止维护**，仅零星合并 bugfix。这本身就是一个风险信号——awesome 的核心依赖无人接盘。

### 3、替代方案对比矩阵

| 项目 | GitHub 仓库（2026-09-20 实测） | ⭐ / Fork | 绑定方式 | 维护状态 | 静态编译支持 | 关键备注 |
|------|------------------------------|-----------|---------|---------|-------------|---------|
| **LGI** | [lgi-devs/lgi](https://github.com/lgi-devs/lgi) | **492** / 81 | 动态 GI | ⚠️ 9 年无 release（2017-10 后） | 官方开发包 `lua-lgi-dev` 声明支持静态链接二进制 | awesome 官方绑定；最后 push 2026-08-17 |
| **LuaGObject** | [vtrlx/LuaGObject](https://github.com/vtrlx/LuaGObject) | 32 / 4 | 动态 GI（GIRepository 2.0） | ✅ **最近 push 2026-08-25** | 需手动嵌入：Lua 字节码 + C 侧 `luaL_loadbuffer` | **LGI 直接 fork**（2024-12 创建）；GTK4/libadwaita/Lua 5.4/5.5；GNOME 49+ 刚需 |
| **lgob** | [nomadalex/lgob](https://github.com/nomadalex/lgob) | 5 / 1 | **静态代码生成**（.gir → C 胶水） | ❌ **archived**，最后 push 2011-06-26（**15 年停更**） | **原生设计**——设计上就是静态绑定 | 唯一原生支持静态的方案，但项目已归档不可用；LGPL-3.0 |
| **wxLua** | [pkulchenko/wxlua](https://github.com/pkulchenko/wxlua) | **357** / 60 | 非 GTK（C++ 手写 wxWidgets 绑定） | ✅ **最近 push 2026-09-19（活跃）** | 理论可自编静态版 | 生态中最活跃者；通过 wxWidgets 跑，非直接 GTK 绑定 |
| **LUI3** | [d-power/LGUI3](https://github.com/d-power/LGUI3) | 3 / 1 | 未声明 | ⚠️ 最后 push 2025-12-02 | 未声明 | 个人项目，非官方替代品 |
| **lgui** | [passpeon/lgui](https://github.com/passpeon/lgui) | 0 / 0 | 未声明 | ❌ 最后 push 2018-06-04（8 年） | 未声明 | 轻量 GTK2 绑定；仓库近空 |
| **keybinder** | [aur-archive/lua-keybinder](https://github.com/aur-archive/lua-keybinder) | 0 / 0 | 静态实验 | ❌ 最后 push 2015-08-16（11 年） | 需手动指定 Lua 头文件路径 | 特殊用途（按键绑定）；AUR 归档镜像 |
| **LuiGI** | — | — | — | ❌ **GitHub 上找不到对应仓库** | — | 仅存于早期源码托管（SourceForge 等）；作者已建议改用 LGI |
| **Lua-Gnome / Lua-GTK** | — | — | — | ❌ **GitHub 上找不到对应仓库** | — | 仅存于历史归档；面向 GTK+ 2.x |

**读表结论**：

- **实际最活跃的 Lua-GUI 绑定是 wxLua（357★，2026-09 仍在推）**，但它走 wxWidgets，不是 lgi 的替代路径
- **LGI 主仓库 492★、LuaGObject 精神续作 32★**——两个动态 GI 方案星数差 15 倍，说明 LGI 的"用户资产"实际还在，LuaGObject 只是小圈子
- **lgob 是唯一原生静态方案，但 2011 年后归档 15 年**（`archived: true`），作为依赖引入风险极高
- **LuiGI 和 Lua-Gnome 在 GitHub 上找不到对应仓库**——只能算历史遗产
- **动态 vs 静态的轴**：LGI / LuaGObject 走动态；lgob 走静态（已死）；wxLua 走手写 C++（最活跃但不在同一生态）
- **维护性 × 静态化的交叉点在 2026 年已不存在**：唯一原生静态的 lgob 已归档 15 年

### 4、GTK2 目标环境的静态绑定方案（补充）

如果你的目标环境是 **GTK+ 2.x**（很多老项目/嵌入式环境的默认选择），静态绑定可选面稍宽：

| 项目 | 适配度 | 备注 |
|------|--------|------|
| lgob | 🥇 首选 | 支持 GTK+ 2.6+，静态设计最原生 |
| LuaGnome | 🥈 | 针对老 GTK2；库文件仅约 350 kB；`glib 2.x / gdk / gtk 2.x` 覆盖完整 |
| lgui | 🥉 | 轻量级 GTK2 绑定，构建简单但未声明静态 |
| keybinder | 特殊 | 含实验性静态 Lua 绑定，需手动指定 Lua 头文件 |
| wxLua | 间接 | 通过 wxWidgets 跑在 GTK2 之上 |

### 5、对 awesome 静态化结论的影响

即便存在"能静态编译的 lgi 替代品"（lgob），awesome 全静态**依然不可行**，工程理由如下：

1. **awesome 代码对 lgi 的深度耦合**：`lib/` 下 51/170 文件直接 `require("lgi")`（30%），`lib/gears/init.lua` 一次性加载 16 个子模块全部依赖 lgi，`common/version.c:51` 甚至在**版本查询**路径上都要 lgi。**替换绑定层等于改 awesome 源码 50+ 处**。
2. **lgob 本身已不活跃**：项目本身没有长期维护承诺，作为依赖引入是给自己挖坑；awesome 上游也不会官方采用。
3. **LGob 只是绕开了 GI 运行时，但没绕开实际的图形库链接**：C 胶水代码生成后仍要 `-lX11 -lCairo -lPango` 等；这些库要静态化，回到章节二的 `--start-group` 难题——而 Pango / Fontconfig / Harfbuzz / Freetype 静态链接是 openbox 参照仓库里已经踩过坑的一步（需自编 pango + fontconfig + libXrandr），工程复杂度不低。
4. **LuaGObject 是维护升级路径但对静态化无益**：它是"动态 GI + 新仓库 2.0"，解决的是"新 GNOME 兼容"，不解决"静态链接"。awesome 换到 LuaGObject 之后，仍然需要 dlopen 每个 C 库，跟当前 lgi 状态相同。
5. **没有任何 awesome fork 走这条替换路径**：b15 章节一排查了 626 个 fork，7 个有实质开发的 fork 分别是 Lua→Luau、Skia 后端、Lua 5.5、CI 等方向，**没有一个在尝试替换 lgi**。这本身就是行业共识——没人觉得这条路值得走。

### 6、路径判断（更新版）

原章节二的三条路径不变，此处补上**第四条路径**（换绑定层路线）并给出统一判断：

| 路径 | 代价 | 静态化收益 | 结论 |
|------|------|----------|------|
| ① 照搬参照仓库做 dwm/openbox 静态版 | 低 | 高 | **推荐** |
| ② awesome 半静态（静态 liblua + 动态 lgi/GI） | 中 | 对容器 ≈ 0 | 无意义 |
| ③ awesome 全静态（保留 lgi） | 极高 | 不可行 | **不可行** |
| ④ awesome 换 lgob / LuaGObject 静态版 | 极高（≥ 重写） | 即使可行也需自编 pango 栈 | **工程上不可行** |

**最终判断**：awesome 的四条静态化路径全部不划算。容器路线仍是 `apk add awesome`（动态 + lgi + GI）；如果目标是"容器里跑静态 WM"，直接走路径 ① 换 dwm/openbox，不要试图改造 awesome。

## 四、全量选型清单与施工复杂度估算

> 直接回答**"以上信息能否为静态编译提供可行性"**：
> - **对 awesome：不能**。7 条路线中仅 R7（换 WM）和 R1（保留 lgi 动态）有工程价值，其余 5 条均不划算。
> - **对其他 WM：能**。dwm/openbox/bspwm 均不依赖 GI，参照仓库已有 20+ 项目落地。

### 1、可行性校对结论

**awesome 全静态不可行**——不是因为技术原理做不到（lgob 存在），而是**没有任何静态化 awesome 的绑定方案具备生产级维护承诺**：

| 障碍层 | 具体表现 |
|--------|---------|
| 依赖层 | 唯一原生静态的 lgob 已不活跃；活跃的 LuaGObject 仍是动态 GI |
| 集成层 | 51/170 lib 文件 `require("lgi")`，替换 = 大改上游源码 |
| 生态层 | 626 个 awesome fork 中无人尝试替换 lgi，行业共识信号 |
| 维护层 | awesome 上游不会接受任何替换分支，做成即成孤儿 fork |

### 2、全量 7 条选型路线（矩阵）

| # | 选型路线 | 目标 | 静态化收益 | 施工复杂度 | 综合判断 |
|---|---------|------|-----------|-----------|---------|
| R1 | 保留 lgi + `apk add awesome` | 现状 | 0（100% 动态） | 0 | 容器路线唯一合理选项 |
| R2 | 换 LuaGObject（上游化） | 换绑定层但保持动态 | 0（仍 GI 反射） | 中 | 上游升级路径，非容器改造 |
| R3 | 换 lgob（静态代码生成） | 静态化 lgi | 理论可能 | 极高 | 单人可做但长期维护无解 |
| R4 | 换 LuaGnome（GTK2 静态） | 静态化但降 GTK2 | 理论可行 | 极高 | awesome GTK3 功能全废 |
| R5 | 保留 lgi + 手工嵌入 GI 仓库 | 半静态 GI 部分 | 半 | 中 | 容器收益 ≈ 0 |
| R6 | 抛弃 GI，纯 C 绑定 + Lua | 完全重写 | 全静态 | 极高 | 等价于写一个新 WM |
| R7 | 直接换 dwm/openbox + 静态编译 | 换 WM | 全静态 | 低 | **推荐** |

### 3、各路线施工复杂度详解

#### R1 — 保留 lgi + `apk add awesome`

- **主体工作**：无（现状）
- **验证**：`apk add awesome` 一条命令
- **风险**：lgi 停维 9 年，若出现严重 CVE 无上游修复
- **工时**：**0 人天**
- **判定**：**✅ 容器默认选项**

#### R2 — 换 LuaGObject（维护升级路径）

- **主体工作**：
  1. 构建期添加 `libgirepository2.0-dev`（新版 GIRepository）
  2. `require("lgi")` 调用点全部保留（LuaGObject API 兼容）
  3. awesome 上游构建脚本改造
- **验证**：awesome 单元测试 + 集成回归
- **风险**：上游不接受，需长期自己维护分支（每年 rebase）
- **工时**：**20-30 人天**（一次性）+ **10-15 人天/年**（rebase 维护）
- **判定**：⚠️ **上游生态升级，非容器静态化路径**

#### R3 — 换 lgob（静态代码生成）

- **主体工作**：
  1. **构建期跑 lgob**：对 awesome 依赖的 8 个 GI repo 生成 C 胶水代码
     - Gtk、Gdk、GdkX11、Cairo、Pango、GdkPixbuf、X11、GObject
  2. **API 重写**：lgob 命名空间与 lgi 不同，需改 ~50 处 `require("lgi").Gtk.Xxx`
  3. **依赖静态化**：libglib/libgobject/libgtk/libcairo/libpango/libX11 等静态链接
     - pango/harfbuzz/fontconfig/freetype 栈参照仓库已有先例但需自配
  4. **产物**：静态 `awesome` 二进制（含内嵌 lua）
- **验证**：
  - 单元：awesome 的 tests/ 目录（49,227 行测试代码）
  - 集成：真实桌面环境跑 30 天
- **风险**：
  - lgob 无官方维护，出现 bug 需自己修
  - awesome 每年度升级都需重跑 lgob 全流程
  - 上游永远不接受，等于成为孤儿 fork
- **工时分解**：

  | 阶段 | 工时 |
  |------|------|
  | 构建流程改造 | 4-6 周 |
  | API 重写（50+ 处 + 边缘 case） | 4-8 周 |
  | 依赖静态化（pango 栈等） | 2-4 周 |
  | 联调 + 修复 bug | 4-8 周 |
  | 回归测试 | 2-4 周 |
  | **合计** | **20-34 人周（5-9 人月）** |

- **判定**：⚠️ **单人可做但长期维护无解**

#### R4 — 换 LuaGnome（GTK2 静态）

- **前置**：awesome 已多年不用 GTK2，其 wibox / gears 深度依赖 GTK3 API
- **主体**：把 GTK3 代码全部回退到 GTK2
- **工时**：**6-12 人月**（重写 UI 层）
- **判定**：❌ **无法实现**

#### R5 — 保留 lgi + 手工嵌入 GI 仓库（半静态）

- **主体**：liblua + GIRepository 静态链接，但 GI 的 `.so` 依赖仍需 dlopen
- **风险**：容器收益 ≈ 0（b10 已论证）
- **工时**：**4-6 周（20-30 人天）**
- **判定**：❌ **无实际收益**

#### R6 — 抛弃 GI，纯 C 绑定 + Lua（完全重写）

- **主体**：写一个新的 C→Lua 绑定框架替换整个 lgi 层
- **工时**：**6-12 人月**（等价于重写半个 awesome）
- **判定**：❌ **不可行**

#### R7 — 换 dwm/openbox + 静态编译（推荐）

- **前置**：无（参照仓库已有完整脚本）
- **主体**：
  - dwm：`compile/src/suckless/build.sh` 直接照抄，改 `config.mk` + `LDFLAGS` 两处
  - openbox：需先自编 pango + fontconfig + libXrandr（参照仓库已有）
- **验证**：本项目 entry-x11base.sh + xvnc2.sh 的 perp 集成链
- **风险**：用户习惯变化（从 Lua 配置到 C 配置或 openbox.xml）
- **工时分解**：

  | 阶段 | 工时 |
  |------|------|
  | dwm 静态化 + perp 集成 | 2-3 天 |
  | openbox 静态化 + perp 集成 | 3-5 天 |
  | 用户迁移文档 | 1-2 天 |
  | **合计** | **1-2 人周（5-15 人天）** |

- **判定**：✅ **推荐**

### 4、复杂度对比（按人天排序）

```
R1  保留 lgi          :   0     ⭐ 现状，容器默认
R7  换 dwm 静态       :  5-15   ⭐ 推荐
R5  半静态 GI         : 20-30   无实际收益
R2  换 LuaGObject     : 20-30   上游升级路径，非静态化
R3  换 lgob           :100-170  单人可做但维护无解
R6  完全重写          :120-240  不可行
R4  换 LuaGnome       :120-240  不可行（GTK3→GTK2）
```

### 5、结论闭环

b15 四个章节的结论至此形成闭环：

| 章节 | 结论 |
|------|------|
| 章节一 | awesome fork 生态无独立社区（626 fork 中 7 有实质开发，最高 9 星） |
| 章节二 | awesome 全静态不可行（GI→dlopen 链是硬边界；参照仓库 20+ 项目无一涉及 lgi） |
| 章节三 | lgi 替代方案全部不可行（lgob 不活跃 / LuaGObject 仍动态 / 626 fork 无替代尝试） |
| 章节四 | 7 条路线中仅 R7（换 dwm）和 R1（保留动态）有工程价值 |

**最终建议**：
- **容器默认**：`apk add awesome`（R1，0 成本）
- **静态 WM 首选**：dwm（R7，5-15 人天）
- **不建议投入**：R2 / R3 / R4 / R5 / R6（累计 200-500 人天，收益为 0 或极低）

awesome 选型优先级不变：**i3（推荐）> bspwm > Awesome**。


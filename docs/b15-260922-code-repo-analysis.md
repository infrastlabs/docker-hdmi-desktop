# b15-260922 | 代码仓库分析

> 主题：awesomeWM 生态的代码仓库分析。本文档按节展开，目前收录 **fork / 改名项目** 与 **上游仓库本体结构** 两节，组织仓库与方法学沉淀待后续补充。
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

# b15-260922 | awesomeWM fork / 改名项目代码仓库分析

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

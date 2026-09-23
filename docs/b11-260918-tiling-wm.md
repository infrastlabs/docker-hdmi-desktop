# b11-260918 | Xorg 平铺窗口管理器选型对比（知识整理）

> 背景：整理 i3 / bspwm / AwesomeWM / dwm / xmonad / herbstluftwm / spectrwm / qtile 的横向对比资料（GitHub 数据、定位差异、与 tint2 / tmux 的组合关系、鼠标支持、发展历史、从 Openbox/Fluxbox 迁移体验），供容器桌面项目选型参考。
> 说明：星标数 / 活跃度为 2026-09-18 附近的快照，随社区变动仅供参考，选型应以"定位匹配 + 亲手体验"为准。

## 一、主流 Xorg 平铺 WM 总览

| WM | 语言 | GitHub 星标 | 活跃度 | 核心特色 |
|----|------|------------|--------|----------|
| [i3/i3](https://github.com/i3/i3) | C | ~9.9k（最受欢迎） | 活跃（约3个月前有提交） | 文档最完善、配置简单、对新手最友好；成熟的 IPC 接口，生态工具丰富 |
| [baskerville/bspwm](https://github.com/baskerville/bspwm) | C | ~8.3k | 维护中（约2-3个月前） | 二叉空间分割（BSP）极简主义；自身只做窗口管理，配 [baskerville/sxhkd](https://github.com/baskerville/sxhkd) 处理快捷键，Unix 哲学纯粹 |
| [awesomeWM/awesome](https://github.com/awesomeWM/awesome) | Lua（核心 C） | ~6.4k | 活跃（约9天前有推送） | 高度可配置的"框架"，Lua 脚本配置；内置部件库（wibox），可做复杂状态栏与桌面效果 |
| [dwm](https://dwm.suckless.org/) | C | 官方仓库不提供（社区常引用 ~4.5k+ 量级） | 极低频更新（suckless 哲学） | 极简终极代表，代码仅约 2000 行；配置需改源码重新编译，靠打补丁扩展 |
| [xmonad/xmonad](https://github.com/xmonad/xmonad) | Haskell | ~3.4k | 活跃（约15天前） | Haskell 编写与配置、类型安全；[xmonad/xmonad-contrib](https://github.com/xmonad/xmonad-contrib) 扩展库强大 |
| [herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm) | C++ | ~1.2k | 活跃（2026年4月） | 手动平铺，运行时用 herbstclient 完全控制；可把屏幕划成多个虚拟区域各自独立平铺 |
| [conformal/spectrwm](https://github.com/conformal/spectrwm) | C | ~1.3k | 较低（约3个月前） | "黑客为黑客写"的小巧工具，开箱即用，无需学编程语言即可配置 |
| [qtile/qtile](https://github.com/qtile/qtile) | Python | ~5.2k | 活跃（约6个月前） | Python 编写与配置，对 Python 开发者友好；功能全面，易写脚本实现复杂逻辑 |

> **[dwm](https://dwm.suckless.org/) 星标说明**：dwm 官方仓库直接托管在 suckless.org，GitHub 上无官方镜像计数；社区常引用 ~4.5k+ 量级。有个别非官方文章声称 18.3 万星，**该数据极度不准确**，请以社区共识为准。

## 二、定位与选型建议

- **求省心与生态** → [i3/i3](https://github.com/i3/i3)：文档和社区资源最丰富，遇到问题最容易找到答案，适合入门第一站。
- **求极简与 Unix 哲学** → [baskerville/bspwm](https://github.com/baskerville/bspwm)：只做窗口管理，[baskerville/sxhkd](https://github.com/baskerville/sxhkd) 解耦快捷键，结构清晰，脚本控制强。
- **求深度定制与动态效果** → [awesomeWM/awesome](https://github.com/awesomeWM/awesome)：Lua 配置灵活性大，部件系统能打造独特桌面。
- **求极致精简与掌控** → dwm：适合愿读改 C 代码、享受"系统完全由我构建"的用户。
- **熟悉 Haskell / 函数式** → [xmonad/xmonad](https://github.com/xmonad/xmonad)：配置本身就是 Haskell 程序，扩展性强。
- **熟悉 Python，配置即代码** → [qtile/qtile](https://github.com/qtile/qtile)：上手门槛低，能快速实现自动化。

### 1、按编程背景判断上手成本

- 偏 **C**：i3（纯文本配置最接近传统 WM）→ bspwm（sxhkd/bspc 命令式）→ dwm（需改 C 源码重编译）。
- 偏 **Lua**：Awesome 是唯一选择，配置即程序，门槛最高但上限最高。
- 偏 **Python**：qtile 完全用 Python 写配置和扩展逻辑，几乎零额外学习成本。

## 三、i3 / bspwm / Awesome "三强"核心数据对比

| WM | 语言 | Star | 活跃度 | 仓库 |
|----|------|------|--------|------|
| [i3/i3](https://github.com/i3/i3) | C | ~9.9k | 近期有更新（约3个月前） | github.com/i3/i3 |
| [baskerville/bspwm](https://github.com/baskerville/bspwm) | C | ~8.3k | 维护中（约4个月前） | github.com/baskerville/bspwm |
| [awesomeWM/awesome](https://github.com/awesomeWM/awesome) | Lua（核心 C） | ~6.4k | 活跃（约9天前） | github.com/awesomeWM/awesome |

### 1、各自定位

- **i3：生态最成熟的"标准答案"**——树状容器结构管理窗口，全键盘操作，IPC 接口成熟，能与大量状态栏/启动器等第三方工具集成。
- **bspwm：极简主义的"Unix 哲学"实践者**——窗口组织为二叉树叶节点；自身不处理任何键盘/鼠标输入，靠 sxhkd 等热键守护进程发 socket 消息控制，结构极清晰。
- **Awesome：高度可配置的"框架"**——用 Lua 自定义一切；用 tags（标签）代替传统工作区，窗口可同时显示在多个标签上；内置 wibox 部件系统。

### 2、选型建议

- 想省心、文档多 → **i3**（入门 Xorg 平铺最佳起点）。
- 求极简、喜欢脚本控制 → **bspwm**（只做窗口管理，控制感最强）。
- 熟悉/愿学 Lua、需深度定制 → **Awesome**（功能最丰富的桌面）。

## 四、美观度与定制案例

### 1、谁的"天花板"高、谁的下限稳

- **[awesomeWM/awesome](https://github.com/awesomeWM/awesome)（上限最高）**：框架级 WM，Lua 控制一切，能实现复杂动画与自定义 UI（示例：手写字体状态栏、13 种手工布局 + 3D 渐变按钮）。
- **i3（下限稳定）**：社区海量现成主题（Catppuccin、Dracula 等），配 picom 合成器即可获得现代美观效果。
- **bspwm（高度依赖外部工具）**：自身不带状态栏，视觉完全取决于搭配的 polybar、eww 等；有项目提供 18 种主题一键切换、透明度实时调节。

### 2、GitHub 定制案例数量（话题页公开仓库数，仅作量级参考）

| WM | 话题页仓库数 | 说明 |
|----|------------|------|
| [i3/i3](https://github.com/i3/i3) | 185+ | 数量绝对领先，社区最庞大 |
| [baskerville/bspwm](https://github.com/baskerville/bspwm) | 51 | 数量居中但精品率高（如 gh0stzk/dotfiles，18 主题） |
| [awesomeWM/awesome](https://github.com/awesomeWM/awesome) | 34 | 数量最少（Lua 门槛高），定制方案往往更有独特性与技术含量 |

### 3、截图资源与视觉特点

- **i3**：默认线性分割、窗口像切蛋糕一样整齐、无间隙（i3-gaps 已并入 v4.21+ 原生支持间隙），风格硬朗高效；浮动需 `$mod+Shift+Space` 切换。参考：i3 官方截图页、[0x7n6/i3wm-Config](https://github.com/0x7n6/i3wm-Config)。
- **bspwm**：二叉树递归分割、默认带窗口间隙更透气；`Super + S` 切换浮动（默认无边框或细边框）。参考：[LambBread/my-dotfiles](https://github.com/LambBread/my-dotfiles)。
- **AwesomeWM**：主次区域布局（1 主 N 副），间隙/边框可定制，配 bling 模块可实现华丽动画；`Super + s` 切换浮动。参考：[mdmrk/policromia](https://github.com/mdmrk/policromia)、[Sanatana-Linux/nixos-awesomewm](https://github.com/sanatana-linux/nixos-awesomewm)。

> 快速找图：GitHub 搜 `dotfiles + [WM名]`，或逛 Reddit r/unixporn。

## 五、与 tint2 的组合

tint2 官方支持绝大多数遵循 EWMH 的 WM，三款都能用；Awesome/bspwm 上偶有兼容性小问题需额外配置。

### 1、i3 + tint2（推荐组合）

- 启动：i3 配置里 `exec --no-startup-id tint2`，建议 `panel_layer = bottom` 避免遮挡窗口。
- 特色：i3 会把窗口自动排列在面板预留空间；tint2 优势在于更丰富的主题 + GUI 配置工具（i3bar 换 tint2 主要是这个动机）。
- 案例：GitHub 上非常丰富，主流选择之一。

### 2、bspwm + tint2（极客之选）

- 启动：bspwmrc 或 autostart 中启动；bspwm 不自动给面板预留空间，需加规则保持底层：`bspc rule -a tint2 layer=below`。
- 特色："WM + 热键守护进程 + 面板"模块化组合，深受 Unix 哲学用户喜爱，常出现在 r/unixporn 的 ricing 作品里；Catppuccin 等配色有对应 tint2 配置。

### 3、AwesomeWM + tint2（不推荐）

- Awesome 自带 wibar 更强大，换 tint2 反而是"降级"，还可能需要处理与内置面板的层级关系。真正要发挥 Awesome 价值应直接用 Lua 定制 wibar；tint2 组合更多是临时方案或特定偏好。

### 4、tint2 主题资源

- [addy-dclxvi/tint2-theme-collections](https://github.com/addy-dclxvi/tint2-theme-collections)：最著名的合集，32 套主题，Github Star 545+。
- [MerkeX/tint2-theme-collections](https://github.com/MerkeX/tint2-theme-collections)：同 32 套主题的备份合集。
- [FanMclaine/Drecked-Tint2-Themes](https://github.com/FanMclaine/Drecked-Tint2-Themes)：Catppuccin 配色为主，风格现代。
- GitHub `tint2-theme` 话题页可发现更多。

## 六、[tmux/tmux](https://github.com/tmux/tmux) pane vs 桌面平铺 WM

把 tmux 的 pane 看作"终端内部的平铺窗口"，i3 / bspwm / Awesome 就是桌面级平铺 WM——效果相似，本质与粒度不同。

| 维度 | tmux pane | i3 | bspwm | AwesomeWM |
|------|-----------|-----|-------|--------|
| 作用域 | 同一个终端窗口内 | 整个 X11 桌面 | 整个 X11 桌面 | 整个 X11 桌面 |
| 管理对象 | 伪终端（每个 pane 一个 shell） | 独立 X11 应用窗口 | 独立 X11 应用窗口 | 独立 X11 应用窗口 |
| 布局模型 | 嵌套水平/垂直分割，字符网格 | 树状容器，支持 tabbed/stacked | 二叉树（BSP），自动/手动分割 | 多种布局算法（tile、magnifier、fair 等），可切换 |
| 调整粒度 | 按字符单元格 | 按像素/比例 | 按比例 | 按比例或鼠标 |
| 快捷键 | Ctrl+b 前缀 | `$mod`（Super），mode 可模拟前缀 | sxhkd 等外部工具定义 | Lua 全局键绑定，可模拟前缀 |
| 工作区/标签 | window + session | workspace | desktop | tag |
| 浮动窗口 | popup（tmux 3.2+），非真正浮动 | 支持 | 支持 | 支持 |
| 多显示器 | 不跨显示器 | 支持 | 支持 | 支持 |
| 会话持久化 | 核心优势（detach/attach） | 无原生持久化 | 无原生持久化 | 无原生持久化 |
| 视觉定制 | 受终端字体/颜色限制 | 依赖 picom 等合成器 | 依赖 picom 等合成器 | 内置 wibox，Lua 可深度定制 |

### 1、与 tmux pane 的相似度

- **i3（最像）**：容器树与 tmux pane 嵌套分割逻辑几乎一致；mode 可完美模拟 Ctrl+b 前缀（`%` 左右分、`"` 上下分、h/j/k/l 切焦点）；tabbed/stacked 类似 window 切换。
- **bspwm（自动化的 tmux pane）**：新窗口自动插入二叉树叶节点，类似 tmux 自动分割但更动态；键位可完全照搬 tmux；`bspc` 调大小比 tmux 更灵活；只差 session 持久化。
- **AwesomeWM（差异最大）**：不是固定树状分割而是多种布局算法可切换；窗口可同时属于多个 tag；用 Lua 可写任何平铺逻辑，但默认是"可编程的桌面框架"，与 tmux 手动分割直观对应最弱。

### 2、关键差异总结

1. 本质：tmux pane 分割的是同一终端内的字符区域；WM 平铺的是多个独立图形应用窗口。
2. 粒度：tmux 按字符，WM 按像素/比例，后者更自由。
3. 持久化：tmux 可 detach/attach；桌面 WM 无原生会话保持，但可用布局保存工具弥补。
4. 多显示器：tmux 不跨显示器，WM 天然支持。
5. 视觉：终端受限，WM 可配 picom 实现阴影、透明度、动画，上限高得多。

> tint2 只是面板，不影响平铺逻辑；无论选哪个 WM，它都只负责显示状态栏。

## 七、AwesomeWM 原生不支持"手动二叉树平铺"

AwesomeWM 默认是**动态布局**而非手动树状管理——tile、fair、spiral 等预定义算法（spiral/dwindle 会形成嵌套分割的视觉，但**无法**像 i3 那样对某个窗口手动执行"垂直/水平分割"指令）。社区有用户专门提 issue 请求"Binary tree / BSP-style / tmux-style manual window tiling"，说明原生不具此能力。

### 1、第三方模块

#### 1.1 awesome-leaved

（[michaelbeaumont/awesome-leaved](https://github.com/michaelbeaumont/awesome-leaved)）最接近 i3 的容器化布局——基于 i3 容器概念，客户端可在容器内垂直/水平排列，支持 stacked/tabbed；提供 `splitH` / `splitV` 键绑定函数。

#### 1.2 treesome

（[RobSis/treesome](https://github.com/RobSis/treesome)）tmux 风格二叉树布局——把 tmux 递归分割机制移植到 AwesomeWM，每个窗口是二叉树节点，可无限嵌套；默认按焦点窗口宽高比自动定拆分方向，也可键绑定强制指定。

| 方案 | 手动水平/垂直切 | 嵌套切 | 类似 tmux/i3 |
|------|:---:|:---:|------|
| [awesomeWM/awesome](https://github.com/awesomeWM/awesome) 默认 | ❌ | ❌ | ❌ |
| [michaelbeaumont/awesome-leaved](https://github.com/michaelbeaumont/awesome-leaved) | ✅ | ✅ | 类似 [i3/i3](https://github.com/i3/i3) |
| [RobSis/treesome](https://github.com/RobSis/treesome) | ✅ | ✅ | 类似 [tmux/tmux](https://github.com/tmux/tmux) |

> 结论：要开箱即用的 tmux pane 式手动平铺，i3 或 bspwm 更直接；Awesome 需额外引入第三方模块，且这些模块的维护活跃度需自行评估。

## 八、鼠标支持对比

总体：**AwesomeWM 最完善，bspwm 最需配置，i3 介于两者之间**。

### 1、窗口移动与调整大小

- **i3**：`$mod` + 鼠标拖拽移动/调整浮动窗口；4.21+ 还支持鼠标直接拖拽平铺窗口。
- **bspwm**：需 `bspc config pointer_modifier` 设置修饰键（如 mod1/Alt），`pointer_action1/2` 绑定左右键移动/调大小；**不支持无修饰键的纯鼠标操作**。
- **AwesomeWM**：默认 Mod4+左键移动、Mod4+右键调大小；支持拖到屏幕边缘自动吸附/平铺、拖到边缘自动切换标签页等高级操作。

### 2、焦点模式（Focus Follows Mouse）

- **i3**：`focus_follows_mouse yes`；另有 `mouse_warping` 控制切工作区时鼠标是否跳屏幕中央。
- **bspwm**：`bspc config focus_follows_pointer true`；另有 `pointer_follows_focus` / `pointer_follows_monitor` 细粒度控制。
- **AwesomeWM**：连接 `mouse::enter` 信号实现 sloppy focus，在信号处理函数中决定是否激活窗口。

### 3、工作区/标签切换与滚轮

- **i3**：点击 i3bar 工作区图标切换；滚轮在 i3bar 上滚动切换工作区。`bindsym button4/5` 可绑滚轮（注意 i3bar 上的滚动可能被内置行为覆盖）。
- **bspwm**：全靠 sxhkd，例如 `super + mouse_down/up` 切换工作区；滚轮自由度高，可绑音量、亮度等。
- **AwesomeWM**：点 taglist 标签切换；默认启用在 taglist 上滚轮循环切标签；`awful.button` 绑定可精细到根窗口、客户端或具体部件。

### 4、对平铺/浮动窗口的影响

- **i3**：鼠标主要作用于浮动窗口；平铺窗口布局固定，但 4.21+ 可拖拽平铺窗口改位置。
- **bspwm**：同为浮动窗口为主；平铺布局调整靠 `bspc` 命令或键盘。
- **AwesomeWM**：默认针对浮动窗口，但 tile 布局下 `awful.mouse.client.move` 等也能影响平铺位置。

## 九、三款 WM 的发展历史与关键节点

### 1、i3：为"更好的平铺"而生

2009 年由德国开发者 Michael Stapelberg 创建，目标是解决 wmii 的局限（名字即 improved tiling wm）；C 语言约一万行，设计哲学"把一件事做好"，去装饰重效率。

#### 1.1 关键节点

- **2009 v3.x**：奠定树状容器模型。
- **2011 v4.0**：重写配置解析器，引入 `for_window` 规则和命令链 `;`，调大小扩展到所有窗口（重要架构升级）。
- **2021 v4.20**：配置支持 `include` 指令、标题栏显示窗口图标。
- **2023-24 v4.21/4.22**：合并 i3-gaps 分支（原生窗口间隙）、支持鼠标拖拽平铺窗口。

#### 1.2 核心亮点

- 树状容器（水平/垂直/嵌套分割）、成熟 IPC、官方文档质量极高。

### 2、bspwm：极致的 Unix 哲学践行者

Bastien Dejean 创建；自身不处理键盘/鼠标输入，热键完全委托 sxhkd，用 `bspc` 命令控制；窗口是 BSP 二叉树叶节点。

#### 2.1 关键节点

- **2017 v0.9.3**：新增节点描述符/修饰符。
- **2020 v0.9.10**：引入 `first_ancestor` 节点描述符、horizontal/vertical 节点修饰符，查询命令更强。
- **2026 v0.9.12**：最新版本，保持活跃维护。

#### 2.2 核心亮点

- 极致模块化（WM 只做窗口管理），结构清晰，控制感最强。

### 3、AwesomeWM：用 Lua 构建的窗口管理"框架"

2007-09-18 首次发布；严格说是窗口管理框架，用户用 Lua 自定义一切。

#### 3.1 关键节点

- **2008 v3.0**：第一个用 XCB 替代 Xlib 的窗口管理器（技术领先性的决定性一步）。
- **2016 v4.0**：API 从 3.5 跃升 4.0 的重大重构，更现代的配置语法。
- **2019 v4.3**：更灵活的 widget 创建机制、全新 keygrabber API、GTK 调色板主题。

#### 3.2 核心亮点

- tags 代替工作区（窗口可同时挂多个 tag）、内置 wibox 部件系统。

## 十、从 Openbox/Fluxbox 迁移的体验差异

核心变化：从"手动管理窗口位置"变成"定义窗口排列规则"。

### 1、习惯项（熟悉甚至更好）

- **键盘驱动工作流**：Openbox/Fluxbox 重度用户本就会配大量快捷键，平铺 WM 把它推向极致，几乎全键盘操作。
- **轻量与可定制**：三者都是独立 WM、不绑完整桌面环境、资源占用低、配置文件深定制，与 Openbox/Fluxbox 一脉相承。
- **"桌面"概念延续**：i3 workspace / bspwm desktop / Awesome tag 都对应多桌面/工作区，切换逻辑相似。

### 2、不习惯项（重点适应）

- **窗口不再自由漂浮**：新窗口自动填充屏幕、不重叠、不能随意拖拽，一切由布局规则决定（这是最根本的差异）。
- **配置文件从"配置"变成"程序"**：
  - i3：纯文本配置，最接近传统 WM，最容易上手，但表达力有限；
  - bspwm：自身无配置文件，需学 sxhkd + bspc 命令，学习曲线陡、配置分散；
  - AwesomeWM：Lua 脚本即程序，功能最强但门槛最高。
- **鼠标作用大幅削弱**：主要剩切焦点和操作浮动窗口；i3 新版虽支持拖拽平铺窗口，整体仍以键盘为主。
- **浮动成为例外**：需为对话框、GIMP 工具箱等写规则让其浮动；在 Openbox/Fluxbox 里浮动才是默认状态。
- **面板/状态栏要重新配**：i3 自带 i3bar；bspwm 通常配 polybar/tint2；Awesome 推荐原生 wibar。

### 3、迁移建议

- 平滑过渡 → **i3**（文本配置最接近传统 WM）。
- 极致控制/Unix 哲学 → **bspwm**（解耦设计 + sxhkd 像拼 Shell 命令）。
- 会/愿学 Lua → **AwesomeWM**（视觉与自动化上限最高，但需投入时间"编写"桌面）。
- 一开始建议：保留一个浮动窗口快捷键 + 把常用应用窗口规则配好（浏览器平铺、对话框浮动），可极大缓解迁移初期不适。

## 十一、对本项目的落地（待办）

- 本项目容器默认 `START_SESSION=startfluxbox`（.arg.sample 可选 `openbox-session`），目前是堆叠式 WM 路线。
- Awesome 在 Alpine/musl 下的静态化不可行、`apk add awesome` 即可用（详见 b10）；若要在容器内跑 Awesome，需在 Dockerfile 加依赖并按 xvnc2.sh / entry-x11base.sh 的 perp 服务模式注册。
- 若要在容器里引入平铺 WM：**i3** 体积小、纯文本配置、文档全，与容器"开箱即用"最契合；bspwm 次之；Awesome 依赖链最重（Lua + LGI + GTK 生态）；dwm/herbstluftwm 可作为 Alpine 精简路线的备选。
- 待实施；如需要可参照 b6/b7/b10 的方式新增分支或 `.arg` 开关（如 `TILING_WM=i3`）。

## 参考

- [i3/i3](https://github.com/i3/i3)（官方文档质量极高）
- [baskerville/bspwm](https://github.com/baskerville/bspwm)（配合 sxhkd：[baskerville/sxhkd](https://github.com/baskerville/sxhkd)）
- [awesomeWM/awesome](https://github.com/awesomeWM/awesome)（rc.lua 配置、wibox 文档）
- [dwm](https://dwm.suckless.org/)（源码即文档，需自行编译打补丁）
- [xmonad/xmonad](https://github.com/xmonad/xmonad) + [xmonad/xmonad-contrib](https://github.com/xmonad/xmonad-contrib)
- [herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm)（herbstclient 运行时控制）
- [conformal/spectrwm](https://github.com/conformal/spectrwm)
- [qtile/qtile](https://github.com/qtile/qtile)
- [michaelbeaumont/awesome-leaved](https://github.com/michaelbeaumont/awesome-leaved)
- [RobSis/treesome](https://github.com/RobSis/treesome)
- tint2 主题：[addy-dclxvi/tint2-theme-collections](https://github.com/addy-dclxvi/tint2-theme-collections)（32 套）、[MerkeX/tint2-theme-collections](https://github.com/MerkeX/tint2-theme-collections)（备份）、[FanMclaine/Drecked-Tint2-Themes](https://github.com/FanMclaine/Drecked-Tint2-Themes)（Catppuccin）
- [jcrd/dovetail](https://github.com/jcrd/dovetail)（Lua 平铺 WM，2022 年 archived）
- [lab1702/larswm](https://github.com/lab1702/larswm)（C 平铺 WM，2019 年 archived，非 Lua）
- AUR 归档 `fluxbox-lua-git`（Fluxbox Lua 脚本钩子，已废弃）
- 相关：treesome 讨论区、r/unixporn、[gh0stzk/dotfiles](https://github.com/gh0stzk/dotfiles)（bspwm 18 主题）
- 本项目：docs/b10-260918-awesome-musl-static.md（Awesome 在 Alpine/musl 下的编译分析）

## 十二、成熟度梯队、单独支持 Awesome 的发行版与 Lua 平铺 WM 生态现状

> 补充于 2026-09-20：承接上文"定位/选型"，补充各 WM 的成熟度分档，以及哪些发行版把 Awesome 当作默认桌面。

### 1、成熟度与 AwesomeWM 相当的平铺 WM

按稳定性、文档、生态、长期维护与发行版打包情况分三档：

| 梯队 | WM | 星标（2026-09 快照） | 说明 |
|------|----|------|------|
| 第一梯队（公认最成熟） | [i3/i3](https://github.com/i3/i3)（X11） | ~9.9k | 平铺 WM 事实标准，2009 年至今，文档极好、演进保守（v4.21+ 仍属 4.x 系列），发行版打包全覆盖 |
| | [swaywm/sway](https://github.com/swaywm/sway)（Wayland） | ~17.3k | i3 的 Wayland 复刻，2021 年 1.0 后进入稳定期，迁移成本低 |
| | [dwm](https://dwm.suckless.org/)（X11） | 无 GH 计数（社区 ~4.5k+） | 与 Awesome 同年（2006），靠"少即是多"（~2000 行单文件 + patch 生态）保持稳定 |
| 第二梯队（成熟且活跃） | [baskerville/bspwm](https://github.com/baskerville/bspwm)（X11） | ~8.3k | bspc 消息协议脚本驱动，无配置语言，Arch 系流行 |
| | [qtile/qtile](https://github.com/qtile/qtile)（X11+Wayland） | ~5.2k | 与 Awesome 定位最接近：**Python 可编程配置**、模块化 layout/widget，2012 年至今活跃 |
| | [xmonad/xmonad](https://github.com/xmonad/xmonad)（X11） | ~3.4k | 2007 年，Haskell 配置（编译期类型检查），学术背景、极其稳定 |
| | [herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm)（X11） | ~1.2k | 手动平铺（manual tiling），2009 年至今 |
| 第三梯队（流行但年轻） | [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland)（Wayland） | ~38.6k | 2021 年起步，2024–26 热度与特效最高，但 API 变动频繁、向后兼容性不及 i3/Sway |
| | [riverwm/river](https://github.com/riverwm/river)（Wayland） | ~4.3k | 社区较小，维护良好但文档/生态/打包未到第一梯队 |
| | [djpohly/dwl](https://github.com/djpohly/dwl)（Wayland） | ~2.0k | dwm 的 Wayland 对应（wlroots） |
| | [WayfireWM/wayfire](https://github.com/WayfireWM/wayfire)（Wayland） | ~3.1k | 可平铺/堆叠的特效合成器 |

> 星标为 2026-09-21 GitHub API 快照，与第一、三章数据同源（i3 ~9.9k、bspwm ~8.3k、awesome ~6.4k、qtile ~5.2k、xmonad ~3.4k、herbstluftwm ~1.2k）；dwm 无官方 GH 计数，沿用第一章说明。

与 Awesome 对比的关键维度：

- 可编程配置（运行时 Lua 定制）→ **Qtile**（Python）
- 稳定性/保守演进 → **i3 / dwm**
- 模块化 widget 生态（lain/bling）→ **Qtile / bspwm + polybar**
- Wayland 出路（Awesome 官方至今无 Wayland 支持）→ **Sway / Hyprland**

### 2、单独以 Awesome 为默认桌面的发行版

现状：**没有任何主流发行版官方"独占" Awesome 并作为默认桌面**。awesomewm.org/download 明确列举的"Distributions using Awesome as the default window manager"只有一个：

| 类别 | 发行版 | 链接（GH/官网） | 说明 |
|------|--------|------|------|
| 官方点名 | GoboLinux | [官网](https://www.gobolinux.org/) / [github.com/gobolinux](https://github.com/gobolinux) | 源码型发行版（`/Programs` 文件系统布局著称），Awesome 为默认 WM（早期列表还有 OpenIndiana，已被移除） |
| 主流社区版 | Manjaro Awesome CE | [manjaro.org 下载页](https://manjaro.org/download/) / 第三方 [luho91/manjaro-awesome](https://github.com/luho91/manjaro-awesome) | Manjaro 官方社区版，ISO 直接预装 Awesome 配置 |
| | ArcoLinux Awesome | [arcolinux.com/awesome](https://arcolinux.com/awesome/) | ArcoLinux 的 WM 系列版本之一，带配套教程与预配置 |
| | Archcraft | [archcraft.io](https://archcraft.io/) | Arch 系，预配置 Awesome（同时带 openbox/bspwm 等，非独占） |
| 历史/小众（已停或边缘） | Zenix | 无现行官网（已停更） | Slackware 系，网站主打 Awesome，规模极小、长期未更新 |
| | Sabayon | [github.com/Sabayon](https://github.com/Sabayon)（组织存档） | Gentoo 系曾有 Awesome spin（项目已停） |
| | Gentoo LiveDVD | [gentoo.org/downloads](https://www.gentoo.org/downloads/) | 安装时可选 Awesome，非默认 |

对比其他平铺 WM 的"发行版待遇"：i3 有 Regolith Linux（官方定位）、Fedora i3 Spin、EndeavourOS/Manjaro i3 版；Qtile 有 Woof OS；bspwm 有 Exodia OS 等——**Awesome 无任何官方 spin，只有社区版**。

结论：最接近"开箱即用 Awesome"的是 **Manjaro Awesome CE** 或 **ArcoLinux Awesome**；否则 Arch/Debian 装 `awesome` 包 + 抄配置（如 anhsirk0/awesome-config，见 b12）；NixOS 一行 `services.xserver.windowManager.awesome.enable = true` 也能配出。

### 3、除了 Awesome，还有别的 Lua 配置平铺 WM 吗？

> 补充于 2026-09-22：GitHub API 实测核查。**结论：没有第二个"活的"。第一章"偏 Lua：Awesome 是唯一选择"的判断成立，且可以写得更绝对。**

#### 3.1 候选核查结果

| 候选 | 状态 | 实测依据（2026-09-22） |
|------|------|------|
| [awesomeWM/awesome](https://github.com/awesomeWM/awesome) | ✅ 唯一活跃 | 6960 stars，last push 2026-08-28 |
| [Ion](https://en.wikipedia.org/wiki/Ion_(window_manager)) 2.x | ❌ 已死 | 2009 年停更，无 GH 官方仓库 |
| luaxm（纯 Lua X11 WM） | ❌ 已消失 | `neovim/luaxm`、`spectrwm/luaxm` 等仓库全 404，GitHub 搜索无果 |
| neovim-tui（Neovim 的 Lua X11 WM） | ❌ 已消失 | `neovim/neovim-tui`、`neovim/tui`、`nv-tui/neovim-tui` 全 404 |
| dasm | ❌ 已消失 | `dasm/dasm`、`johnparker/dasm` 等全 404 |
| Notion WM（Lua 脚本钩子） | ❌ 仅剩第三方脚本 | `ptman/notion-scripts`（2015 停更）、`meribold/notion-hide-tabs`（2015 停更），主仓库找不到 |
| [larswm](https://github.com/lab1702/larswm) | ❌ 且非 Lua | 1 star、**C 语言**、2019 年 archived |
| [jcrd/dovetail](https://github.com/jcrd/dovetail) | ❌ 已废弃 | Lua，3 stars，2022-03-12 archived |

即：Lua 这条路上的历史选手（luaxm / neovim-tui / dasm / Notion）全部消失，Ion 2009 年停更，只剩 Awesome。这也解释了第四章为什么 Awesome 的定制案例只有 34 个——不是没人用，而是"想要 Lua 方案但 Awesome 不合适"的人没处可去。

#### 3.2 两个容易被误认的"伪 Lua"

| WM | 真相 |
|----|------|
| [conformal/spectrwm](https://github.com/conformal/spectrwm) | 1410 stars、C、last push **2026-07-20**（仍在维护）。但 README 原话是 *"does not require one to learn a language to do any configuration"*，用人类可读文本配置，**刻意反 Lua**；在 `spectrwm.c` 中 grep `lua` 仅命中 `valuators_len` 的误匹配 |
| Hyprland | 见本文第十三章纠错清单：实为 hyprlang + C++ 插件 API，无 Lua |

边缘信号：AUR 归档中的 `aur-archive/fluxbox-lua-git`（2015）曾给 Fluxbox 加过 Lua 脚本钩子，但已进入 AUR archive，等于官方放弃。

#### 3.3 选型含义

- 想要"可编程配置"而非文本配置 → 唯一现成替代是 **Qtile（Python）**，即第一章"与 Awesome 定位最接近"的那款；Lua 侧无第二选择。
- 容器路线不变：i3 > bspwm > Awesome；Alpine/musl 上 Lua 方案只有 `apk add awesome` 一条活路（见 b10），依赖链最重。
- 本节核查同时记录两处数据刷新（保留前文 2026-09-18 快照原值不动）：Awesome 星标现值 **6960**（前文快照 ~6.4k）；spectrwm last push 实测 **2026-07-20**（比前文"约 3 个月前"更活跃）。

### 4、对本项目的影响

- 上文（十一）已指出 Awesome 依赖链最重（Lua + LGI + GTK 生态）、与容器"开箱即用"契合度低于 i3；本节的发行版调查进一步印证：Awesome 生态高度依赖各发行版分发打包，缺少自己的发行版背书，选型优先级维持 i3 > bspwm > Awesome 不变。

## 十三、平铺 WM 起源、实现语言与核心目的（三条来源信息核查）

> 2026-09-21 补充：对三条来源信息（①历史脉络 ②实现语言 ③核心目的）逐条核对权威来源（Wikipedia、IEEE 1988 论文、suckless 邮件列表考古、判例与 Retrocomputing 考据）。
> 总体结论：**大体准确**；两处需修正（Windows 1.0"诉讼说"、Hyprland"用 Lua 说"），一处需补背景（GEM 2.0 的 CP/M 表述）。

### 1、核心目的（信息③）——核查一致

要点：①自动布局专注内容 ②最大化屏幕空间 ③键盘驱动工作流 ④可预测可编程 ⑤轻量高效；解决窗口重叠遮挡、手动调整耗时、屏幕空间浪费、多任务切换低效、鼠标依赖、可定制性差、资源占用高；早期（80 年代）因分辨率低、多任务刚起步而自然选择平铺，现代（2000 后）因开发者对效率/键盘/脚本化需求而复兴。

核查结论：与史料一致。早期动机对应 Xerox 平铺实验（CEDAR 的 tiling 实验目标即"最小化用户缩放定位操作 + 高性能屏幕更新"，见 Swinehart 论文）、Siemens RTL 论文的自动布局策略；现代复兴动机与本文件一、二节选型分析吻合。**无事实错误**。

### 2、起源与早期探索（信息①-A）——逐条核查

| 年份 | 系统 | 原描述 | 核查结果 | 参考链接（早期系统无 GH，附维基/论文） |
|------|------|--------|----------|------|
| 1981 | Xerox Star | 首个平铺组织应用窗口 | ✅ 属实；应用窗口平铺，对话框/属性窗仍可重叠 | [Wikipedia: Xerox Star](https://en.wikipedia.org/wiki/Xerox_Star) |
| 1982 | CEDAR | 第一个使用平铺 WM 的窗口系统 | ✅ 属实（Wikipedia 明确"first windowing system using a tiled window manager"）；备注：更早的平铺实践可上溯至 PARC Alto 时代实验 | [Wikipedia: Cedar](https://en.wikipedia.org/wiki/Cedar_(programming_environment)) |
| 1983 | Andrew WM | 完整平铺式窗口系统，后被 X11 取代 | ✅ 属实 | [Wikipedia: Andrew Project](https://en.wikipedia.org/wiki/Andrew_Project) |
| 1985 | Windows 1.0 | 受法律诉讼影响采用平铺 | ⚠️ 平铺属实，**法律归因存疑**：更可靠考据表明平铺是受前 PARC 员工影响的设计决策（"neat desktop"）；1985 年是与 Apple 的**授权协议**（非诉讼），Apple 正式起诉在 1988 年、对象是 Windows 2.0 的重叠窗口 | [Wikipedia: Windows 1.0](https://en.wikipedia.org/wiki/Windows_1.0) |
| 1986 | GEM 2.0 | 为 CP/M 开发、默认平铺 | ⚠️ 需补背景：说法沿袭 Wikipedia"windowing system for the CP/M"；实际 GEM/1 为可重叠窗口，2.0（1986.3）是 Apple 诉讼和解后改为桌面仅两个固定平铺窗口；主要运行于 MS-DOS/DOS Plus 与 Atari ST（TOS），与 CP/M 的关联仅是早期原型（Concurrent CP/M / CP/M-68K） | [Wikipedia: GEM](https://en.wikipedia.org/wiki/GEM_(desktop_environment)) |
| 1988 | Siemens RTL | X11R2/R3、自动缩放排列算法、教科书范例 | ✅ 属实（IEEE 1988 论文；基于 Andrew 项目思想；常称首批 X11 平铺 WM / 首个自动放置缩放策略实现，而非"第一个平铺 WM"） | [IEEE 1988 论文](https://doi.org/10.1109/comwor.1988.4808) |

### 3、现代复兴：系统与实现语言（信息①-B + ②）——核查一致（Hyprland 语言除外）

| 年份 | 系统 | 语言 | 链接 / 星标 | 核查 |
|------|------|------|------|------|
| 2000 | [Ion](https://en.wikipedia.org/wiki/Ion_(window_manager)) | C / Lua（v2 起 Lua 配置） | 无 GH（维基） | ✅ 键盘友好，现代平铺先驱之一 |
| 2003-2005 | [wmii](http://wmii.suckless.org/) | C（前身 wmi 曾用 C++） | 无 GH（suckless） | ✅ 模块化轻量，标签+平铺 |
| 2004 | [larswm](https://en.wikipedia.org/wiki/Larswm) | C（9wm 分支） | 无 GH（维基） | ✅ 基于 9wm 的全自动平铺 |
| 2006 | [dwm](https://dwm.suckless.org/) | C（纯 C、无配置文件） | 无 GH 计数（社区 ~4.5k+） | ✅ suckless 极简典范（~2000 行纯 C） |
| 2007 | [awesomeWM/awesome](https://github.com/awesomeWM/awesome) & [xmonad/xmonad](https://github.com/xmonad/xmonad) | C / Lua · Haskell | ~6.4k / ~3.4k | ✅ awesome 确为 dwm 分支、框架 C + 配置 Lua；xmonad 纯 Haskell |
| 2009 | [i3/i3](https://github.com/i3/i3) | C（JSON IPC） | ~9.9k | ✅ 手动平铺、文档完善、至今最流行之一 |
| 2012 | [baskerville/bspwm](https://github.com/baskerville/bspwm) | C | ~8.3k | ✅ 二叉空间分割、bspc/sxhkd 消息驱动 |
| 2016-2019 | [swaywm/sway](https://github.com/swaywm/sway) | C（wlroots） | ~17.3k | ✅ 2016 起步、2020 前的 2019 发布 1.0（i3 的 Wayland 替代） |
| 2022 | [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland) | C++（配置为 **hyprlang**，非 Lua） | ~38.6k | ❌ 语言纠正：核心 C++；配置为自研 hyprlang（hyprland.conf 声明式语法）、非 Lua；扩展走 C++ 插件 API（hyprpm）——定位 ✅ 高定制/特效 |

> 早期系统语言（信息②，对应信息①-A 上表）：Xerox Star=Mesa ✅ / CEDAR=Cedar ✅ / Andrew=C（面向对象预处理器）✅ / Siemens RTL=C（推测，合理：基于 Andrew 且为 X11 程序）✅。


### 4、核查总结（纠错清单）

1. ❌ **Hyprland 用 Lua 配置**——最明显错误：实为 hyprlang + C++ 插件 API，无 Lua。
2. ⚠️ **Windows 1.0"受诉讼影响平铺"**——流行说法，但 Retrocomputing 考据与同期记录显示是设计决策（受 PARC 平铺研究影响）；1985 Apple 与 MS 之间是授权协议，1988 诉讼针对 Windows 2.0。
3. ⚠️ **GEM 2.0"为 CP/M 开发"**——沿袭 Wikipedia 表述；实际为 Apple 诉讼和解产物（可重叠改固定双窗口平铺），主战场 DOS 系与 Atari ST（TOS），CP/M 仅早期原型。
4. ✅ 其余各条（Star/CEDAR/Andrew/RTL 及现代各 WM 的年份、定位、语言）与 Wikipedia、IEEE 1988 RTL 论文、suckless 邮件列表等可靠来源一致。
5. 📌 "第一个平铺 WM"表述分层次：Xerox Star（1981）常称"始祖"、CEDAR（1982）常称"第一个使用平铺 WM 的窗口系统"、Siemens RTL（1988）常称"首批 X11 平铺 WM / 首个自动布局策略"——出处不同，引用时宜区分。

### 5、来源

- [Wikipedia: Tiling window manager](https://en.wikipedia.org/wiki/Tiling_window_manager)（Star/CEDAR/Andrew/Windows 1.0/GEM 2.0/RTL 早期条目）
- [IEEE Comwor 1988: Automatic strategies in the Siemens RTL tiled window manager](https://doi.org/10.1109/comwor.1988.4808)
- suckless dev 邮件列表（2011-12，RTL 源码考古与年代梳理）
- [Retrocomputing SE: Windows 1.0 平铺是法律还是技术原因](https://retrocomputing.stackexchange.com/questions/32511)
- Apple Computer, Inc. v. Microsoft Corp.（1985 授权协议 + 1988 起诉背景，法院文件）
- Hyprland 官方 Wiki（hyprlang 配置语言与 C++ 插件 API）

## 十四、AwesomeWM 评价与设计影响谱系（2026-09-23 补充）

### 1、AwesomeWM：平铺 WM 里少有的"框架型常青树"

awe 仓库代码很简洁，仓库提交管理得很好，而且是棵常青树，非常优秀。

确实，AwesomeWM（awe）算是平铺窗口管理器里少有的"框架型常青树"。它的优秀不只在于功能，而在于架构克制、可编程性强、社区文化独特。几点很突出：

- **核心与配置分离得干净**：C 核心负责 X11 交互、窗口管理和绘图原语，Lua 层负责策略与界面。gears、awful、wibox、naughty 分层清晰，既不像 dwm 那样一切硬编码，也不像某些 WM 把配置和核心搅在一起。
- **提交与文档管理成熟**：早期 Julien Danjou 打下底子，后来 psychon、elv1313 等人持续重构。发布 tag、CHANGELOG、API 文档、迁移指南都比较完整，commit 粒度也普遍清楚。尤其是 awful 的多次重构，能看出对 API 长期演进的克制。
- **"配置即代码"的生命力**：Lua 嵌入让用户能直接写逻辑，而不是只填配置项。这让它从 WM 变成了一个可编程桌面框架。社区大量 dotfiles、模块、插件反过来又延长了它的寿命。
- **常青的原因**：X11 生态稳定、Lua 轻量、依赖少、发行版长期打包，加上 Awesome 的 API 兼容策略，很多十年前的配置稍作修改仍能跑。
- **客观挑战**：Wayland 支持缺失是最大隐忧，4.3 之后稳定发布节奏也慢了下来。但它作为 X11 时代的"可编程 WM 框架"，设计影响了很多后来的项目。

所以它更像一棵"慢生长的树"：不追热点，但根扎得深。menubar、wibox、wibar 这些命名方言，其实也是这种身份的体现——它不是在做某个桌面环境的面板，而是在提供一套搭建桌面的原语。十几年后还有人在写 rc.lua 和 startup.sh，本身就是最好的证明。

### 2、设计影响：为 Wayland 移植重构 + 启发可编程 WM 两个方向

设计影响主要体现在两个方向：为 Wayland 生态提供"Awesome 式"的移植与重构，以及在架构上启发了一批可编程窗口管理器。

#### 2.1 直接衍生与重实现（以 AwesomeWM 的代码或 API 为蓝本，力求在 Wayland 下复现其体验）

- **SomeWM**（[trip-zip/somewm](https://github.com/trip-zip/somewm)，388★，活跃 2026-09）：将 AwesomeWM 移植到 Wayland 的项目，目标是实现 100% 的 Lua API 兼容，让用户可以直接沿用现有的 rc.lua 配置和组件。项目支持 naughty 通知库和 ruled.notification 规则，并在 AUR、Debian/Ubuntu 和 Fedora 等仓库有打包（1.4.0 稳定版，基于 wlroots 0.19，支持 `awesome.restart()` 热重载）。
- **Pinnacle**（[pinnacle-comp/pinnacle](https://github.com/pinnacle-comp/pinnacle)，638★，活跃 2026-06）：基于 Rust 和 Smithay 构建的 Wayland 合成器，明确以"为 Wayland 打造 AwesomeWM"为目标。支持标签系统、动态平铺和自定义布局，并提供了 Lua 和 Rust 两种配置方式（内置 master-stack/spiral/dwindle/fair 等布局），在概念上高度致敬 AwesomeWM。
- **Way Cooler**（[way-cooler/way-cooler](https://github.com/way-cooler/way-cooler)，2139★，2019 归档）：用 **C** 编写（wlroots + meson 构建）的 Wayland 合成器，定位是"AwesomeWM 的 Wayland 合成器组件"，运行打补丁的 awesome 客户端、配置即 Lua（rc.lua），并将扩展实现为独立客户端程序（早期版本曾用 Rust + wlc，后重写为 C）。该项目目前已归档，但其设计思路仍有参考价值。
- **CwC**（[Cudiph/cwcwm](https://github.com/Cudiph/cwcwm)，186★，活跃 2026-09）：基于 wlroots 的可扩展 Wayland 合成器，深受 AwesomeWM 影响，同样使用 Lua 配置和 C 插件扩展。项目文档特别提到，其源自 AwesomeWM 的 API 保证不会轻易破坏，以维持配置的稳定性（基于 wlroots 0.20，AUR 已有 cwc 包）。

#### 2.2 受启发的独立项目（借鉴 Lua 可编程配置或标签式工作流，但并非直接移植）

- **Swaysome**（[hyask/swaysome](https://gitlab.com/hyask/swaysome)，GitLab 托管，24★，2026-07 活跃）：定位不是合成器，而是帮助 Sway 用户配置出"更像 AwesomeWM"工作流的工具，主要复现其标签式工作区体验（workspace groups）。Rust 实现（crates.io 2.3.2），AUR/Void/Debian 有包。
- **wmoon**（[Natchuz/wmoon](https://github.com/Natchuz/wmoon)，6★，2022 归档）：用 Zig 编写的 Wayland 窗口管理器，自称"在精神上遵循 AwesomeWM"，并使用 Moonscript 进行完全的自定义配置。
- **PyleWM**（[Lucas7211/PyleWM](https://github.com/Lucas7211/PyleWM)，33★，2024-10 最后推送）：在 Windows 平台上实现的平铺窗口管理工具，灵感来源于 Linux 下的 i3 和 AwesomeWM。

#### 2.3 总结

这些项目构成了一个清晰的谱系：SomeWM 和 Way Cooler 是直接的"继承人"，Pinnacle 和 CwC 是在新生态下的"转世"，而 Swaysome 和 wmoon 则是受到其工作流启发的"远亲"。它们共同证明了 AwesomeWM "配置即代码"和"标签式管理"理念的持久影响力。

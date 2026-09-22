# b14-260921 | Awesome 细化配置使用

> 背景：对照分析 [anhsirk0/awesome-config](https://github.com/anhsirk0/awesome-config)（Gitee 镜像：https://gitee.com/g-system/fk-anhsirk0-awesome-config ，原仓库在 Codeberg：https://codeberg.org/anhsirk0/awesome-config）与 AwesomeWM 官方默认配置（`/etc/xdg/awesome/rc.lua`）的区别，作为本项目 Awesome 配置细化的参考案例。
> 该仓库基于 awesome-copycats 修改，本文件为 2026-09-21 对源码文件的梳理。

## 一、anhsirk0/awesome-config 与默认 Awesome 的配置区别

### 1、仓库结构：单文件 → 模块化

默认配置只有一个 `rc.lua`，包含全部逻辑；本仓库拆成 5 个模块 + 主题目录：

| 文件 | 职责 |
|------|------|
| `rc.lua` | 入口：加载模块、布局、信号（边框/焦点/标题栏）、autostart |
| `keys.lua` | 全部按键绑定（全局 + 客户端 + 鼠标），返回 `globalkeys` |
| `rules.lua` | client 匹配规则表（`awful.rules.rules`） |
| `theme.lua` | 主题入口：选主题、字体、颜色映射、tag 名、`at_screen_connect` |
| `bar.lua` | wibox 顶栏组装（taglist + 时钟 + 托盘 + lain 部件） |
| `themes/` + `old-themes/` | 68 套配色（modus×8、ef×36、doric×16、old×8），纯颜色定义 |
| `scripts/change-theme.pl` | 用 fzf 交互式切换主题（`change-theme.pl viv` / `gruv`） |

其他差异：

- **删除了默认的错误处理**（naughty 捕获 rc.lua 异常）和 **hotkeys_popup 帮助**（`Mod4+s`，已注释）。
- `beautiful.init` 由默认的 `gears.filesystem.get_configuration_dir()` 改为**硬编码** `$HOME/.config/awesome/theme.lua`（旧主题分支则指向 `themes/<name>/theme.lua`）。
- 默认 9 个 tag，这里 7 个，名字可在 theme.lua 里改（数字 / 特殊字符 / 字母均可）。

### 2、主题系统（与默认最大差异）

- 默认：一个 `themes/default/theme.lua`，基本只换一个主色。
- 本仓库：**68 套主题全部来自 Emacs 的 Modus / Ef / Doric 配色移植**，每套是独立的 `colors.lua`（fg/bg/accent 体系），非 RGB 硬编码。
- theme.lua 里 `local chosen_theme = "ef-trio-dark"` 一行选主题，运行时也可用 `scripts/change-theme.pl`（fzf）或 `Mod4+=`（dmenu 脚本）切换。
- 字体：Iosevka / Aporetic 等，`theme.font` 可随时换；默认字体档位对应 1920x1080，1366x768 需调字号和间隙。

### 3、按键绑定（keys.lua）

整体风格：

- **交换了 Alt 和 Ctrl**：`altkey = "Control"`、`ctrlkey = "Mod1"`，为 Emacs 习惯设计。
- 大量**应用专属快捷键**：浏览器（`Mod4+b`）、私有窗口（`Mod4+Shift+b`）、`emacsclient -c`（`Mod4+r`）、文件管理器（`Mod4+e`）、Lollypop 音乐（`Mod4+x/./,`）、蓝牙（`Mod4+[`）等。
- 启动器走 **dmenu/rofi 脚本**（`windows.pl`、`volume.pl`、`theme.pl`、`brightness.pl`、`powermenu.pl` 等），路径硬编码在 `keys.lua` 顶部变量（`dmenu_dir`、`rofi_dir`、`scripts_dir`）。
- `F12` 绑定下拉终端（`my_dropdown:toggle()`，注：keys.lua 里 `my_dropdown` 未在本仓库定义，疑为遗留）。
- `Mod4+o` 是 **keychord（键弦）**：先按 `Mod4+o`，再按 a/b/k/t/u/x 触发不同动作（下拉终端、kmonad 脚本、xrandr-toggle 等）。
- 大量 `Mod4+Ctrl+Alt` 细调组合：亮度/音量 ±5%/10%/到顶/静音，带 naughty 通知（`spawn_and_notify` 封装）。
- 截图全家桶：`Print`/`Ctrl+Print`/`Alt+Print`/`Shift+Print` 分别全屏/窗口/区域/OCR，另有 `Mod4+Alt` 冗余版和 `Mod4+Print` rofi 菜单。

与默认键位对照：

| 功能 | 默认 | 本仓库 |
|------|------|--------|
| 终端 | `Mod4+Return` | `Mod4+Return`（st/alacritty）+ `Mod4+'` |
| 运行框 | `Mod4+r`（run prompt） | `Mod4+r`（emacsclient）+ `Mod4+a`（rofi 启动器） |
| 布局切换 | `Mod4+Space` | `Mod4+Space`（inc -1） |
| 重置配置 | `Mod4+Ctrl+r` | `Mod4+Ctrl+r`（Ctrl 被换为 Alt 键） |
| menubar | `Mod4+p` | `Mod4+y`（`menubar.show_categories = false`） |
| 帮助 | `Mod4+s` | 删（hotkeys_popup 注释掉） |

### 4、布局（rc.lua）

默认启用 tile、fair、floating、max、magnifier 等一整套；这里**几乎全部注释，只留 `tile` 和 `tile.bottom`**（spiral.dwindle 等也注释）。lain/centerwork 相关布局全部关闭。

### 5、规则（rules.lua）

| 差异点 | 默认 | 本仓库 |
|--------|------|--------|
| 忽略 size hints | 保持 | `size_hints_honor = false`（去掉终端间缝隙） |
| 新窗口位置 | 默认置 master | `callback = awful.client.setslave`（末尾） |
| 放置策略 | `no_offscreen` | `no_overlap + no_offscreen` |
| 浮动窗口规则 | Arandr/Gpick 等基础列表 | 另加 `org.gnome.FileRoller`、`pinentry`、`xtightvncviewer` 等 |
| 标题栏 | 默认 `titlebars_enabled = false` | `titlebars_enabled = true`（normal/dialog） |
| 应用固定 | 无 | Lollypop / smplayer 固定到 tag[3] 并 `view_only()`；自定义 `float_on_top_in_corner`（620x120、ontop+floating、固定坐标） |

> 注意：rules.lua 里 `titlebars_enabled = true`，但 rc.lua 的 `request::titlebars` 回调只写了按钮定义、**没有真正创建 `awful.titlebar(c)`**，实际无可见标题栏（删减后的半成品）。

### 6、顶栏（bar.lua）

- 位置：默认顶部 → 本仓库**底部**（`position = "bottom"`，高 26px）。
- 内容：taglist + 时钟 + 托盘 + **音量（`lain.widget.alsa`）+ 电池（`lain.widget.bat`）+ Lollypop 歌曲名**；**没有 tasklist、没有 layoutbox**。
- 部件间用 `|` 分隔符；taglist 用 `filter.all` + 滚轮切 tag；音量 >115 会红字警告。
- 依赖两个外部库：**`lain`**（alsa/bat widget）和 **`bling`**（tiled_wallpaper 生成壁纸图案），主题 tiled wallpaper 用 `⚝` 符号铺背景。
- `s.mywibar` 命名供 `Mod4+z` 切换显隐。

### 7、其他要点

- **autostart**：`awful.spawn($HOME/.config/awesome/scripts/autorun.sh)`，与默认的 autorun.sh 思路一致。
- **sloppy focus**：与默认相同用 `mouse::enter` 信号，另排除 magnifier 布局。
- **单窗去边框**：复用默认的 arrange 信号逻辑（唯一客户端时 `border_width = 0`），但用宏 `screen.count()` 循环而非 `connect_for_each_screen`。
- **键盘布局兼容**：tag 1-9 用 `keycodes`（`np_map`）绑定，不依赖键盘布局。
- **硬编码个人路径**（拿来需改）：`/home/krishna/...`（bar.lua 的 lollypop 标题脚本）、`/mnt/projects/suckless/dmenu/scripts/`、`/mnt/projects/Git/extra/boomer/`、`waterfox`、`st`、`nemo`。

### 8、对本项目的启发（落地参考）

- **模块化拆分**与本项目一致：`keys`/`rules`/`theme`/`bar` 分离 ≈ entry-x11base.sh / xvnc2.sh / src/bin 的分工；后续若在容器内集成 Awesome（见 b10/b11），可参考该结构让用户只改 `.arg` 级配置。
- **多主题体系**（Emacs 配色移植）可作为容器桌面"配置文件热切换"的参考：`change-theme.pl` + 运行时切换 ≈ 本项目 `.arg` 热加载思路（`docker-compose restart desktop`）。
- 注意其**依赖链**（lain/bling/多套 dmenu-rofi 脚本 + 硬编码路径）不符合容器"开箱即用"原则；仅借鉴结构，不直接搬用。

### 9、参考

- Gitee 镜像：https://gitee.com/g-system/fk-anhsirk0-awesome-config
- GitHub 同步：https://github.com/anhsirk0/awesome-config
- 原仓库（Codeberg）：https://codeberg.org/anhsirk0/awesome-config
- 主题来源：Modus/Ef/Doric（protesilaos）、wezterm/alacritty/rofi/xresources/kakoune 各终端主题仓库
- 相关文档：docs/b10-260918-awesome-musl-static.md、docs/b11-260918-tiling-wm.md、docs/b12-260920-awesome-config-guide.md

## 二、AwesomeWM 默认配置快捷键：高频清单与总量统计

> 对照基准：AwesomeWM 4.3 默认 `rc.lua`（`/etc/xdg/awesome/rc.lua`），`modkey = Mod4`（Super/Win 键）。本节约为 b14 的比较底板，也便于与上文 anhsirk0 键位表（第 3 节）对照差异。

### 1、高频实用快捷键

| 快捷键 | 功能 |
|--------|------|
| `Mod4+Enter` | 打开终端（默认 xterm） |
| `Mod4+w` | 显示主菜单 |
| `Mod4+j` / `Mod4+k` | 聚焦下一个/上一个窗口 |
| `Mod4+Shift+j` / `Mod4+Shift+k` | 与下一/上一个窗口交换位置 |
| `Mod4+方向键` | 按方向聚焦（上下左右） |
| `Mod4+Shift+方向键` | 按方向交换窗口 |
| `Mod4+数字 1-0` | 切换标签页 |
| `Mod4+Shift+数字` | 把当前窗口移到指定标签 |
| `Mod4+Space` / `Mod4+Shift+Space` | 下一个/上一个布局（tile、floating、max 等） |
| `Mod4+Ctrl+Space` | 切换窗口浮动/平铺 |
| `Mod4+h` / `Mod4+l` | 减小/增大主窗口宽度占比（master 宽度） |
| `Mod4+Shift+h` / `Mod4+Shift+l` | 减少/增加主区窗口数（master 数量） |
| `Mod4+f` | 全屏切换 |
| `Mod4+m` | 最大化切换 |
| `Mod4+Ctrl+n` / `Mod4+Shift+n` | 最小化到托盘 / 恢复最小化 |
| `Mod4+Shift+c` | 关闭当前窗口 |
| `Mod4+t` | 置顶切换（ontop） |
| `Mod4+Ctrl+r` | 重启 awesome |
| `Mod4+Shift+q` | 退出 awesome |
| `Mod4+Escape` | 恢复上一个标签（tag history） |
| `Mod4+s` | 显示快捷键帮助面板（hotkeys_popup） |

注意：默认配置**没有应用启动器**（dmenu/rofi），社区常用 `Mod4+r`/`Mod4+p` 自绑；anhsirk0 方案用 `Mod4+a`（rofi）代替。

### 2、总量与分类统计（约 75~80 条）

| 类别 | 数量 | 构成 |
|------|------|------|
| 标签页操作（数字键） | **40** | `1-0` × 4 组：查看 / 查看+切换 / 移动 / 移动+切换 |
| 窗口焦点与交换 | ~12 | `j/k`、`Shift+j/k`、方向键 ×4、`Shift+方向键` ×4 |
| 布局与尺寸 | ~8 | `Space/Shift+Space`、`h/l` 族（含 Shift、Ctrl 变体共 6 条） |
| 窗口操作（clientkeys） | ~10 | close/fullscreen/maximize/minimize/restore/floating/ontop/换屏等 |
| awesome 自身控制 | ~8 | 帮助/菜单/重启/退出/Lua 终端/清除输入等 |
| 鼠标键（不计入键盘） | — | `Mod4+左键`移动窗口、`Mod4+右键`缩放、标题栏按钮 |

**合计约 75~80 条**，其中数字标签类占一半（40），真正"功能各异"的实质快捷键约 35~40 条。不同小版本（4.2/4.3）略有出入。

### 3、验证方法

```bash
grep -c "awful.key" /etc/xdg/awesome/rc.lua   # 粗略 keybinding 数量
```

运行时按 `Mod4+s` 打开 hotkeys_popup 帮助面板，其分类列表即权威清单（anhsirk0 方案已删此功能，见第 1 节）。

## 三、Awesome 组件体系：版本、作者与命名参考

> 背景：2026-09-22 补充，内容已对照 GitHub release notes（v4.0/v4.2）、NEWS.md 及 API 文档模块页的 Copyright/Author 字段核实。

### 1、组件引入版本、时间与主要作者（已核实）

| 组件 | 引入版本 | 时间 | 主要作者（文档 Copyright 字段） |
|------|----------|------|------|
| `wibox` | 3.1 | 2008-12-12 | Julien Danjou（创始人；3.1-rc1 起 "wibox and image types were added"，statusbar 对象被 wibox 取代） |
| `naughty` | 3.x 早期 | 2008 | **koniu**（Author: koniu，copyright 2008） |
| `awful.tooltip` | 3.2~3.3 期间 | 2009 | Sébastien Gross（copyright 2009） |
| `menubar` | 独立模块 | 2011-2012 | Alexander Yakushev（`menu_gen`/`utils` 原型出自 Antonio Terceiro，2009） |
| `awful.wibar` | 4.0 | 2016-12-25（v4.0 发布） | Emmanuel Lepage Vallee (elv1313)，copyright 2016 |
| `awful.popup` | **4.2** | 2017-07-15（v4.2 发布） | Emmanuel Lepage Vallee (elv1313)，copyright 2016 |
| `awful.titlebar` | 3.x 已有，4.0 重构 | 2015~2016 | 核心团队（Uli Schlachter 等；3.5.2 已有 show/hide/toggle） |

### 2、常见说法修正

- **naughty 作者不是 Julien Danjou**：API 文档明确为 koniu（2008）；Julien 是项目创始人但不写 naughty。
- **awful.popup 是 4.2 引入，不是 4.3**：v4.2 release notes 原文 "A new popup widget allows to bypass most of the boilerplate code..."；4.3（2019-01）只是继续完善。
- **awful.wibar 继承自 wibox，不是 awful.popup**：elv1313 曾有"wibar 从 popup 派生"的计划（issue #3599），未实施；4.x 中 wibar 是 wibox 的子类（3.5→4.0 迁移：`awful.wibox{}` → `awful.wibar{}`）。
- **awful.titlebar 3.x 已存在**：3.5.2 changelog 已有 "awful.titlebar: Add show, hide, toggle functions"；4.0 是 API 重构而非首次引入。
- wibox 引入时间为 2008-12-12（3.1 正式版），"2008-10" 实为 3.1-rc 阶段。

### 3、命名参考：TWM 圈的"Awesome 方言"

- **wibox = widget + box**：官方口径即"容纳 UI 小组件的盒子"，wibar/awful.popup/awful.tooltip 都是特殊化的 wibox。
- **出身**：Awesome 2.x 是 dwm 的 fork，继承 dmenu/dwm 式"造词"简洁风格；3.0 起 C+Lua 完全重写，命名风格延续。
- **对通用概念的方言化**：X11 世界叫 panel/dock/notification-daemon，Awesome 自造 wibox/wibar/naughty，强调"可编程框架"而非现成组件。
- 同类 TWM 参照系：**xmonad**（`XMonad.Layout/Hooks` 函数式精确）、**i3**（`i3bar/i3status/i3blocks` 直白实用）、**bspwm**（bsp = 二叉空间分割，借算法概念）。Awesome 介于 xmonad 的抽象与 i3 的直白之间，既有 naughty 的拟人俏皮，也有 wibar 的功能直述。

### 4、版本时间线速查

| 版本 | 时间 | 备注 |
|------|------|------|
| 3.0 | 2008-09-18 | C+Lua 重写 |
| 3.1 | 2008-12-12 | wibox 引入 |
| 3.2 | 2009-03-13 | |
| 3.4 | 2009-10-20 | |
| 3.5 | 2012-12-21 | 主题系统大改 |
| 3.5.9 | 2016-03-06 | 3.x 最后一版 |
| 4.0 | 2016-12-25 | awful.wibar、API 断代 |
| 4.2 | 2017-07-15 | awful.popup |
| 4.3 | 2019-01-31 | |
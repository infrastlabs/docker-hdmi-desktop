# b12-260920 | AwesomeWM 热门配置项目与模块指南（知识整理）

> 背景：整理 AwesomeWM 生态中受欢迎的配置项目、第三方模块、主题模板和最佳实践，为容器桌面项目提供配置参考。重点收集核心社区模块、热门配置模板、常用小部件配置模式、高级功能集成方案。
> 说明：星标数和活跃度为 2026-09-20 附近的快照，随社区变动仅供参考，实际选择应以"需求匹配 + 维护状态"为准。


## 一、AwesomeWM 配置指南大全

### 1、核心社区模块与库

#### 1.1 主流模块库

| 项目 | GitHub Stars | 主要功能 | 活跃状态 |
|------|--------------|----------|----------|
| **[lcpz/lain](https://github.com/lcpz/lain)** | ⭐1,076 | 布局、异步小部件、实用函数（替代 awesome-vain） | 活跃（2024-01-25 更新） |
| **[BlingCorp/bling](https://github.com/BlingCorp/bling)** | ⭐858 | 实用工具集：Flash Focus、标签容器、任务预览等 | 归档（但代码仍可用） |
| **[andOrlando/rubato](https://github.com/andOrlando/rubato)** | ⭐266 | 平滑动画与缓动函数（专注于动画） | 活跃 |
| **[streetturtle/awesome-wm-widgets](https://github.com/streetturtle/awesome-wm-widgets)** | ⭐2,264 | Spotify、CPU、RAM、亮度、音量、电池等小部件 | 活跃（2026-04-21 更新） |

#### 1.2 其他优秀模块

| 模块 | 功能特点 | 推荐度 |
|------|----------|--------|
| **[ReadyWidgets/awesome-extrautils](https://github.com/ReadyWidgets/awesome-extrautils)** | 额外工具函数 | ★★★☆☆ |
| **[eromatiya/awesome-glorious-widgets](https://github.com/eromatiya/awesome-glorious-widgets)** | 豪华小部件集合 | ★★★☆☆ |
| **[Elv13/radical](https://github.com/Elv13/radical)** | 高级小部件系统 | ★★★★☆ |
| **[vicious-widgets/vicious](https://github.com/vicious-widgets/vicious)** | 小部件数据提供器（传统） | ★★☆☆☆ |
| **[K4rakara/awestore](https://github.com/K4rakara/awestore)** | 状态管理和动画框架 | ★★★★☆ |

#### 1.3 模块选择建议

- **刚入门**：先掌握默认配置，逐步添加 [streetturtle/awesome-wm-widgets](https://github.com/streetturtle/awesome-wm-widgets) 中的实用小部件
- **需要高级布局**：集成 [lcpz/lain](https://github.com/lcpz/lain) 的额外布局和异步小部件
- **追求动画效果**：结合 [andOrlando/rubato](https://github.com/andOrlando/rubato) 和 [BlingCorp/bling](https://github.com/BlingCorp/bling) 的动画功能
- **项目已归档注意**：[BlingCorp/bling](https://github.com/BlingCorp/bling) 已归档但代码仍可参考，优先选择活跃维护项目

### 2、热门配置模板与主题

#### 2.1 配置模板项目

| 模板项目 | GitHub Stars | 特点 | 适用场景 |
|----------|--------------|------|----------|
| **[sewergweller/modular-awm-default](https://github.com/sewergweller/modular-awm-default)** | - | 模块化默认配置，更易理解和扩展 | 新手入门、模块化学习 |
| **[lcpz/awesome-copycats](https://github.com/lcpz/awesome-copycats)** | - | 多主题模板，包含 10+ 主题 | 主题切换、现成配置 |
| **[arcolinux/arcolinux-awesome](https://github.com/arcolinux/arcolinux-awesome)** | - | ArcoLinux 官方配置，功能全面 | 生产环境、完整功能 |
| **[Gwynsav/gwileful](https://github.com/Gwynsav/gwileful)** | - | 基于模块化默认配置的简洁配置 | 简洁风格、现代配置 |

#### 2.2 完整配置示例（可直接参考）

| 配置项目 | GitHub Stars | 特点 | AwesomeWM 版本 |
|----------|--------------|------|----------------|
| **[raven2cz/awesomewm-config](https://github.com/raven2cz/awesomewm-config)** | - | 现代配置，支持 dashboard、machi 布局等 | 4.3+ |
| **[ThePrimeagen/.dotfiles](https://github.com/ThePrimeagen/.dotfiles)** | - | 知名开发者的配置 | 4.3+ |
| **[anhsirk0/awesome-config](https://github.com/anhsirk0/awesome-config)** | - | 模块化配置，Rofi 集成良好 | 4.3+ |

#### 2.3 常用主题列表（来自 [lcpz/awesome-copycats](https://github.com/lcpz/awesome-copycats)）

```lua
-- 常用主题配置示例
local themes = {
    "blackburn",    -- 1 - 深色专业
    "copland",      -- 2 - 简洁现代
    "dremora",      -- 3 - 暗黑风格
    "holo",         -- 4 - 全息效果
    "multicolor",   -- 5 - 多色主题（热门）
    "powerarrow",   -- 6 - 箭头风格（热门）
    "powerarrow-dark",  -- 7 - 暗色箭头
    "rainbow",      -- 8 - 彩虹渐变
    "steamburn",    -- 9 - 蒸汽朋克
    "vertex"        -- 10 - 顶点风格
}

local chosen_theme = themes[5]  -- 选择 multicolor
local theme_path = string.format("%s/.config/awesome/themes/%s/theme.lua", os.getenv("HOME"), chosen_theme)
beautiful.init(theme_path)
```

### 3、常用小部件配置模式

#### 3.1 系统监控小部件（使用 [lcpz/lain](https://github.com/lcpz/lain)）

```lua
-- 电池小部件
local batwidget = lain.widgets.bat({
    battery = "BAT0",
    settings = function()
        if bat_now.status == "Discharging" then
            widget:set_markup(" ⚡ " .. bat_now.perc .. "% ")
        else
            widget:set_markup(" 🔌 " .. bat_now.perc .. "% ")
        end
    end,
    timeout = 30
})

-- 音量小部件
local volumewidget = lain.widgets.alsa({
    settings = function()
        if volume_now.status == "off" then
            volume_now.level = volume_now.level .. " 🔇"
        else
            volume_now.level = volume_now.level .. "% 🔊"
        end
        widget:set_markup(volume_now.level)
    end
})

-- CPU 小部件
local cpuwidget = lain.widgets.cpu({
    settings = function()
        widget:set_markup(" 🖥️ " .. cpu_now.usage .. "% ")
    end,
    timeout = 2
})
```

#### 3.2 现代化小部件（[streetturtle/awesome-wm-widgets](https://github.com/streetturtle/awesome-wm-widgets)）

```lua
-- 需要先安装 streetturtle/awesome-wm-widgets 模块
local volume_widget = require("awesome-wm-widgets.volume-widget.arc")
local battery_widget = require("awesome-wm-widgets.batteryarc-widget.batteryarc")
local brightness_widget = require("awesome-wm-widgets.brightnessarc-widget.brightnessarc")

-- 配置示例
s.mywibox:setup {
    layout = wibox.layout.align.horizontal,
    { -- Left widgets
        layout = wibox.layout.fixed.horizontal,
        mylauncher,
        s.mytaglist,
    },
    s.mytasklist, -- Middle widget
    { -- Right widgets
        layout = wibox.layout.fixed.horizontal,
        battery_widget(),
        volume_widget(),
        brightness_widget(),
        mytextclock,
        s.mylayoutbox,
    }
}
```

#### 3.3 自定义小部件模式

```lua
-- 网络状态小部件
local netwidget = wibox.widget.textbox()
local net_timer = gears.timer({
    timeout = 5,
    call_now = true,
    autostart = true,
    callback = function()
        local f = io.popen("ip addr show | grep 'state UP' | head -1")
        if f then
            local output = f:read("*all")
            f:close()
            if output:match("state UP") then
                netwidget:set_markup(" 🌐 ")
            else
                netwidget:set_markup(" 📡 ")
            end
        end
    end
})

-- 天气小部件（示例）
local weather_widget = wibox.widget.textbox()
weather_widget:set_markup(" ☀️ 25°C ")
```

### 4、按键绑定最佳实践

#### 4.1 多媒体键绑定（最常见）

```lua
-- 音量控制
awful.key({}, "XF86AudioRaiseVolume", function()
    os.execute(string.format("amixer -q set %s 5%%+", beautiful.volume.channel))
    beautiful.volume.update()
end, {description = "volume +5%", group = "media"}),

awful.key({}, "XF86AudioLowerVolume", function()
    os.execute(string.format("amixer -q set %s 5%%-", beautiful.volume.channel))
    beautiful.volume.update()
end, {description = "volume -5%", group = "media"}),

awful.key({}, "XF86AudioMute", function()
    os.execute(string.format("amixer -q set %s toggle", beautiful.volume.channel))
    beautiful.volume.update()
end, {description = "toggle mute", group = "media"}),

-- 亮度控制
awful.key({}, "XF86MonBrightnessUp", function()
    os.execute("xbacklight -inc 10")
end, {description = "brightness +10%", group = "media"}),

awful.key({}, "XF86MonBrightnessDown", function()
    os.execute("xbacklight -dec 10")
end, {description = "brightness -10%", group = "media"}),

-- 媒体播放控制
awful.key({}, "XF86AudioPlay", function()
    awful.util.spawn("playerctl play-pause", false)
end, {description = "play/pause", group = "media"}),

awful.key({}, "XF86AudioNext", function()
    awful.util.spawn("playerctl next", false)
end, {description = "next track", group = "media"}),

awful.key({}, "XF86AudioPrev", function()
    awful.util.spawn("playerctl previous", false)
end, {description = "previous track", group = "media"})
```

#### 4.2 自定义功能键绑定

```lua
-- 截图功能
awful.key({ modkey }, "Print", function()
    awful.spawn("flameshot gui")
end, {description = "screenshot with flameshot", group = "utils"}),

-- 锁屏
awful.key({ modkey, "Control" }, "l", function()
    awful.spawn("i3lock -n -i " .. beautiful.wallpaper)
end, {description = "lock screen", group = "system"}),

-- 应用程序启动器
awful.key({ modkey }, "s", function()
    awful.spawn("rofi -show-icons -modi windowcd,window,drun -show drun")
end, {description = "application launcher", group = "launcher"}),

-- 文件管理器
awful.key({ modkey }, "e", function()
    awful.spawn(terminal .. " -e ranger")
end, {description = "file manager", group = "launcher"}),

-- 浏览器快速启动
awful.key({ modkey }, "b", function()
    awful.spawn("firefox")
end, {description = "browser", group = "launcher"})
```

#### 4.3 窗口管理增强绑定

```lua
-- 方向键焦点控制
awful.key({ modkey, "Control" }, "Right", function()
    awful.client.focus.bydirection("right")
end, {description = "focus right", group = "client"}),

awful.key({ modkey, "Control" }, "Left", function()
    awful.client.focus.bydirection("left")
end, {description = "focus left", group = "client"}),

awful.key({ modkey, "Control" }, "Up", function()
    awful.client.focus.bydirection("up")
end, {description = "focus up", group = "client"}),

awful.key({ modkey, "Control" }, "Down", function()
    awful.client.focus.bydirection("down")
end, {description = "focus down", group = "client"}),

-- 快速移动窗口到指定屏幕
awful.key({ modkey, "Shift" }, "o", function(c)
    c:move_to_screen()
end, {description = "move to next screen", group = "client"})
```

### 5、窗口规则配置模式

#### 5.1 浮动窗口规则（常见应用）

```lua
ruled.client.append_rule {
    id = "floating",
    rule_any = {
        class = {
            "Arandr", "Blueman-manager", "Gpick", "Kruler", "Sxiv",
            "Tor Browser", "Wpa_gui", "veromix", "xtightvncviewer",
            "Pamac-manager", "Polkit-gnome-authentication-agent-1",
            "Polkit-kde-authentication-agent-1", "Gcr-prompter",
        },
        instance = { "copyq", "pinentry" },
        name = {
            "Event Tester",  -- xev
            "Remmina Remote Desktop Client",
            "win0",
        },
        role = {
            "AlarmWindow",  -- Thunderbird's calendar
            "ConfigManager", -- Thunderbird's about:config
            "pop-up",       -- Chrome Developer Tools
        }
    },
    properties = { floating = true },
    callback = function(c)
        awful.placement.centered(c, nil)
    end
}
```

#### 5.2 应用特定标签分配

```lua
-- Firefox 分配到标签 2
ruled.client.append_rule {
    rule = { class = "Firefox" },
    properties = { tag = screen[1].tags[2] }
}

-- Terminal 分配到标签 1
ruled.client.append_rule {
    rule = { class = terminal_class },  -- 如 "Alacritty", "kitty"
    properties = { tag = screen[1].tags[1] }
}

-- 编辑器分配到标签 3
ruled.client.append_rule {
    rule_any = {
        class = { "Code", "Subl", "Geany", "Gvim" }
    },
    properties = { tag = screen[1].tags[3] }
}
```

#### 5.3 特殊窗口处理

```lua
-- 无边框窗口（如 GLava 可视化）
ruled.client.append_rule {
    rule_any = {
        name = { "GLava" }
    },
    properties = {
        focusable = false,
        ontop = true,
        skip_taskbar = true,
        border_width = 0
    },
    callback = function(c)
        local img = cairo.ImageSurface(cairo.Format.A1, 0, 0)
        c.shape_input = img._native
        img.finish()
    end
}

-- 启动时最大化（特定应用）
ruled.client.append_rule {
    rule_any = {
        class = { "Gimp", "Inkscape", "VirtualBox Machine" }
    },
    properties = { maximized = true }
}
```

### 6、标签与布局高级配置

#### 6.1 每屏幕独立标签配置

```lua
-- 定义每个屏幕的标签和布局
local tags_config = {
    settings = {
        {  -- 屏幕 1
            names = { "web", "term", "code", "media", "chat", "6", "7", "8", "9" },
            layout = {
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.max,
                awful.layout.suit.floating,
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.tile
            }
        },
        {  -- 屏幕 2
            names = { "docs", "sys", "vm", "misc", "5", "6", "7", "8", "9" },
            layout = {
                awful.layout.suit.tile.bottom,
                awful.layout.suit.max,
                awful.layout.suit.floating,
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.tile,
                awful.layout.suit.tile
            }
        }
    }
}

-- 创建标签
awful.screen.connect_for_each_screen(function(s)
    local screen_tags = awful.tag(tags_config.settings[s.index].names, s, tags_config.settings[s.index].layout)
    tags[s] = screen_tags
end)
```

#### 6.2 动态布局切换

```lua
-- 扩展默认布局列表
awful.layout.append_default_layouts({
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
    -- 自定义布局
    lain.layout.centerwork,
    lain.layout.termfair.center,
    -- 第三方布局
    machi.default_layout,
})

-- 快速布局切换快捷键
awful.key({ modkey }, "space", function()
    awful.layout.inc(1)
end, {description = "next layout", group = "layout"}),

awful.key({ modkey, "Shift" }, "space", function()
    awful.layout.inc(-1)
end, {description = "previous layout", group = "layout"}),

-- 直接切换到特定布局
awful.key({ modkey }, "t", function()
    awful.layout.set(awful.layout.suit.tile)
end, {description = "tile layout", group = "layout"}),

awful.key({ modkey }, "f", function()
    awful.layout.set(awful.layout.suit.floating)
end, {description = "floating layout", group = "layout"})
```

### 7、高级功能集成

#### 7.1 Rofi 启动器深度集成

```lua
-- Rofi 应用启动器
awful.key({ modkey }, "r", function()
    awful.spawn("rofi -show drun -show-icons")
end, {description = "application launcher", group = "launcher"}),

-- Rofi 窗口切换器
awful.key({ modkey }, "Tab", function()
    awful.spawn("rofi -show window -show-icons")
end, {description = "window switcher", group = "client"}),

-- Rofi 密码管理器
awful.key({ modkey, "Control" }, "p", function()
    awful.spawn.with_shell("rofi-pass")
end, {description = "password manager", group = "utils"}),

-- Rofi 计算器
awful.key({ modkey, "Shift" }, "c", function()
    awful.spawn("rofi -show calc -modi calc -no-sort")
end, {description = "calculator", group = "utils"}),

-- Rofi 表情符号选择器
awful.key({ modkey, "Shift" }, "e", function()
    awful.spawn("rofi -show emoji -modi emoji")
end, {description = "emoji picker", group = "utils"})
```

#### 7.2 下拉终端（Quake 风格）

```lua
-- 使用 F12 唤出下拉终端
local dropdown_terminal = nil
awful.key({}, "F12", function()
    if dropdown_terminal and dropdown_terminal.valid then
        dropdown_terminal.minimized = not dropdown_terminal.minimized
        if not dropdown_terminal.minimized then
            dropdown_terminal:raise()
            client.focus = dropdown_terminal
        end
    else
        awful.spawn(terminal .. " --class=dropdown", {
            floating = true,
            placement = awful.placement.centered,
            callback = function(c)
                dropdown_terminal = c
                c:geometry({ width = 1200, height = 600 })
                c.sticky = true
                c.ontop = true
                c.skip_taskbar = true
            end
        })
    end
end, {description = "toggle dropdown terminal", group = "launcher"})
```

#### 7.3 仪表板/通知中心

```lua
-- 创建通知中心弹窗
local notification_popup = awful.popup {
    widget = {
        {
            {
                text = "Notifications",
                font = beautiful.font,
                widget = wibox.widget.textbox
            },
            {
                id = "notification_list",
                layout = wibox.layout.fixed.vertical,
                spacing = 5
            },
            layout = wibox.layout.fixed.vertical
        },
        margins = 10,
        widget = wibox.container.margin
    },
    border_width = 2,
    border_color = beautiful.border_focus,
    bg = beautiful.bg_normal .. "CC",  -- 半透明背景
    placement = awful.placement.top_right,
    shape = gears.shape.rounded_rect,
    visible = false
}

-- 切换通知中心
awful.key({ modkey }, "n", function()
    notification_popup.visible = not notification_popup.visible
end, {description = "toggle notification center", group = "awesome"})
```

#### 7.4 壁纸管理

```lua
-- 动态壁纸切换
local wallpapers_dir = os.getenv("HOME") .. "/Pictures/Wallpapers/"
local current_wallpaper_index = 1
local wallpapers = {}

-- 读取壁纸目录
local function load_wallpapers()
    local f = io.popen("find " .. wallpapers_dir .. " -type f \\( -name '*.jpg' -o -name '*.png' -o -name '*.jpeg' \\) | sort")
    if f then
        for filename in f:lines() do
            table.insert(wallpapers, filename)
        end
        f:close()
    end
end

-- 切换壁纸
local function set_next_wallpaper()
    if #wallpapers == 0 then return end
    current_wallpaper_index = (current_wallpaper_index % #wallpapers) + 1
    local wallpaper = wallpapers[current_wallpaper_index]
    
    for s in screen do
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- 绑定快捷键
awful.key({ modkey, "Control" }, "w", function()
    set_next_wallpaper()
end, {description = "next wallpaper", group = "aesthetic"}),

-- 初始加载
load_wallpapers()
if #wallpapers > 0 then
    gears.wallpaper.maximized(wallpapers[1], screen[1], true)
end
```

### 8、配置结构最佳实践

#### 8.1 模块化目录结构

```
~/.config/awesome/
├── rc.lua                    # 主入口文件
├── theme.lua                 # 主题配置
├── keys.lua                  # 按键绑定（分离）
├── rules.lua                 # 窗口规则
├── widgets.lua               # 小部件定义
├── layouts.lua               # 布局配置
├── signals.lua               # 信号处理
│
├── lib/                      # 第三方库
│   ├── lain/                 # lcpz/lain 模块
│   ├── bling/                # BlingCorp/bling 模块
│   ├── rubato.lua            # andOrlando/rubato 动画库
│   └── awesome-wm-widgets/   # 小部件集合
│
├── themes/                   # 主题目录
│   ├── default/              # 默认主题
│   ├── multicolor/           # multicolor 主题
│   └── powerarrow/           # powerarrow 主题
│
└── scripts/                  # 辅助脚本
    ├── volume.sh             # 音量控制
    ├── brightness.sh         # 亮度控制
    └── lockscreen.sh         # 锁屏脚本
```

#### 8.2 主配置文件示例（rc.lua）

```lua
-- 主配置文件：rc.lua
awesome_mode = "api-level=4:screen=on"

-- 加载 LuaRocks 模块
pcall(require, "luarocks.loader")

-- 加载基础库
local gears = require("gears")
local awful = require("awful")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")
local menubar = require("menubar")

-- 加载自定义模块
local keys = require("keys")
local rules = require("rules")
local widgets = require("widgets")
local layouts = require("layouts")

-- 错误处理
naughty.connect_signal("request::display_error", function(message, startup)
    naughty.notification {
        urgency = "critical",
        title = "Awesome Config Error",
        message = message,
        timeout = 0
    }
end)

-- 初始化主题
beautiful.init(gears.filesystem.get_configuration_dir() .. "theme.lua")

-- 设置默认应用
terminal = "alacritty"
editor = os.getenv("EDITOR") or "nvim"
editor_cmd = terminal .. " -e " .. editor

-- 设置修饰键
modkey = "Mod4"

-- 加载布局
require("layouts")

-- 创建标签
awful.screen.connect_for_each_screen(function(s)
    require("tags").setup(s)
end)

-- 加载按键绑定
root.keys(keys.globalkeys)
root.buttons(keys.globalbuttons)

-- 加载窗口规则
ruled.client.connect_signal("request::rules", rules.setup)

-- 创建状态栏
awful.screen.connect_for_each_screen(function(s)
    s.mywibox = widgets.create_wibox(s)
end)

-- 加载信号处理
require("signals")

-- 自动启动应用
awful.spawn.with_shell("~/.config/awesome/scripts/autostart.sh")

-- 打印配置加载完成
naughty.notification {
    title = "AwesomeWM",
    message = "Configuration loaded successfully",
    timeout = 3
}
```

#### 8.3 热重载与调试

```lua
-- 配置热重载快捷键（默认：Mod4 + Ctrl + r）
awful.key({ modkey, "Control" }, "r", awesome.restart,
    {description = "reload awesome", group = "awesome"}),

-- 语法检查（启动时使用）
-- awesome -k  # 检查配置文件语法

-- 调试信息记录
awful.key({ modkey, "Shift" }, "d", function()
    local debug_file = io.open(os.getenv("HOME") .. "/.config/awesome/debug.log", "a")
    if debug_file then
        debug_file:write("=== Debug Info " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===\n")
        debug_file:write("Active clients: " .. #client.get() .. "\n")
        debug_file:write("Active screens: " .. #screen .. "\n")
        debug_file:write("Current layout: " .. awful.layout.getname() .. "\n")
        debug_file:close()
        naughty.notify({ title = "Debug", message = "Debug info saved", timeout = 2 })
    end
end, {description = "save debug info", group = "debug"})
```

### 9、AwesomeWM 4.3+ 新特性利用

#### 9.1 自动 DPI 处理

```lua
-- 启用自动 DPI 处理（注意：会破坏现有配置的像素值）
awful.screen.set_auto_dpi_enabled(true)

-- 或者手动设置屏幕 DPI
screen.connect_signal("request::dpi", function(s)
    -- 根据屏幕尺寸计算 DPI
    local dpi = math.floor(s.geometry.width / (s.geometry.width / 96))
    s.dpi = dpi
end)
```

#### 9.2 改进的 spawn 函数

```lua
-- 单实例启动
awful.spawn.single_instance("firefox", {
    callback = function(c)
        c:move_to_tag(screen[1].tags[2])
    end
})

-- 保证只运行一个实例（跨重启）
awful.spawn.once("discord", {
    restart_callback = function()
        naughty.notify({ title = "Discord", message = "Restarted after awesome reload" })
    end
})

-- 如果已运行则激活，否则启动
awful.spawn.raise_or_spawn("spotify", {
    properties = { tag = screen[1].tags[5] }
})
```

#### 9.3 新的键抓取器 API

```lua
-- 使用新的 keygrabber API（更简洁）
local keygrabber = require("awful.keygrabber")

local function start_app_launcher()
    local grabber = keygrabber.run(function(_, key, event)
        if event == "release" then return end
        
        if key == "Escape" then
            keygrabber.stop(grabber)
        elseif key == "Return" then
            -- 执行启动命令
            keygrabber.stop(grabber)
        end
    end)
end

awful.key({ modkey }, "p", start_app_launcher)
```

#### 9.4 每个标签多布局支持

```lua
-- 为标签设置布局列表（而不是单个布局）
tag.connect_signal("request::default_layouts", function()
    awful.layout.append_default_layouts({
        awful.layout.suit.tile,
        awful.layout.suit.floating,
        awful.layout.suit.max,
        awful.layout.suit.spiral.dwindle,
    })
end)

-- 获取当前布局在列表中的索引
local function get_current_layout_index(t)
    return awful.layout.get_tag_layout_index(t)
end
```

### 10、容器项目中的配置建议

#### 10.1 容器环境特殊配置

```lua
-- 检测是否为容器环境
local function is_container()
    local f = io.open("/proc/1/cgroup", "r")
    if f then
        local content = f:read("*all")
        f:close()
        return content:match("docker") or content:match("lxc") or content:match("kubepods")
    end
    return false
end

-- 容器环境调整
if is_container() then
    -- 调整某些设置以适应容器环境
    beautiful.border_width = 2  -- 更细的边框
    beautiful.useless_gap = 4   -- 适当的间隙
    
    -- 容器中可能不需要某些功能
    -- 如电池监控、亮度控制等
end
```

#### 10.2 资源监控与限制

```lua
-- 容器内资源监控小部件
local container_resources = wibox.widget.textbox()
local resource_timer = gears.timer({
    timeout = 5,
    call_now = true,
    autostart = true,
    callback = function()
        -- 读取容器资源使用
        local mem_f = io.open("/sys/fs/cgroup/memory/memory.usage_in_bytes", "r")
        local cpu_f = io.open("/sys/fs/cgroup/cpu/cpuacct.usage", "r")
        
        local mem_usage = "N/A"
        local cpu_usage = "N/A"
        
        if mem_f then
            mem_usage = tonumber(mem_f:read("*all")) / 1024 / 1024  -- MB
            mem_f:close()
        end
        
        if cpu_f then
            cpu_usage = cpu_f:read("*all")
            cpu_f:close()
        end
        
        container_resources:set_markup(string.format(" 🐳 %.1fMB", mem_usage or 0))
    end
})
```

#### 10.3 配置备份与同步

```lua
-- 容器配置备份功能
local function backup_config()
    local config_dir = gears.filesystem.get_configuration_dir()
    local backup_dir = os.getenv("HOME") .. "/.config/awesome-backup/"
    
    os.execute("mkdir -p " .. backup_dir)
    os.execute("cp -r " .. config_dir .. "* " .. backup_dir)
    
    naughty.notify({
        title = "Config Backup",
        message = "Configuration backed up to " .. backup_dir,
        timeout = 3
    })
end

-- 定期备份
local backup_timer = gears.timer({
    timeout = 3600, -- 每小时备份一次
    autostart = true,
    callback = backup_config
})

awful.key({ modkey, "Control" }, "b", backup_config,
    {description = "backup config", group = "system"})
```


## 二、配置项目特色对比与选型建议

> 背景：对比分析各配置项目的核心特色、功能复杂度、美观度和适用场景，为编程与日常办公提供朴实实用的选型建议。

### 1、配置项目核心特色对比

#### 1.1 模板类项目（适合学习/起点）

| 项目 | 核心特色 | 功能复杂度 | 美观度 | 适用性 |
|------|----------|------------|--------|--------|
| **[sewergweller/modular-awm-default](https://github.com/sewergweller/modular-awm-default)** | **模块化教学模板** - 将默认配置拆分为 `binds/`、`config/`、`ui/` 等目录，代码结构清晰，含个人学习笔记 | ★★☆☆☆ | ★★☆☆☆ | 新手学习、模块化理解 |
| **[lcpz/awesome-copycats](https://github.com/lcpz/awesome-copycats)** | **多主题仓库** - 10+ 主题（blackburn、powerarrow 等），内置快速 MPD/音量快捷键、Quake 下拉终端、邮件/天气通知 | ★★★☆☆ | ★★★★☆ | 主题切换、功能齐全的起点 |
| **[arcolinux/arcolinux-awesome](https://github.com/arcolinux/arcolinux-awesome)** | **发行版官方配置** - 面向 ArcoLinux 用户，包含大量应用规则、F1-F12 功能键绑定、完整桌面集成 | ★★★★☆ | ★★★☆☆ | ArcoLinux 用户、生产环境 |

#### 1.2 个人配置项目（可直接使用）

| 项目 | 核心特色 | 功能复杂度 | 美观度 | 编程办公友好度 |
|------|----------|------------|--------|----------------|
| **[anhsirk0/awesome-config](https://github.com/anhsirk0/awesome-config)** | **极简实用主义** - "no fancy effects, no fancy widgets, not even icons"，68 个主题，Rofi 脚本控制音量/亮度/截图 | ★★★☆☆ | ★★★★☆ | ★★★★★ |
| **[Gwynsav/gwileful](https://github.com/Gwynsav/gwileful)** | **简洁现代** - 基于 [sewergweller/modular-awm-default](https://github.com/sewergweller/modular-awm-default)，focus on clean, simple and fast to use，自定义图标字体 | ★★☆☆☆ | ★★★☆☆ | ★★★★☆ |
| **[raven2cz/awesomewm-config](https://github.com/raven2cz/awesomewm-config)** | **功能丰富现代** - 支持 dashboard、machi 布局、treetile 布局、活动角落、桌面图标 | ★★★★☆ | ★★★★☆ | ★★★☆☆ |
| **[justaguylinux/awesomewm-setup](https://codeberg.org/justaguylinux/awesomewm-setup)** | **GitHub 主题风格** - 模块化配置，GitHub 风格通知，完整的自动启动系统，HiDPI 支持 | ★★★★☆ | ★★★★☆ | ★★★☆☆ |
| **[pablonoya/awesomewm-configuration](https://github.com/pablonoya/awesomewm-configuration)** | **视觉效果导向** - Rubato 动画、视频壁纸、媒体控制与封面颜色提取、Google Calendar 集成 | ★★★★☆ | ★★★★★ | ★★☆☆☆ |

### 2、编程与日常办公需求分析

#### 2.1 核心需求
- **专注性**：减少视觉干扰，高效窗口管理
- **快捷操作**：快速切换应用/窗口/工作区
- **信息展示**：必要系统状态（时间、网络、音量）
- **资源效率**：内存占用低，启动速度快
- **稳定性**：bug 少，不崩溃

#### 2.2 非必要功能（办公环境下）
- **华丽动画**：[andOrlando/rubato](https://github.com/andOrlando/rubato)、[BlingCorp/bling](https://github.com/BlingCorp/bling) 动画效果
- **复杂小部件**：天气、股票、音乐播放器
- **视觉特效**：透明窗口、阴影、模糊
- **壁纸管理**：动态壁纸、视频壁纸
- **主题切换**：频繁更换配色方案

### 3、朴实实用推荐排名

#### 🥇 **第一名：[anhsirk0/awesome-config](https://github.com/anhsirk0/awesome-config)**
**推荐理由**：
- **极简哲学**："无花哨效果、无花哨小部件、甚至无图标"
- **实用功能**：Rofi 脚本控制音量/亮度/截图/WiFi/表情符号
- **主题丰富**：68 个主题（8 modus-themes + 36 ef-themes + 16 doric-themes）
- **高效设计**：无图标、纯文本界面减少视觉负担
- **脚本集成**：亮度/音量精细控制（5%/10%/最大/最小）
- **一致性**：为 Alacritty、Kakoune、Rofi 提供匹配主题

**办公适用度**：★★★★★
- 减少视觉噪音，专注代码/文档
- Rofi 脚本解决日常操作需求
- 主题系统支持长时间使用的护眼配色

#### 🥈 **第二名：[sewergweller/modular-awm-default](https://github.com/sewergweller/modular-awm-default) + 自定义**
**推荐理由**：
- **结构清晰**：模块化目录结构，易于理解和修改
- **学习价值**：包含作者使用经验笔记
- **轻量基础**：接近默认配置，可逐步添加所需功能
- **灵活性高**：可从空白画布开始构建

**办公定制建议**：
1. 使用 [sewergweller/modular-awm-default](https://github.com/sewergweller/modular-awm-default) 作为起点
2. 添加 [streetturtle/awesome-wm-widgets](https://github.com/streetturtle/awesome-wm-widgets) 中必要的系统监控
3. 配置 Rofi 作为应用启动器
4. 选择简洁主题（如 `blackburn` 或 `powerarrow-dark`）

#### 🥉 **第三名：[Gwynsav/gwileful](https://github.com/Gwynsav/gwileful)**
**推荐理由**：
- **简洁现代**：基于模块化配置，clean and simple
- **图标字体**：自定义图标字体，统一视觉风格
- **音频支持**：pactl/playerctl 集成，适合有音频需求的办公环境
- **维护活跃**：作者持续更新

**办公适用度**：★★★★☆
- 简洁不简陋，有一定美观度
- 支持现代音频系统（PipeWire/PulseAudio）
- 代码结构清晰，易于调整

### 4、功能取舍建议表

| 功能类别 | 推荐保留 | 建议去除 | 说明 |
|----------|----------|----------|------|
| **小部件** | 时钟、音量、网络状态 | 天气、股票、音乐播放器 | 办公只需核心系统信息 |
| **布局** | tile、tile.left、max、floating | spiral、fair、magnifier | 编程常用 tile 和 maximized |
| **快捷键** | 窗口管理、工作区切换、应用启动 | 主题切换、壁纸管理、复杂动画 | 专注核心操作效率 |
| **视觉效果** | 简洁边框、适当间隙 | 透明窗口、阴影、模糊、动画 | 减少视觉干扰 |
| **集成** | Rofi、截图工具、锁屏 | 视频壁纸、日历同步、邮件通知 | 办公环境集成必要工具 |

### 5、容器环境特别优化建议

#### 5.1 资源限制适配
```lua
-- 容器中关闭非必要功能
if is_container_environment() then
    -- 关闭动画效果
    beautiful.enable_animations = false
    
    -- 简化小部件
    beautiful.widgets.complexity = "minimal"
    
    -- 减少内存占用
    collectgarbage("collect")
end
```

#### 5.2 实用配置组合（容器推荐）
```lua
-- 基于 sewergweller/modular-awm-default 的办公优化版
-- 1. 基础结构：sewergweller/modular-awm-default 目录结构
-- 2. 主题：ef-trio-dark（anhsirk0 的护眼主题）
-- 3. 小部件：只保留时钟 + 网络状态
-- 4. 快捷键：编程常用快捷键（代码跳转、终端切换）
-- 5. 布局：tile + maximized + floating
-- 6. 启动器：Rofi 极简配置
```

#### 5.3 容器性能优化
- **禁用合成器效果**：容器中不需要 picom 阴影/透明效果
- **简化图标系统**：使用文字标签代替图标，减少资源占用
- **减少自动刷新**：系统监控小部件刷新间隔调至 30-60 秒
- **预加载优化**：仅启动必要服务（如网络、音频）

### 6、最终推荐方案

#### **方案 A：极简高效（最佳办公选择）**
**配置**：[anhsirk0/awesome-config](https://github.com/anhsirk0/awesome-config) + `ef-trio-dark` 主题
**特点**：
- 纯文本界面，零视觉干扰
- Rofi 脚本解决所有日常操作
- 68 个主题可选，支持护眼配色
- 内存占用极低，启动快速

#### **方案 B：学习型定制**
**配置**：[sewergweller/modular-awm-default](https://github.com/sewergweller/modular-awm-default) + 选择性添加功能
**特点**：
- 理解 AwesomeWM 架构的最佳途径
- 可按需添加功能，避免过度复杂
- 适合长期维护和个性化

#### **方案 C：现代实用**
**配置**：[Gwynsav/gwileful](https://github.com/Gwynsav/gwileful) 或 [justaguylinux/awesomewm-setup](https://codeberg.org/justaguylinux/awesomewm-setup)
**特点**：
- 平衡美观与功能
- GitHub 风格或简洁现代设计
- 包含必要办公功能

### 7、配置验证清单

部署前检查：
- [ ] 键盘快捷键符合编程习惯（hjkl 或方向键）
- [ ] 工作区/标签切换流畅
- [ ] 必要应用启动器（Rofi）正常工作
- [ ] 系统监控小部件信息准确
- [ ] 窗口规则符合办公应用需求
- [ ] 多屏幕支持（如果适用）
- [ ] 音频控制正常工作
- [ ] 锁屏功能可用


## 三、tint2 面板模拟方案

> 背景：调研"AwesomeWM 是否有完全模拟 tint2 的现成配置项目"，并给出 wibar 复刻 tint2 任务栏（窗口任务栏 + 右键单击关闭）的完整实现。

### 1、结论：没有"完全模拟 tint2"的现成配置项目

- **不存在专门复刻 tint2 的独立 AwesomeWM 配置项目**。tint2 官方也标注 awesome 存在 EWMH 兼容问题（tint2 issue #385），社区没有往这个方向做。
- **技术障碍**：tint2 是独立的 EWMH dock 面板，依赖标准 NETWM 规范。AwesomeWM 从 3.5 起对第三方面板的 docking 支持就处于 broken 状态（`rc.lua` 需额外代码禁用内置面板 magic，tint2 才会正常摆放）。tint2 在 awesome 下会出现位置错乱、误判桌面数量（`tint2: WM doesn't respect NETWM specs`）等问题。
- **社区方向相反**：Awesome 自带 wibar + 完整 widget 系统，能力覆盖 tint2 的功能。官方/社区的建议一直是"从 tint2 迁移到 wibar"，而不是反向移植。

### 2、替代方案：用 wibar 模拟 tint2 外观

tint2 的典型外观 = 底部面板 + 菜单按钮 + 任务列表 + 系统托盘 + 时钟，这些 wibar 都能做到：

```lua
-- wibar 复刻 tint2 典型布局（底部任务栏风格）
awful.screen.connect_for_each_screen(function(s)
    s.mywibox = awful.wibar {
        position = "bottom",          -- tint2 默认在底部
        screen = s,
        height = 42,                  -- 类似 tint2 的 panel_size
        bg = "#2e3436",               -- 纯色不透明背景，tint2 风格
        -- 可选半透明: bg = "#2e3436EE" + 配合 picom
        widget = {
            layout = wibox.layout.align.horizontal,
            {   -- 左侧：菜单按钮 + 任务列表（tint2 的 PT）
                layout = wibox.layout.fixed.horizontal,
                mylauncher,            -- 应用菜单按钮
                s.mytasklist,          -- 窗口任务列表（tint2 的 tasklist）
            },
            nil,                       -- 中间留空
            {   -- 右侧：系统托盘 + 时钟（tint2 的 ST）
                layout = wibox.layout.fixed.horizontal,
                wibox.widget.systray(), -- tint2 的 system tray
                mytextclock,            -- tint2 的 clock
            },
        },
    }
end)
```

#### 2.1 现成配置项目参考（非 tint2 克隆，但风格接近）

| 项目 | 参考点 |
|------|--------|
| **[lcpz/awesome-copycats](https://github.com/lcpz/awesome-copycats)** (lcpz) | 底部任务栏风格 wibar、系统托盘、任务列表，社区公认的"类任务栏"模板 |
| **[dynamotn/awesomewm-config](https://github.com/dynamotn/awesomewm-config)** | 双面板（top + bottom），bottom 面板可当任务栏用 |
| **[kotbaton/awesomewm-config](https://github.com/kotbaton/awesomewm-config)** | 顶部面板 + gruvbox 主题，菜单按钮 + 托盘 + 时钟结构清晰 |
| **[Sanatana-Linux/nixos-awesomewm](https://github.com/sanatana-linux/nixos-awesomewm)** | hover-reveal 面板 + 系统托盘 + 任务预览，功能最接近"完整任务栏" |

#### 2.2 差异提醒

- tint2 的**多桌面 pager 模式**（Desktop Switcher）在 wibar 里没有现成 widget，需要自行用 taglist 脚本实现
- tint2 的**启动器图标**在 wibar 中就是 launcher widget，可逐项复刻
- tint2 的 `panel_layer = bottom` 行为，wibar 原生就是独立层，无需额外配置

### 3、窗口任务栏 + 右键单击关闭（wibar 完整实现）

"窗口任务栏 + 右键单击关闭"是 wibar 的标准能力，不需要 tint2，直接配置即可：

```lua
-- 1. 任务栏按钮定义（tint2 风格的窗口任务按钮）
local tasklist_buttons = gears.table.join(
    -- 左键：激活窗口（已激活则最小化，模拟 tint2 左键行为）
    awful.button({}, 1, function(c)
        c:activate { context = "tasklist", action = "toggle_minimization" }
    end),
    -- 右键：直接关闭窗口 ← 核心行为
    awful.button({}, 3, function(c)
        c:kill()
    end),
    -- 中键：同样关闭（tint2 中键也是关闭）
    awful.button({}, 2, function(c)
        c:kill()
    end),
    -- 滚轮：切换焦点窗口（tint2 任务栏也有类似交互）
    awful.button({}, 4, function() awful.client.focus.byidx(1) end),
    awful.button({}, 5, function() awful.client.focus.byidx(-1) end)
)

-- 2. 底部 wibar + 任务栏（完全 tint2 布局）
awful.screen.connect_for_each_screen(function(s)
    s.mytasklist = awful.widget.tasklist {
        screen   = s,
        filter   = awful.widget.tasklist.filter.currenttags, -- 只显示当前 tag 的窗口（tint2 单桌面模式）
        buttons  = tasklist_buttons,
        style    = {
            shape = gears.shape.rectangle,
            border_width = 0,
        },
        layout   = wibox.layout.fixed.horizontal,
    }

    s.mywibox = awful.wibar {
        position = "bottom",
        screen   = s,
        height   = 42,
        bg       = "#2e3436",        -- tint2 风格纯色背景
        widget   = {
            layout = wibox.layout.align.horizontal,
            {   -- 左侧：菜单按钮 + 任务列表
                layout = wibox.layout.fixed.horizontal,
                mylauncher,          -- 应用菜单按钮（PT 的 P）
                s.mytasklist,        -- 任务列表（PT 的 T）
            },
            nil,                     -- 中间留空
            {   -- 右侧：系统托盘 + 时钟
                layout = wibox.layout.fixed.horizontal,
                wibox.widget.systray(),
                mytextclock,
            },
        },
    }
end)
```

#### 3.1 如果想要"右键弹菜单（含关闭）"而不是直接关

tint2 默认右键是弹任务菜单（菜单里有关闭项），awesome 也有等价物：

```lua
awful.button({}, 3, function(c)
    awful.menu {
        items = {
            { "关闭", function() c:kill() end },
            { "最小化", function() c:minimize() end },
            { "全屏", function() c.fullscreen = not c.fullscreen end },
            { "浮动", function() awful.client.floating.toggle(c) end },
            { "移动到 tag", awful.menu.clients({...}, { c }) },  -- 仿 tint2 pager 换桌面
        }
    }:show()
end)
```

#### 3.2 现成项目参考

| 项目 | 说明 |
|------|------|
| **[lcpz/awesome-copycats](https://github.com/lcpz/awesome-copycats)** | 自带完整 tasklist_buttons + 底部任务栏模板，只需把右键改为 `c:kill()`（默认是弹 client 菜单） |
| **[seqizz/awesomewm-config](https://github.com/seqizz/awesomewm-config)** | 极简（仅 tile/max 布局 + powerline 状态栏），tasklist 结构简单易改 |

## 四、参考

### 官方资源
- [AwesomeWM 官网](https://awesomewm.org/)
- [API 文档](https://awesomewm.org/apidoc/)
- [FAQ](https://awesomewm.org/apidoc/documentation/90-FAQ.md.html)

### 社区资源
- [AwesomeWM Reddit](https://www.reddit.com/r/awesomewm/)
- [GitHub Awesome 主题](https://github.com/topics/awesomewm)
- [AwesomeWM 模块集合](https://github.com/thomashighbaugh/awesome-awesomewm-modules-widgets-and-libraries)

### 推荐学习路径
1. **新手入门**：从默认配置 `/etc/xdg/awesome/rc.lua` 开始
2. **模块化学习**：使用 [sewergweller/modular-awm-default](https://github.com/sewergweller/modular-awm-default) 模板
3. **小部件添加**：集成 [streetturtle/awesome-wm-widgets](https://github.com/streetturtle/awesome-wm-widgets)
4. **高级功能**：根据需要添加 lcpz/lain、BlingCorp/bling、andOrlando/rubato 等模块
5. **主题定制**：参考 [lcpz/awesome-copycats](https://github.com/lcpz/awesome-copycats) 主题

### 版本兼容性说明
- **优先使用 AwesomeWM 4.3+**：包含自动 DPI、改进的 spawn 函数等新特性
- **关注模块维护状态**：优先选择活跃维护的项目，避免已归档项目
- **测试配置语法**：使用 `awesome -k` 检查配置文件语法

---

**最后更新**：2026-09-20  
**编写目的**：容器桌面项目 AwesomeWM 配置参考  
**适用版本**：AwesomeWM 4.3+  
**文档状态**：活跃维护
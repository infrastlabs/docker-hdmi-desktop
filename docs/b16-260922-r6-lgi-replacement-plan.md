# b16-260922 | R6 施工方案：抛弃 LGI 的手写 C 绑定

> **来源**：docs/b15-260922-code-repo-analysis.md 章节五（LGI 替代候选实测与最小替换边界）
> **定位**：b15 章节五把 R6（抛弃 GI，纯 C 绑定 + Lua）从 120-240 人天修正为 45-95 人天，并判定"可做但不建议"。本文档是 R6 的**可执行施工方案**，不是可行性论证。
> **结论先行**：R6 不是"重写半个 awesome"，是"**写一个 4 层 700-1000 行的 shim + 砍掉 Gio 和 menubar**"。技术风险只集中在 GLib 主循环一处，其余是体力活。细化后成本 **25-40 人天**，低于 b15 的下限估算（GLib/Gio 两项经上游源码实测再次下调，校正过程见 8、）。

---

## 一、R6 施工方案：抛弃 LGI 的手写 C 绑定

### 1、目标与前置事实

#### 1.1 R6 定义

awesome 静态化的障碍是 `lgi → gobject-introspection → dlopen` 这条链。R6 的做法是**不动 awesome 的 X11 C 内核**（它本来就静态友好：纯 Xlib、无 dlopen、无 GI），只把 Lua 侧的 LGI 绑定层替换为手写 C 绑定。

#### 1.2 LGI 真实调用面（上游 commit `0a5e50c` 实测）

```
生产代码活跃调用行（去注释/文档）: 60
涉及文件数                       : 39
引用文件数（含注释）             : 39
```

按 GI 模块统计：

| GI 模块 | 引用 | 用途 | 现状方案 |
|---------|------|------|---------|
| `cairo` | 8+ | 全部绘制 | **oocairo** 官方活跃（25★，2025-08） |
| `Pango` / `PangoCairo` | 4 | 文本渲染 | oopango 停滞 12 年（4★，2014-10） |
| `GLib` | 2 | `gears.timer` 主循环 | **无现成方案**，唯一真空缺 |
| `Gio` / `GioUnix` | 4 | 文件系统 / dbus | **无现成方案** |
| `GdkPixbuf` | 1 | 图片加载 | 单一调用点 |
| `Gtk 3.0` | 4 | 主题变量读取 | pcall 保护，可零成本砍 |

#### 1.3 GLib/Gio 是唯一真空缺

GitHub API 全量搜索 `total_count` 全为 0：`lua glib gio binding` / `lgi replacement glib lua` / `lgol lua` / `awesome wm static glib`。GI 反射的 GLib/Gio Lua 绑定从来只有 LGI 一家，且无人做过静态版。**这就是 R6 必须手写的部分。**

---

### 2、第一原则：shim 收敛，不改 39 个文件

LGI 的 60 行调用散布在 39 个文件，逐文件改是 45-95 人天估算里的隐性浪费。**正确做法是做 API 形状的 shim，把收敛点降到 1 个文件**：

```lua
-- lib/vendor/lgishim.lua  ← 唯一新增的 Lua 文件
local shim = {}
shim.cairo      = require("lgishim_cairo")      -- 包 oocairo
shim.Pango      = require("lgishim_pango")      -- 手写最小绑定（不碰 oopango）
shim.PangoCairo = require("lgishim_pangocairo")
shim.GLib       = require("lgishim_glib")       -- 手写 C 绑定
shim.Gio        = require("lgishim_gio")        -- 手写 C 绑定（极小）
shim.GObject    = setmetatable({}, { __index = function() return nil end })
shim.require    = function() return nil end     -- Gtk 恒 nil
shim.version    = "0.9.2"                       -- 骗过 surface.lua:22 版本检查
return shim
```

然后一把梭替换调用点：

```bash
sed -i 's/require("lgi")/require("lgishim")/g' lib/**/*.lua lib/*.lua
```

改动从"39 个文件要理解"变成"1 个 shim 要实现"。

**真正的工作量不在替换，在 OO ↔ 函数式的 API 形态转换**（见 3.1）。

---

### 3、逐模块改法

#### 3.1 Cairo：0-3 人天，但有个隐蔽坑

用 [awesomeWM/oocairo](https://github.com/awesomeWM/oocairo)（官方，25★，2025-08 活跃，纯 C）。

**坑**：LGI 是冒号调用 `cr:line_to(x, y)`，oocairo 是函数式 `cairo.line_to(cr, x, y)`。shim 必须把 oocairo 的函数表包装成 metatable 驱动的对象方法：

```lua
-- lib/vendor/lgishim_cairo.lua 骨架
local oc = require("oocairo")
local Ctx = {}     Ctx.__index = Ctx
Ctx.__typename = "cairo_t"            -- 关键：类型标识，见下"隐蔽坑"

local Surface = {} Surface.__index = Surface
Surface.__typename = "cairo_surface_t"

-- 把 oocairo 函数名批量挂到 metatable
for _, name in ipairs({
    "line_to", "move_to", "rectangle", "fill", "stroke", "paint",
    "set_source_rgb", "set_source_rgba", "select_font_face", "set_font_size",
    "text_extents", "translate", "scale", "rotate", "save", "restore",
    "arc", "arc_negative", "curve_to", "new_line_to", "close_path",
    "set_operator", "set_line_width", "set_dash", "clip", "rel_move_to"
}) do
    Ctx[name] = function(self, ...) return oc["_" .. name](self, ...) end
end

function Ctx._wrap(cr)    return setmetatable({ _cr = cr }, Ctx) end
function Surface._wrap(s) return setmetatable({ _s = s }, Surface) end
```

约 200-400 行，R6 里最大的一块体力活。

**隐蔽坑**：`lib/gears/surface.lua` 第 35 / 48 / 70 / 109 / 119 行有 **5 处 "lgi cairo surface" 类型判断**（源码注释 `-- Try to convert the argument into an lgi cairo surface.`）。LGI 用 type 名区分对象，shim 必须提供可辨识标识（上面的 `__typename` 字段），否则 `_to_surface` 这类转换函数**静默失败**——不报错，只是画不出图，会浪费 2-3 天排查。

#### 3.2 Pango：10-20 人天，但有更省的绕法

oopango（[awesomeWM/oopango](https://github.com/awesomeWM/oopango)）停滞 12 年（2014-10 最后 push）。现代 pango 1.50+ 的 `PangoFontDescription` API 有变更，整体移植是体力活且要背 12 年的债。

**更省的做法：不要移植 oopango，手写 60 行最小绑定，只实现 awesome 真正调用的函数。** awesome 对 Pango 的需求收敛在"字体描述符解析 + 文本测量"，实际用到 5-8 个 C 函数：

```c
// lib/vendor/lgishim_pango.c —— 只实现 awesome 用到的
pango_font_description_from_string / pango_font_description_free
pango_font_description_get_size / set_size / get_family / get_weight / get_style
pango_layout_new / pango_layout_free / set_font_description / set_text
pango_layout_get_pixel_size
pango_cairo_create_layout / pango_cairo_set_font_and_layout / pango_cairo_show_layout
```

调用点仅 5 处：`lib/beautiful/init.lua`（4 处，字体解析）+ `lib/gears/color.lua`（1 处）。绕开 oopango 的 12 年债，且不需要同步其 API 演进。

#### 3.3 GLib 主循环：3-6 人天（原估 15-30，校正见 8.1）

**关键认知：GLib 主循环在 C 侧，不在 Lua 侧。** `awesome.c:896-897`：

```c
globalconf.loop = g_main_loop_new(NULL, FALSE);
g_main_loop_run(globalconf.loop);
```

`luaa.c:241-242` 同样有 `g_main_loop_new` / `g_main_loop_quit`；`awesome.c:890` 用 `g_main_context_set_poll_func(g_main_context_default(), a_glib_poll)` 把 `xcb_poll_for_event` + `awesome_refresh()` 合并进 GLib poll。**GLib 是整个进程的心跳**（窗口事件、输入、渲染全跑在它上面），但这部分已经通过 `libglib-2.0` 静态链接，**完全不需要绑定**。

Lua 侧的真实调用面只有 3 行（`lib/gears/timer.lua` 第 102 / 104 / 120 行）：

```lua
self.data.source_id = glib.timeout_add(glib.PRIORITY_DEFAULT, timeout_ms, function()
    protected_call(self.emit_signal, self, "timeout")
    return glib.SOURCE_CONTINUE
end)
glib.source_remove(self.data.source_id)
```

`lib/gears/event.lua` 里**零 GLib 调用**。所以需要的 API 只有：

| 类型 | 项 |
|------|-----|
| 函数 | `g_timeout_add`、`g_source_remove` —— **2 个** |
| 常量 | `G_PRIORITY_DEFAULT`、`G_SOURCE_CONTINUE` —— **2 个** |

```c
// lib/vendor/lgishim_glib.c —— 约 50 行
// luaL_Reg: "timeout_add" → g_timeout_add, "source_remove" → g_source_remove
// 常量: PRIORITY_DEFAULT, SOURCE_CONTINUE
// 唯一难点在 closure marshal（见下）
```

**唯一真正的技术难点：closure 生命周期。** 注意 awesome 的 timer 回调**无参数**，靠闭包捕获 `self`：

```lua
glib.timeout_add(glib.PRIORITY_DEFAULT, timeout_ms, function()
    protected_call(self.emit_signal, self, "timeout")   -- self 是闭包变量
```

LGI 用 closure guard 保证**整个闭包**在回调期间不失效。手写方案：closure marshal 成 userdata → `g_source_set_callback_user_data` 持有 → `g_source_set_destroy_notify` 释放。竞态点在 `source_remove` 与正在执行的回调之间。写错症状是**随机段错误，堆栈不指向绑定代码**。

可参考 `trip-zip/somewm` 仓库的 `lgi_closure_guard.c`（10KB）+ `lgi_closure_guard.map`（66B）——思路可借，API 不可照抄（somewm 面向 wlroots 的回调模型）。

**验收标准**：1000 个并发定时器下不泄漏、不重入。

#### 3.4 Gio：2-4 人天（原估"砍到 0-1"，校正见 8.2）

Gio 的 4 处用途逐一定性：

| 位置 | 调用数 | 处理 | 依据 |
|------|-------|------|------|
| `lib/beautiful/init.lua:274` | 1 | 改 `io` 路径操作 | `Gio.File.new_for_path(config):get_parent()`，单行 |
| `lib/gears/filesystem.lua` | 中 | **砍**，改 `io` + `lfs` | 只用 `query_info`×4 / `make_directory_with_parents` / `get_parent` / `query_file_type` / `enumerate_children` |
| `lib/naughty/dbus.lua` | **21** | **砍，但必须打补丁** | 见下"dbus.c 兜不住" |
| `lib/menubar/utils.lua` | 4 | **砍整个 menubar** | 含 `async_enumerate_children` + `gio.Async.start` |

**`dbus.c` 兜不住 `naughty/dbus.lua`。** `dbus.c:24-29` 头注释原文：

```
/** A deprecated low-level D-Bus API **DO NOT USE**.
 * `lgi.GDBus` is always better. This module will eventually be removed.
 * If it ever breaks due to an upstream API change, it wont be fixed.
```

三条硬事实：① 官方标注 **DO NOT USE**、即将删除、坏了不修；② 它 `#include <dbus/dbus.h>`（**libdbus**），而 `naughty/dbus.lua` 用的是 `Gio.DBusConnection`（**GDBus**，在 libgio 里）——**完全不同的两个库**；③ 它只暴露一个 Lua 表 `awesome_dbus_lib[]`（`dbus.c:857`），全仓库实际只有测试在引用。

**砍掉后的真实影响**：

| 项 | 结果 |
|----|------|
| 本地通知（`naughty.notification.new()`） | ✅ 仍工作——wibox 渲染，不经 dbus |
| 外部通知（`notify-send`、外部应用） | ❌ 收不到 |
| 通知 action button 回调 | ❌ 无法回传 |
| `notification.lua:813` | ⚠️ **`require("naughty.dbus")` 直接崩** |

`lib/naughty/notification.lua:813`：`self._private.clients = require("naughty.dbus").get_clients(self)`；`lib/naughty/init.lua:13`：`naughty.dbus = require("naughty.dbus")`。**不是删文件就行，必须打补丁改这两处调用方。**

**隐藏收益**：`libgio-2.0.a` 依赖 `gio-unix-2.0`、`libmount`、`libselinux`、`libsystemd`、`libffi`... **砍掉 Gio 需求，静态链接阶段能直接省掉这一整串依赖**。"Gio 10-20 人天"的真实含义从来不是写绑定，而是搞这条链接链。

#### 3.5 GTK3：0 人天

`lib/beautiful/gtk.lua` 是唯一使用点，已包在 `pcall` 里：

```lua
local _gtk_status, Gtk = pcall(function()
    local lgi = require('lgi')
    return lgi.require('Gtk', '3.0')
end)
if not _gtk_status or not Gtk then
    gears_debug.print_warning("Can't load GTK+3 introspection...")
    return nil
end
```

shim 里 `lgi.require` 恒返回 `nil`，已有的 `print_warning` + `return nil` 路径自然走通，上层调用方全部对 `nil` 有容错。**0 人天，零改动。**

#### 3.6 GdkPixbuf：0-2 人天

仅 `lib/gears/surface.lua:54` 一处：`GdkPixbuf.Pixbuf.new_from_file(_surface)`。

两条路：
1. **写 50 行 C 绑定**直接调 `libgdk_pixbuf-2.0.a`（可静态链接）——推荐
2. 用 `libpng` 直接解 + oocairo image surface 装载——省一个依赖但要写 PNG 解码路径

---

### 4、编译侧要动的 3 处

```
CMakeLists.txt          → required_modules 里的 lgi 依赖，换成 4 个 lua 模块
build-utils/lgi-check.c → 删除（编译期 lgi 版本检查；shim 里 version 已硬编码）
lib/gears/surface.lua:19-22 → 删除 lgi.version 检查块
```

awesome 已迁 CMake（commit `0a5e50c`），`*.c` 在仓库顶层、Lua 在 `lib/`，无 `src/` 子目录。

---

### 5、施工顺序与验收信号

按"可独立验证"排序，每步都有明确的成功信号：

| 天 | 步骤 | 验收信号 |
|----|------|---------|
| 1-2 | shim 骨架 + Gtk stub + 编译侧 3 处 | `make` 通过，awesome 能启动到 crash |
| 2-3 | Cairo shim（oocairo 包装）+ **5 处 surface 类型标识** | `gears.surface` 能输出纯色图 |
| 3-4 | Pango 最小绑定（60 行手写） | `beautiful.font` 能渲染文字 |
| 4-8 | **GLib 绑定**：2 函数 + 2 常量 + closure guard | 1000 定时器压力测试不泄漏、不重入 |
| 8-9 | 砍 Gio 4 处 → `io`/`lfs` + **补丁 `notification.lua:813` 与 `naughty/init.lua:13`** | 主题加载正常，本地通知正常 |
| 9-10 | GdkPixbuf 50 行绑定 | 图片加载正常 |
| 10-16 | 回归：跑 `tests/` 纯 Lua 单测子集 | 无 GI 依赖的测试全绿 |
| 16-26 | 静态链接调试（砍 Gio 后链接链已简化） | 二进制无动态依赖（`ldd` 只剩 libc） |

**总成本 ~25-40 人天**，低于 b15 章节五的 45-95 估算，原因是砍掉 Gio（省 10-20）、绕开 oopango（省 5-15），以及 GLib 经源码实测下调（省 10-20，见 8.1）。

静态链接阶段参照本项目已有方法论（docs/b11 + gitee docker-x11base）：
- libtool 会重排 LDFLAGS，必须用 `-Wl,--start-group` / `-Wl,--end-group` 包住整串库
- Alpine musl 上主动 `--disable` 一批可选功能（参照 openbox 的 7 个 disable）

---

### 6、风险清单

#### 6.1 GLib closure guard（高）

C 回调期间 Lua 对象被 GC，症状是**随机段错误，无堆栈指向绑定代码**。somewm 的 `lgi_closure_guard.c` + `lgi_closure_guard.map` 是现成参考，但 API 不可照抄。

#### 6.2 cairo surface 类型判别（中，但排查成本最高）

`lib/gears/surface.lua` 5 处判断点（第 35/48/70/109/119 行）。shim 的 metatable 必须能被类型检查识别。**写错不报错，只是画不出图**——预计浪费 2-3 天排查。

#### 6.3 测试子集（中）

awesome 的 `tests/` 大量依赖真实 X11 + LGI 的集成测试。静态版大概率只能跑纯 Lua 单测。用 `luatest` 标签过滤出无 GI 依赖的子集，**别指望全绿**。

#### 6.4 单作者押注风险（低，但需注意）

oocairo 虽由 awesomeWM 组织维护，实际贡献者集中。若 2025-08 后再次停滞，Cairo 层需要自维护。

---

### 7、成本汇总与结论

#### 7.1 对比表

| 子项 | b15 估算 | 本文细化 | 差异原因 |
|------|---------|---------|---------|
| Cairo 层 | 0-3 | 0-3 | — |
| Pango 层 | 10-20 | **2-4** | 不移植 oopango，手写 60 行最小绑定 |
| GLib 主循环 | 15-30 | **3-6** | C 侧 GLib 已是进程心跳且已静态；Lua 侧仅 2 函数（见 8.1） |
| Gio | 10-20 | **2-4** | 4 处全砍；原写"C 侧 dbus.c 兜底"是错的（见 8.2） |
| GTK3 | 0 | 0 | pcall 保护 |
| GdkPixbuf | 0-2 | 0-2 | — |
| 测试回归 | 10-20 | 6-8 | 只跑纯 Lua 子集 |
| 静态链接 | 未单列 | 10-20 | 含 LDFLAGS 调优；砍 Gio 后链接链简化 |
| **合计** | **45-95** | **25-40** | 砍 Gio + 绕开 oopango + GLib 实测下调 |

#### 7.2 R6 在路线排序中的位置

```
R1  保留 lgi           :    0      容器默认
R7  换 dwm 静态        :  5-15     ⭐ 性价比最高
R9  换 somewm(Wayland) : 40-80    需接受后端切换
R6  抛弃 GI 纯 C 绑定  : 25-40    本文；保留 Lua 生态的唯一自研路径
R2  换 LuaGObject      : 20-30    仍动态，非静态化
R3  换 lgob            :100-170   归档 15 年
R5  半静态 GI          : 20-30    无实际收益
R4  换 LuaGnome        :120-240   不可行
```

#### 7.3 结论

- R6 细化后 **25-40 人天**（GLib/Gio 经源码实测再次下调，见 8、），结论从 b15 的"可做但不建议"收窄为"**有条件建议**"
- 条件：**Lua 生态 + awesome 配置复用对本项目是刚需**
- 若只为"静态 WM"，R7（dwm，5-15 人天）以 1/4 成本拿到同样收益
- R6 的唯一不可替代价值：**保留 60 行调用点背后的整套 Lua widget/layout 生态**

#### 7.4 与 b15 的关系

| 文档 | 内容 |
|------|------|
| b15 章节五 | R6 人天从 120-240 修正为 45-95（调用面实测） |
| **b16（本文）** | R6 施工方案细化，25-40 人天，可执行到"按天排期"粒度 |

---

### 8、源码实测校正：GLib 与 Gio

> 3.3 / 3.4 的人天与方案在拿到上游 `0a5e50c` 源码后做了实测校正。本节目的是**说明原文那两处错在哪**，以及砍 Gio 的真实代价。

#### 8.1 GLib：绑定面比"5 个函数"小一个量级

**发现 1：GLib 主循环在 C 侧。** `awesome.c:896-897`：

```c
globalconf.loop = g_main_loop_new(NULL, FALSE);
g_main_loop_run(globalconf.loop);
```

`luaa.c:241-242` 同样有 `g_main_loop_new` / `g_main_loop_quit`。`awesome.c:890`：

```c
g_main_context_set_poll_func(g_main_context_default(), a_glib_poll);
```

`a_glib_poll` 内部把 `xcb_poll_for_event` + `awesome_refresh()` 合并进 GLib poll 循环。**GLib 是整个进程的心跳**——窗口事件、输入、渲染全跑在它上面。但这部分已经通过 `libglib-2.0` 静态链接，**不需要任何 Lua 绑定**。

**发现 2：Lua 侧调用面只有 3 行。** `lib/gears/timer.lua` 里 GLib 调用共 3 处（第 102 / 104 / 120 行），`lib/gears/event.lua` 里**零 GLib 调用**。原文"3-4 个函数"是错的：

| 类型 | 实际所需 |
|------|---------|
| 函数 | `g_timeout_add`、`g_source_remove` —— 2 个 |
| 常量 | `G_PRIORITY_DEFAULT`、`G_SOURCE_CONTINUE` —— 2 个 |

原文列的 `source_new` / `source_attach` / `source_destroy` / `idle_add` 在 awesome 生产代码里**一处都没用**。绑定代码从 ~200 行降到 ~50 行，人天从 15-30 降到 **3-6**。

**发现 3：回调靠闭包捕获 `self`，guard 必须覆盖整个闭包。**

```lua
glib.timeout_add(glib.PRIORITY_DEFAULT, timeout_ms, function()
    protected_call(self.emit_signal, self, "timeout")
```

回调函数**无参数**，`self` 是闭包变量。guard 不能只护函数对象本身，必须护住整个闭包捕获的环境。

#### 8.2 Gio：`dbus.c` 兜不住 `naughty/dbus.lua`

原文写"砍掉 `naughty/dbus.lua`，awesome C 内核自带 `dbus.c`（30KB）"——**这条是错的**。`dbus.c:24-29` 头注释原文：

```
/** A deprecated low-level D-Bus API **DO NOT USE**.
 * `lgi.GDBus` is always better. This module will eventually be removed.
 * If it ever breaks due to an upstream API change, it wont be fixed.
```

三条硬事实：
1. 官方标注 **DO NOT USE**、即将删除、坏了不修
2. 它 `#include <dbus/dbus.h>`（**libdbus**）；`naughty/dbus.lua` 用的是 `Gio.DBusConnection`（**GDBus**，在 libgio 里）——**完全不同的两个库**
3. 它只暴露一个 Lua 表 `awesome_dbus_lib[]`（`dbus.c:857`），全仓库实际只有测试在引用（`tests/test-dbus-error.lua`）

**`naughty/dbus.lua` 的 21 处调用不是"几个调用"**，而是一个完整的 DBus service 实现（实现 `org.freedesktop.Notifications` 接口）：`DBusConnection` / `DBusProxy` / `DBusInterfaceInfo` / `DBusMethodInfo` / `bus_own_name` / `GLib.Variant` / `GObject.Closure` / `DBusArgInfo` / `BusType.SESSION` / `DBusCallFlags` / `DBusProxyFlags` / `BusNameOwnerFlags`。

**发现 4：Gio 的真实成本从来不是"写绑定"。** `libgio-2.0.a` 依赖 `gio-unix-2.0`、`libmount`、`libselinux`、`libsystemd`、`libffi`... 原文"Gio 10-20 人天"的实际含义是搞这条链接链，而不是写 API 绑定。所以**砍掉 Gio 有隐藏收益**：静态链接阶段直接省掉这一整串依赖。

#### 8.3 `gears/filesystem.lua` 降级：影响面 10 个文件

`gears/filesystem` 被 10 个文件引用：`naughty/notification.lua`、`naughty/layout/legacy.lua`、`menubar/icon_theme.lua`、`menubar/menu_gen.lua`、`menubar/init.lua`、`menubar/utils.lua`、`wibox/widget/imagebox.lua`、`awful/completion.lua`、`awful/prompt.lua`、`gears/init.lua`。

改 `io.open` 后有两个语义丢失：

**① typed error 丢失**

原代码靠 Gio 的 typed error 判断"目录已存在"：

```lua
if err.domain == Gio.IOErrorEnum and err.code == "EXISTS" then
```

改 `io.open` 后错误变成字符串/nil，**所有 `make_directory` 调用方的"已存在"分支失效**，扩散到上面 10 个文件。

**② 流式枚举器变成一次性缓存**

`filesystem.lua:202`：

```lua
local file_list = Gio.File.new_for_path(path):enumerate_children("standard::*", 0)
```

`enumerate_children` 是**惰性游标**，`io` 无等价物，必须一次性缓存到表。对 `/usr/share/icons` 这类大目录有内存和延迟代价——而 `menubar/icon_theme.lua` 正好枚举图标目录（砍 menubar 则此问题消失）。

#### 8.4 两处"看起来简单但错就全坏"的位置

| 位置 | 代码 | 错的影响 |
|------|------|---------|
| `lib/beautiful/init.lua:274` | `Gio.File.new_for_path(config):get_parent()` | 定位主题目录，**改错 → 主题解析失败 → 整个桌面外观崩**。只有一行，测试最容易漏 |
| `lib/menubar/utils.lua:407` | `gio.Async.start(do_protected_call)(...)` | 菜单扫描是**异步**的；同步化会阻塞主循环导致 UI 卡顿。砍 menubar 则消失 |

#### 8.5 `a_glib_poll` 的 Lua 栈断言（原文未列的隐蔽隐患）

`awesome.c:460-464`：

```c
if (lua_gettop(L) != 0) {
    warn("Something was left on the Lua stack, this is a bug!");
    luaA_dumpstack(L);
    lua_settop(L, 0);
}
```

**每次 GLib poll 都断言 Lua 栈顶为 0。** 手写绑定如果在 C 回调里操作 Lua 栈后没清干净，会踩这个断言——表现为 warn 刷屏 + 随机行为，**而不是崩溃**，比段错误更难定位。LGI 有专门处理，手写要自己保证。

#### 8.6 校正汇总

| 项 | 原文 | 实测 | 依据 |
|----|------|------|------|
| GLib 需绑定 API | 5 个函数 | **2 函数 + 2 常量** | `timer.lua` 仅 3 行调用 |
| GLib 人天 | 15-30 | **3-6** | 绑定代码 200 行 → 50 行 |
| GLib 定位 | "成本主体" | **仅剩 closure guard 一处风险** | 主循环在 C 侧已静态 |
| Gio dbus 兜底 | "C 侧 dbus.c" | ❌ **不成立** | `dbus.c:24` 标注 DO NOT USE；且是 libdbus 非 GDBus |
| 砍 dbus.lua | "省 Gio" | ⚠️ **需补丁 2 处 require** | `notification.lua:813`、`naughty/init.lua:13` |
| Gio 人天 | 10-20 | **2-4** | 真实成本是链接链，砍掉即省依赖树 |
| **R6 合计** | 35-45 | **25-40** | — |

---

### 9、GTK3 降级的真实影响面

> 3.5 判"GTK3 零成本砍掉"。本节展开砍掉后的真实影响面，并纠正一个常见误解：**不会 fallback 到 GTK2**。

#### 9.1 没有 GTK2 fallback

全仓库搜 `Gtk 2` / `GTK2` / `gtk-2`，唯一命中是 `tests/_client.lua:35` 的一句测试注释：

```lua
-- This requires Gtk3, but fails with an obscure message with Gtk2.
```

`lib/beautiful/gtk.lua:74` 是硬编码：

```lua
return lgi.require('Gtk', '3.0')
```

**无版本探测、无 try-GTK2 分支。砍掉 GTK3 = 二进制里彻底没有 GTK，不是降级到 GTK2。**

补充：`CMakeLists.txt` 搜 `gtk` **零命中**——GTK 从来不是构建期依赖，只是运行时通过 lgi `dlopen`。静态版不需要链接任何 GTK 库，**砍掉让二进制更小**。

#### 9.2 WM 本体不用 GTK 主题

| 东西 | 实现 | 依赖 |
|------|------|------|
| 窗口边框 / 标题 / 标签条方块 | `lib/beautiful/theme_assets.lua` 生成 vector assets | `lgi.cairo` |
| 全部渲染 | `gears/surface.lua`、`wibox/*` | cairo |
| **图标主题识别** | `lib/menubar/icon_theme.lua:63-76` 自己遍历文件系统找 `Adwaita`/`gnome`/`hicolor` 的 `index.theme` | `lgi.GLib` |
| naughty 通知 | `lib/naughty/notification.lua` cairo 绘制 | 零 GTK 引用 |
| awful.completion / prompt | — | 零 GTK 引用 |

**图标主题识别不依赖 GTK 的 `IconTheme` API**——它直接扫 `~/.icons` / `/usr/share/icons` 的文件系统结构。这条容易搞错。

#### 9.3 主题识别机制与 GTK 无关

容易混淆：`beautiful.gtk` 听起来像主题系统的一部分，但它不是。

**主题识别机制**是 `beautiful.init(path)` 加载一个 Lua 文件，把 `theme.xxx = yyy` 的赋值挂到 beautiful 表上——**纯 Lua 文件加载 + 表操作，零 GTK**。

证据：`lib/beautiful/init.lua` 搜 `gtk` 只有 4 处：

```
25:  local gtk = require("beautiful.gtk")
30:      gtk = gtk,                                  ← 挂到返回的 table
43:  --- Get GTK+3 theme variables ...                ← 文档
88:  -- @staticfct beautiful.gtk.get_theme_variables  ← 文档注解
```

**没有任何生产代码调用 `gtk.get_theme_variables()`**——它只是作为 `beautiful.gtk` 字段暴露给**用户 rc.lua 手动调用**。

#### 9.4 那 40+ 个 GTK 主题变量到底是什么

一个可选的"跟随系统主题"桥，把 GTK CSS 属性读出来映射成 beautiful 变量：

| 类别 | 数量 | 例子 |
|------|------|------|
| 颜色 | 40 | `bg`/`fg`/`base`/`text`/`selected`/`button`/`header_button`/`menubar`/`osd`/`tooltip` 各一组，加 `error`/`warning`/`success` |
| WM 专属 | 6 | `wm_border_focused/unfocused`、`wm_title_focused/unfocused`、`wm_icons_focused/unfocused` |
| 字体 | 2 | `font_family`、`font_size`（含 `GDK_SCALE` + Xresources DPI + pt-to-px 换算） |
| 圆角 | 2 | `button_border_radius`、`button_border_width` |

#### 9.5 砍掉后的真实影响面

| rc.lua 写法 | 影响 |
|-------------|------|
| `beautiful.init(".../default.lua")` + 显式设颜色/字体 | ✅ **零影响** |
| 手动调 `beautiful.gtk.get_theme_variables()` 跟随系统主题 | ❌ **崩在用户代码** |

第 2 种的崩溃点要说清楚：`gtk.lua` 内部两层 pcall 只保护"加载 Gtk"和"创建 Window"，**函数本身返回 nil**。真正崩的是调用方：

```lua
local vars = beautiful.gtk.get_theme_variables()   -- nil
beautiful.bg_normal = vars.bg_color                 -- 崩：attempt to index nil
```

所以 shim 里让 `lgi.require('Gtk')` 恒返回 nil 是安全的（函数优雅返回 nil），但**用户 rc.lua 必须能处理 nil**。

**结论**：砍掉 GTK3 不会让 awesome 崩，只会让"跟随 GTK 主题"的 rc.lua 崩。

#### 9.6 其他连带影响

**① 字体 DPI 自动适配丢了，但有替代路径**

`gtk.lua` 里的 `GDK_SCALE` + Xresources DPI + pt-to-px 换算逻辑没了，但两条替代不依赖 GTK：

- `lib/beautiful/xresources.lua` 的 `get_dpi()`（读 Xresources 的 `Xft.dpi`）
- `lib/awful/screen/dpi.lua:228` 的 `_get_xft_dpi()`

需 DPI 适配时在 rc.lua 里自己写 `font_size = 默认值 * dpi/96`。

**② menubar 彻底没戏**

`lib/menubar/menu_gen.lua` 依赖 Gtk menubar 协议 + Gio。砍 GTK3 后无法工作——但本文本来就建议砍整个 menubar（Gio 也是它依赖的），两个一起砍正好。

**③ 用户自定义 widget 里用了 `Gtk.*` 的会失效**

这是用户代码，不是 awesome 本体。

#### 9.7 小结：3.5 的"0 人天"成立，但表述需要修正

3.5 原文写"只是不再能读取 GTK 主题颜色变量"。更精确的表述：

| 项 | 结果 |
|----|------|
| WM 本体渲染 | ✅ 零影响 |
| 主题识别（`beautiful.init`） | ✅ 零影响 |
| 图标主题识别（hicolor / Adwaita） | ✅ 零影响 |
| naughty 本地通知 / awful.completion | ✅ 零影响 |
| **rc.lua 主动跟随 GTK 主题** | ❌ 崩在用户代码，需补 nil 保护 |
| **GTK 主题的 DPI 自动换算** | ⚠️ 需改用 `xresources.get_dpi()` |
| menubar | ❌ 连带失效（本来就计划砍） |

对这个项目：容器里大概率没有桌面环境也没有 GTK 主题，这条路径本来就不会走。**砍掉是纯收益，0 人天成立。**

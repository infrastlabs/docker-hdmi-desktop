# b16-260922 | R6 施工方案：抛弃 LGI 的手写 C 绑定

> **来源**：docs/b15-260922-code-repo-analysis.md 章节五（LGI 替代候选实测与最小替换边界）
> **定位**：b15 章节五把 R6（抛弃 GI，纯 C 绑定 + Lua）从 120-240 人天修正为 45-95 人天，并判定"可做但不建议"。本文档是 R6 的**可执行施工方案**，不是可行性论证。
> **结论先行**：R6 不是"重写半个 awesome"，是"**写一个 4 层 700-1000 行的 shim + 砍掉/改造 Gio**"。细化后成本 **38-62 人天**（砍 menubar）或 **47-74 人天**（保留 menubar，见 12、），低于 b15 的下限估算。
>
> **但风险分布极不均匀**：GLib / Gio / menubar 三项已经上游源码实测校定（见 8.1 / 8.2 / 12.1），**Pango 没有**。3.2 原估的"60 行最小绑定 / 2-4 人天"经实测证伪（漏掉 `textbox.lua` 这个最大消费者），已上修为 **15-30**——**但仍是推测值，不是实测值**，且是当前合计里唯一未经验证的主体项。各数字的可信度分级见 7.3。

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
| `Pango` / `PangoCairo` | 4 | 文本渲染 | oopango 停滞 **14 年**（4★，最后 commit 2012-03，见 10.5） |
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

oopango（[awesomeWM/oopango](https://github.com/awesomeWM/oopango)）停滞 **14 年**——最后 commit 是 `2012-03-29`（"Make this work with lua 5.2"），最后 tag `v1.1`（2011-05-18）。仓库 `created_at`/`pushed_at` 都显示 2014-10-21，那是 GitHub mirror 的导入日期，不是活跃度。现代 pango 1.50+ 的 `PangoFontDescription` API 有变更，整体移植是体力活且要背 14 年的债（详见 10.5）。

**更省的做法：不要移植 oopango，手写最小绑定，只实现 awesome 真正调用的函数。**

⚠️ **原稿这里低估了调用面，实测校正见下**。原文写"调用点仅 5 处：`lib/beautiful/init.lua`（4 处，字体解析）+ `lib/gears/color.lua`（1 处）"、"实际用到 5-8 个 C 函数"——**两者都错，差了一个量级**（同类错误已在 8.1 的 GLib、12.1 的 menubar 上各犯过一次）。

**实测调用面（`lib/` 全目录，排除 spec/tests/docs）**：

| 文件 | 引用数 | 角色 |
|------|-------|------|
| `lib/wibox/widget/textbox.lua` | **27** | **富文本渲染主消费者——原文完全漏掉** |
| `lib/beautiful/init.lua` | 16（原文写 4） | 字体解析、字体高度测量 |
| `lib/gears/color.lua` | 9（原文写 1） | `Pango.Color.parse` 颜色解析 |
| `lib/awful/util.lua` | 5 | 文本测量 |
| `lib/awful/hotkeys_popup/widget.lua` | 4 | |
| `lib/naughty/layout/legacy.lua` | 3 | 通知文本 |
| `lib/naughty/notification.lua` | 2 | 通知文本 |
| `lib/naughty/widget/_markup.lua` | 2 | markup 支持 |

**8 个文件，不是 2 个**。Pango API 实测约 **25 个入口**（不是 5-8）：

```
Pango 静态   : units_from_double, parse_markup, Layout.new, FontDescription.from_string,
               FontDescription.merge, FontDescription.get_size, Color(), Color.parse,
               SCALE, FontDescription.set_ellipsize/wrap/alignment 相关枚举
Layout 方法  : context_changed, get_pixel_extents, set/get_ellipsize, set/get_wrap,
               set/get_alignment, set/get_justify, set/get_indent, set/get_line_spacing,
               set_font_description, set_text, 字段 text/attributes/width/height
PangoCairo   : font_map_get_default, create_context, set_resolution, get_metrics
               (get_ascent/get_descent), get_font_description, 以及 cairo 回调
```

另外 `cairo.Context` 有 **28 个方法、约 450 处调用**（`cr:line_to` × 83、`cr:set_source` × 60、`cr:translate` × 51、`cr:rectangle` × 38……），分散在 10 个文件。这部分 3.1 已单列，不重复计入。

**为什么漏掉 textbox 影响这么大**：`textbox.lua:513-554` 是真正的富文本渲染路径——

```lua
ret._private.ctx = PangoCairo.font_map_get_default():create_context()
ret._private.layout = Pango.Layout.new(ret._private.ctx)
ret._private.layout:set_font_description(beautiful.get_font(font))
local attr, parsed = Pango.parse_markup(text, -1, 0)   -- markup → AttrList
playout.attributes, playout.text = attr, parsed
local _, logical = playout:get_pixel_extents()
```

这条路径需要 `PangoFontContext` + `PangoFontMetrics` 真实对象、`pango_cairo_update_layout` 前置、AttrList 构造、以及 ellipsize/wrap/justify/indent 的枚举映射。原文列的"5-8 个 C 函数"只覆盖了字体解析，**覆盖不了文本测量和富文本排版**。

**校正后的估计**：最小可编译（markup/ellipsize 降级、抛 warning）约 **8-15 人天**；保真实现约 **15-30 人天**。原文"60 行最小绑定 / 2-4 人天"作废——按 25 个入口 × 每个约 10-15 行 C 胶水（类型检查 + 参数转换 + 返回值转换 + 错误处理）算，光骨架就 250-400 行。

**这也解释了 7.1 与 12.4 的表内矛盾**：7.1 写 Pango `2-4`，12.4 写 `15-30`。以实测为准应统一为 **15-30**（见下）。

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
| `lib/menubar/utils.lua` | 4 | **砍 menubar** 或 **改造为同步**（见 12） | `async_*` 可换同步版，`gio.Async.start` 包装可整个删掉 |

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

shim 里 `lgi.require` 恒返回 `nil`，`gtk.lua` 内部两层 pcall 走 `print_warning` + `return nil` 路径，**函数优雅返回 nil，awesome 本体不崩**。

⚠️ 但这不等于"上层调用方全部对 nil 有容错"。`gtk.get_theme_variables()` 返回的 nil 只在**用户 rc.lua 主动跟随 GTK 主题**时被用到，此时崩点是用户代码里 `vars.bg_color` 索引 nil；另有 DPI 自动换算丢失等影响——**精确影响面详见 9、**。（注：menubar **不**属于此列，它零 GTK 依赖，见 11.3）

**0 人天，零改动。**

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
| **3-18** | **Pango 绑定（约 25 个 API，15 天）** | `textbox` 能渲染带 markup 的富文本、ellipsize 生效、`beautiful.font` 高度正确 |
| 18-22 | **GLib 绑定**：2 函数 + 2 常量 + closure guard | 1000 定时器压力测试不泄漏、不重入 |
| 22-26 | 砍 Gio 4 处 → `io`/`lfs` + **补丁 `notification.lua:813` 与 `naughty/init.lua:13`** | 主题加载正常，本地通知正常 |
| 26-27 | GdkPixbuf 50 行绑定 | 图片加载正常 |
| 27-33 | 静态链接调试（砍 Gio 后链接链已简化；保留 menubar 则需静态化 libgio 依赖链，见 12） | 二进制无动态依赖（`ldd` 只剩 libc） |
| 33-40 | 回归：跑 `spec/` + `tests/` 纯 Lua 单测子集 | 无 GI 依赖的测试全绿 |

> **原排期把 Pango 压在 1 天（`| 3-4 |`）是基于 3.2 已证伪的"60 行最小绑定"假设。按实测的约 25 个 API 重排后，Pango 是全程最长的单项，整条排期后移约 12 天。**

**总成本 ~38-62 人天**（砍 menubar 方案），低于 b15 章节五的 45-95 估算，原因是砍掉 Gio（省 10-20）以及 GLib 经源码实测下调（省 10-20，见 8.1）。**若保留 menubar 则升至 47-74 人天**（见 12、）。

⚠️ **这个合计里 Pango 的 15-30 是唯一未实测的主体项**（见 3.2 / 7.3），合计区间的可信度主要取决于它。

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
| Pango 层 | 10-20 | **15-30** | ⚠️ 原估 2-4 已证伪（见 3.2）：实测 8 个文件 / 约 25 个 API，漏掉 `textbox.lua`；**仍为推测值，非实测** |
| GLib 主循环 | 15-30 | **3-6** / **4-8** | C 侧已静态；Lua 侧 2 函数；保留 menubar 需补 6 个 GLib 函数（见 12.1） |
| Gio | 10-20 | **2-4** / **8-15** | 砍 menubar 则 4 处全砍；保留则需同步 shim + fork（见 12）；原写"C 侧 dbus.c 兜底"是错的（见 8.2） |
| GTK3 | 0 | 0 | pcall 保护 |
| GdkPixbuf | 0-2 | 0-2 | — |
| 测试回归 | 10-20 | 6-8 | 只跑纯 Lua 子集 |
| 静态链接 | 未单列 | 10-20 / **6-12** | 砍 menubar 则链接链简化；保留则需静态化 libgio 依赖链——**已有 `v-pcmanfm` 落地先例，见 12.3** |
| **合计** | **45-95** | **38-62** / **47-74** | 砍 menubar / 保留 menubar（见 12）；绕开 oopango + GLib 实测下调 |

#### 7.2 R6 在路线排序中的位置

```
R1  保留 lgi           :    0      容器默认
R7  换 dwm 静态        :  5-15     ⭐ 性价比最高
R9  换 somewm(Wayland) : 40-80    需接受后端切换
R6  抛弃 GI 纯 C 绑定  : 38-62    本文；保留 Lua 生态的唯一自研路径
R2  换 LuaGObject      : 20-30    仍动态，非静态化
R3  换 lgob            :100-170   归档 15 年
R5  半静态 GI          : 20-30    无实际收益
R4  换 LuaGnome        :120-240   不可行
```

#### 7.3 结论

- R6 细化后 **38-62 人天**（砍 menubar）或 **47-74 人天**（保留 menubar，见 12、）；GLib/Gio 经源码实测再次下调（见 8、）。结论从 b15 的"可做但不建议"收窄为"**有条件建议**"
- 条件：**Lua 生态 + awesome 配置复用对本项目是刚需**
- 若只为"静态 WM"，R7（dwm，5-15 人天）以 1/4 成本拿到同样收益
- R6 的唯一不可替代价值：**保留 60 行调用点背后的整套 Lua widget/layout 生态**

 **各数字的可信度分级**（决定合计区间该信几成）：

 | 等级 | 项 | 依据 |
 |------|-----|------|
 | ✅ 上游源码实测 | GLib 3-6、Gio 2-4、menubar Gio 8-15、零 D-Bus、libgio 静态链 | 8.1 / 8.2 / 12.1 / 12.3，均可复现 grep 或 `ldd` |
 | ✅ 本项目已落地 | libgio 依赖链静态化 | `v-pcmanfm` 37.1M 全静态产物 |
 | ⚠️ **推测值，未实测** | **Pango 15-30** | 只有调用面枚举（3.2），没有绑定实现样本 |
 | ⚠️ 推测值 | Cairo 0-3、GdkPixbuf 0-2、测试回归 6-8、静态链接 10-20/6-12 | 数量级判断 |

 合计 38-62 的下界主要由 Pango 支撑，**在 Pango 实测校定前，不要把 38-62 当成承诺值**。校定方法见文末"待办"。

#### 7.4 与 b15 的关系

| 文档 | 内容 |
|------|------|
| b15 章节五 | R6 人天从 120-240 修正为 45-95（调用面实测） |
| **b16（本文）** | R6 施工方案细化，38-62 / 47-74 人天，可执行到"按天排期"粒度 |

---

### 8、源码实测校正：GLib 与 Gio

> **提问原文**：
> 最小替换集：cairo + Pango + GLib + Gio 四模块，外加砍掉 GTK3。真正没现成方案的是 GLib 主循环 和 Gio——这两个加起来是 R6 的成本主体。两个当前细节是怎么处理的？降级有哪些影响？会有什么隐患？
>
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
| **Pango 调用面** | **2 个文件 / 5 处 / 5-8 个 C 函数** | ❌ **8 个文件 / 约 25 个 API** | `lib/` 全目录 grep；**漏掉 `textbox.lua`（27 处引用，富文本主路径）** |
| Pango 人天 | 10-20 → "更省的 2-4" | **上修至 15-30** | 3.2；与 10.7 的 15-30 对齐，消除 7.1 / 12.4 表内矛盾 |
| 同步化 menubar | "无真正并发，可直接同步" | ⚠️ **会卡 UI** | `async_*` 每调用 `coroutine.yield` 让出主循环；见 12.2 |
| libgio 静态链 | "硬门槛，需实测" | ✅ **已落地** | `v-pcmanfm` 37.1M 全静态 + 零 D-Bus |
| **R6 合计** | 35-45 → 25-40 | **38-62**（Pango 上修 +13） | — |

---

### 9、GTK3 降级的真实影响面

> **提问原文**：
> gtk3降级砍掉。也就是说静态版 awesome 里砍掉 GTK3 不会崩，只是不再能读取 GTK 主题颜色变量——这是一个可接受的降级。这个砍掉之后，会用gtk2? 有没其他的什么影响？
>
> **追问原文**：主题的识别还能用吗？本身窗口管理器应该用不到gtk主题吧？
>
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

**② menubar 不受影响（原文曾误判为"彻底没戏"）**

原判断"`lib/menubar/menu_gen.lua` 依赖 Gtk menubar 协议"是**错的**——grep `Gtk\|gtk` 全 `lib/menubar/` 目录**零命中**，menubar 零 GTK 依赖。它靠 Gio 扫 `.desktop` 文件 + 自己遍历文件系统找图标。

**砍 GTK3 后 menubar 仍能工作**。它真正的问题是 Gio（`utils.lua:17` 的 `lgi.Gio` + `gio.Async.start` 异步扫描），砍 Gio 时才需要砍 menubar。详见 11.3。

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
| menubar | ✅ **不受影响**（零 GTK 依赖，原文误判，见 11.3） |

对这个项目：容器里大概率没有桌面环境也没有 GTK 主题，这条路径本来就不会走。**砍掉是纯收益，0 人天成立。**

---

### 10、四模块替换源与 LGI 引入历史

> **提问原文**：
> 最小替换集：cairo + Pango + GLib + Gio 四模块，四个具体是怎么替换的？用的awesomewm官方的另外两个仓库吗？官方什么时候 哪个版本开始用lgi的，官方的那两个仓库对应最新版本还靠谱可用吗？
>
> 本节回答四问，并纠正两个之前的记录偏差：**LGI 引入点是 v3.5 不是 v4.0**；**oopango 停滞 14 年不是 12 年**。

#### 10.1 四模块替换源对照

| 模块 | 替换源 | API 形态差异 |
|------|--------|-------------|
| **cairo** | `awesomeWM/oocairo` | LGI 是 OO 调用（`cr:line_to(x,y)`），oocairo 是函数式（`cairo.line_to(cr,x,y)`）→ shim 要做形态适配 |
| **Pango** | `awesomeWM/oopango` | 同上，OO ↔ 函数式 |
| **GLib** | **无现成方案，手写** | 无等价库（见 8.1） |
| **Gio** | **全砍**，改 `io.open` + C 侧 `dbus.c` | 无等价替换（见 8.2） |

GLib 全仓库生产代码仅 3 行调用：`glib.timeout_add` / `glib.SOURCE_CONTINUE` / `glib.source_remove`，即 2 函数 + 2 常量。

Gio 4 处调用：`gears/filesystem.lua`、`naughty/dbus.lua`、`menubar/utils.lua`、`menubar/icon_theme.lua`。两个坑：`Gio.IOErrorEnum` 的 typed error 在 `io` 无等价物；`enumerate_children` 是惰性游标，`io` 无等价物需一次性缓存。

#### 10.2 官方两个仓库：是，但 awesome 本体已零引用

`awesomeWM` 组织名下：

| 仓库 | 最新版本 | 最后 commit | forks |
|------|---------|------------|-------|
| `awesomeWM/oocairo` | **v1.5** | 2025-08-10 | 10 |
| `awesomeWM/oopango` | **v1.1** | **2012-03-29** | 2 |

**关键澄清：awesome 本体已零引用这两个库**。grep 全仓库 `oocairo\|oopango\|oox11` **零命中**。它们是 LGI 引入后的遗留库，组织仍维护，但不是 awesome 的当前实现。

#### 10.3 LGI 引入点是 v3.5，不是 v4.0

证据链：

| 版本 | cairo 来源 | 证据 |
|------|-----------|------|
| **v2.3.6** | 直接链接 pangocairo | `configure.ac`: `PKG_CHECK_MODULES([pangocairo], [pangocairo])` |
| **v3.4.15** | **零 cairo 引用** | `lib/naughty.lua.in`（22371 字节）grep `cairo` 命中 **0 次**；用 `image = image`（C 侧 image 对象） |
| **v3.5.9** | **LGI** | `CMakeLists.txt`: `# check for lgi and the needed gobject introspection files` + `lgi-check` target；`naughty.lua.in`: `local cairo = require("lgi").cairo` |
| **v4.0**（2016-12-25） | LGI 全面铺开 | `lib/beautiful/init.lua`: `require("lgi")` |

版本线：**v1.0 → v2.3.6**（手写绑定 + 直接链接 pangocairo）→ **v3.5**（LGI 引入）→ **v4.0**（2016-12-25，LGI 全面铺开）。

awesome release 日期（GitHub API 实测）：v4.0 2016-12-25、v4.1 2017-03-18、v4.2 2017-07-15、v4.3 2019-01-28。

**R6 本质上是回到 v3.4 之前的架构**，但比那时更好——GLib 主循环早就在 C 侧了。

#### 10.4 oocairo v1.5：相对靠谱

- 2025-08-10 还有 bugfix（tflori 的 PR #14，"return nothing in a void function"）
- 依赖声明干净：`PKG_CHECK_MODULES([DEPS], [$LUA_NAME cairo])`
- ⚠️ 2019-12 → 2025-08 之间有 **6 年空档**，靠零星 PR 维持
- ⚠️ **0 个 GitHub release，无 LuaRocks 包**，需自己编译
- ⚠️ 10 forks，社区小

结论：**可用，但需要自己维护编译链**。

#### 10.5 oopango v1.1：R6 的真正风险点

- 最后 commit **2012-03-29**（"Make this work with lua 5.2"），**停滞 14 年**
- 最后 tag **v1.1**（2011-05-18），2 forks，无人接手
- ⚠️ **现代 pango（1.50+）的 `PangoFontDescription` API 有变更**，v1.1 无法直接编译工作

**之前记录"停滞 12 年"是错的**：仓库 `created_at`/`pushed_at` 都是 2014-10-21，那是 GitHub mirror 的导入日期，被误当成活跃度。实际最后 commit 早 2.5 年。

#### 10.6 Pango 层只剩两条路

候选清单里没有活着的官方方案，只剩：

| 方案 | 代价 | 结论 |
|------|------|------|
| 自己移植 oopango v1.1 到现代 pango | FontDescription API 逐处改 | 体力活，14 年债自己背 |
| **降级到 cairo toy text API** | 放弃文字 shaping | ❌ 实质降级 |

toy text API（`select_font_face` / `show_text`）覆盖不了 `PangoFontDescription` 解析 `"sans 10"` 这类字符串，awesome 的 `wibox` 文字渲染和字体解析会出问题。中文/复杂文字排版更是直接失效。

**对比**：
- ✅ cairo 层：有活的官方库（2025 还在修）
- ❌ Pango 层：**没有可用方案**，只有死库或降级

#### 10.7 小结

| 问 | 答 |
|----|-----|
| 四模块怎么换 | cairo→oocairo、Pango→oopango、GLib→手写 2 函数、Gio→全砍 |
| 是官方两个仓库吗 | 是（oocairo / oopango），但 awesome 本体已零引用 |
| LGI 从哪个版本开始 | **v3.5**（不是 v4.0），v4.0 是 2016-12-25 全面铺开 |
| 两个仓库靠谱吗 | oocairo v1.5 相对靠谱；**oopango v1.1 不靠谱（停滞 14 年）** |

**对 R6 成本的影响**：3.2 节估的 Pango "10-20 人天"是**下限**。因为 oopango v1.1 无法直接编译到现代 pango，需要移植，实际可能是 **15-30 人天**——甚至可能超过 GLib 的 3-6 人天成为新的成本主体。

---

### 11、menubar 到底是什么，砍掉会缺什么

> **提问原文**：
> menubar介绍下是啥 是主桌面右键菜单还是顶部panel？ 砍掉它有什么影响与风险，哪些功能会缺失？
>
> 本节澄清一个概念误区，并**修正 9.6 节的错误判断**：menubar 零 GTK 依赖，砍 GTK3 不影响它。

#### 11.1 menubar 是什么

官方定义（`docs/05-awesomerc.md.lua:30`）：**"XDG (application) menu implementation"**
模块头（`lib/menubar/init.lua:2`）："a freedesktop menu alternative"

数据来源：扫 `~/.local/share/applications/*.desktop` + `/usr/share/applications/*.desktop`（`menu_gen.all_menu_dirs`，`menu_gen.lua:22-30`）。

**它是一个独立的启动器 popup，既不是桌面右键菜单也不是顶部 panel**：

| 概念 | 是什么 | 怎么触发 |
|------|--------|---------|
| 桌面右键菜单 | 用户在 `root.keys` 里自己绑一个 `awful.menu` | 用户在 rc.lua 手写 |
| 顶部 panel | 用户自己创建的 `wibox`，可放任意 widget | 常驻屏幕顶部 |
| **`menubar`** | **独立启动器 popup**：应用列表 + 分类导航 + 搜索框 + 翻页 | 默认 `Super+P` |

`menubar.show(scr)` 自建 `wibox{ ontop = true }`（`init.lua:485`），内嵌 `awful.widget.prompt()` 搜索框。**不是可嵌入 widget**，是全屏 popup，`Escape` 退出。

命名有误导性——叫 "menubar" 但实际不是"菜单条"，是"应用启动器"。

键盘导航（`init.lua:7-27`）：`Left`/`Right`/`C-j`/`C-k` 选条目、`Backspace` 退出分类、`Escape` 退出、`Home`/`End` 首末、`Return` 执行、`C-Return` 用 `awful.spawn`、`C-M-Return` 终端执行。

#### 11.2 API 全表

`init.lua` 导出：

| 项 | 说明 |
|----|------|
| `show(scr)` / `hide()` / `refresh(scr)` / `get(scr)` | 显示/隐藏/刷新/获取 |
| `cache_entries = true` | 是否缓存条目 |
| `show_categories = true` | 是否显示分类 |
| `match_empty = true` | 空查询时是否匹配 |
| `geometry` | 几何参数 |
| `right_margin` / `right_label`(`▶▶`) / `left_label`(`◀◀`) | 翻页标记 |
| `prompt_args` | 搜索框参数 |
| 子模块 `menu_gen` / `utils` | 菜单生成 / 工具 |

`utils` 导出（`utils.lua`）：`terminal`（默认 `'xterm'`）、`wm_name`、`rtrim`、`lookup_icon_uncached`、`lookup_icon`、**`parse_desktop_file`**、`parse_dir`、`compute_textbox_width`、`compute_text_width`。

#### 11.3 依赖：零 GTK（修正 9.6 的判断）

| 依赖 | 实际 |
|------|------|
| **Gtk** | **零依赖**——grep `Gtk\|gtk` 全 `lib/menubar/` 目录**零命中** |
| **Gio** | 仅 `utils.lua:17`（`lgi.Gio`）+ 经 `gears.filesystem` 间接 |
| **GLib** | `utils.lua:18` + `icon_theme.lua:15` |
| 图标主题 | `index_theme.lua` / `icon_theme.lua` **自己遍历文件系统**，不用 `Gtk.IconTheme` |

**结论：砍 GTK3 后 menubar 仍能工作**。9.6 原文"`menu_gen.lua` 依赖 Gtk menubar 协议"是错的。

menubar 真正卡在 Gio 上：`menu_gen.generate` 是异步的（NEWS:1281 "now asynchronous and needs a callback"），`utils.parse_dir` 用 `gio.Async.start` + `async_enumerate_children` 回调。砍 Gio 只能改同步，**大目录下会阻塞主循环**。

#### 11.4 砍掉的改动面：3 行

全仓库生产代码只有 `awesomerc.lua` 一处 `require("menubar")`，其余全是测试：

```lua
19:        local menubar = require("menubar")
77:        menubar.utils.terminal = terminal
252-253:   awful.key({ modkey }, "p", function() menubar.show() end,
                       {description = "show the menubar", group = "launcher"})
```

**改动成本接近 0**。

#### 11.5 缺失的功能

| 功能 | 替代方案 |
|------|---------|
| `Super+P` 应用菜单启动器（分类 + 搜索 + 键盘导航 + 翻页） | `awful.menu` + 手写菜单项——能用但不读 `.desktop`，要手动维护 |
| **`.desktop` 文件解析** | ❌ **无替代** |
| XDG 图标查找（`lookup_icon` / `find_icon_path`） | 无直接替代，需自己扫文件系统 |
| prompt 搜索框联动菜单 | `modkey+r` 的 `promptbox`（`awesomerc.lua:250`）可代替命令行部分 |

**第 2 项是最实质损失**：`awful/menu.lua` grep `desktop\|xdg\|applications\|parse` **零命中**，它只是通用菜单容器，不做应用菜单解析。而且 awesome **没有 `awful.application_menu`**（只有 `lib/awful/menu.lua`）。砍掉 menubar 等于放弃"从系统读应用列表"的能力。

#### 11.6 两个隐患

1. **`naughty` 里有注释掉的代码引用它**（`naughty/core.lua:620/654/655`：`menubar.utils.lookup_icon(hints.id)`）——上游曾计划用 menubar 的图标查找给通知配图标。用户 rc.lua 若照抄这类代码，砍掉会崩。
2. **砍 Gio 后无法同步化改造**：`parse_dir` 的异步回调结构改同步会阻塞主循环，`~/.local/share/applications` 条目多时启动卡顿明显。

#### 11.7 小结

| 问 | 答 |
|----|-----|
| 是右键菜单还是 panel | **都不是**，是独立启动器 popup（默认 `Super+P`） |
| 依赖什么 | **零 GTK**、Gio（仅 `utils.lua`）、GLib、自己遍历文件系统找图标 |
| 砍 GTK3 影响它吗 | ❌ **不影响**（9.6 原文误判，已修正） |
| 砍掉改动面 | `awesomerc.lua` 3 行 |
| 实质缺失 | `.desktop` 解析能力（无替代）+ 应用启动器 |
| 对本项目 | 容器里 `~/.local/share/applications/` 大概率空，这功能用不上 |

**砍 menubar 的真正理由是它卡 Gio，不是它卡 GTK。**

---

### 12、保留 menubar：技术可行性与成本变化

> **决策**：menubar 应用启动器倾向于保留。
>
> 这一决策让 R6 的 Gio 项从"全砍"变为"改造"，成本从 38-62 人天升到 **47-74 人天**。但关键发现是：**保留 menubar 不需要保留 LGI**——只要一个同步 Gio shim，因为 `parse_dir` 的 async 包装可以整个去掉。

#### 12.1 menubar 的 Gio 真实调用面

对 `lib/menubar/` 全目录（5 个 `.lua`）做词边界 grep，结果如下。

**gio 直接调用面（全部在 `utils.lua`）**：

| 行号 | 调用 | 类型 |
|------|------|------|
| 370 | `gio.FILE_ATTRIBUTE_STANDARD_NAME` / `FILE_ATTRIBUTE_STANDARD_TYPE` | 字符串常量 |
| 371 | `gio.FileQueryInfoFlags.NONE` | 整数常量 |
| 371 | `file:async_enumerate_children(query, flags)` | 异步方法 |
| 378 | `enum:async_next_files(n)` | 异步方法 |
| 384 | `info:get_file_type()` | 同步方法 |
| 385 | `enum:get_child(info)` | 同步方法 |
| 365 | `file:get_path()` / `file:get_uri()` | 同步方法 |
| 404 | `enum:async_close()` | 异步方法 |
| 407 | `gio.Async.start(do_protected_call)(...)` | 异步启动 |
| 409 | `gio.File.new_for_path(dir_path)` | 构造 |

**GLib 调用面（6 个函数，分布在 2 个文件）**：

| 文件 | 函数 |
|------|------|
| `icon_theme.lua` | `build_filenamev` / `get_home_dir` / `get_user_data_dir` / `get_system_data_dirs` |
| `utils.lua` | 上述 4 个 + `KeyFile()` / `KeyFileFlags.NONE` |

`KeyFile` 在 `utils.lua:269-270`，用来解析 `.desktop` 文件的 `[Desktop Entry]` 段。**它是 `libglib-2.0` 的一部分（`glib/gkeyfile.h`），不是 gio，也不是 D-Bus**——纯 INI 解析器，静态化无额外负担。（原稿写"4 个函数"漏了这两个，实为 6 个。）

间接依赖：`menubar/init.lua` 用 `gears.filesystem.get_cache_dir()` × 3 处（174、190、528 行）。

**两个收敛结论**：

1. **Gio 需求收敛在 `utils.parse_dir` 一个函数里**，其余 4 个 menubar 文件零 gio 调用。
2. **全模块零 D-Bus**：对 `lib/menubar/` grep `gdbus|dbusconn|GDBus|application_id|GApplication|GSettings` → **零命中**。这条很关键——它意味着静态链接 `libgio-2.0.a` 时**不会拉进 `gdbus*.o`**，见 12.3。

补充：`gio.*` / `glib.*` 这两个全局表**不是 awesome C 代码注册的**（全仓 grep 无 `"gio"`/`"glib"` 注册点），而是 LGI 的 GLib GIR 绑定注入的——`build-utils/lgi-check.c:39` 有 `assert(lgi.cairo, lgi.Pango, lgi.PangoCairo, lgi.GLib, lgi.Gio, lgi.GdkPixbuf)`。所以 R6 删 LGI 后这两个表同时消失，shim 必须把两边都补上。

#### 12.2 关键发现：async 包装可以完全去掉

`parse_dir` 的 `gio.Async.start` 只是把整个函数体包进一个协程，内部的 `async_*` 方法在**同一个协程里顺序执行**：

```lua
gio.Async.start(do_protected_call)(function()
    local result = {}
    parser(gio.File.new_for_path(dir_path), result)  -- 递归
    call_callback(callback, result)
end)
```

内部 `parser` 用 `async_enumerate_children` → `async_next_files(100)` → `async_close`。

**所以 shim 侧不需要实现 `gio.Async.start`**——那是 Lua 协程 + GLib source 的配合，是异步绑定里最难的部分。可直接换同步 API：

- `async_enumerate_children` → `enumerate_children`
- `async_next_files` → `next_files`
- `async_close` → `close`
- **删掉 `gio.Async.start` 包装**

这里说的是**绑定层**不需要 Async 机制。但这**不等于可以无脑同步化**——同步化会引入 UI 卡顿，见下。

##### ⚠️ 同步化的代价：会卡 UI（上一版遗漏了这条）

`async_*` 不只是"没有并发"这么回事——**每个 `async_*` 调用都 `coroutine.yield()`，控制权回到 GLib 主循环，主循环继续处理输入和绘制**。当前实现是协作式的：每 100 个条目让出一次。

| 位置 | 证据 |
|------|------|
| `utils.lua:97-103` | 运行时探测 "yieldable pcall"，注释原文 *"Lua 5.1 cannot yield across a protected call"* —— 整个扫描跑在**会 yield 的协程**里 |
| `menu_gen.lua:78-83` | `generate` 签名带 callback、注释 `@noreturn` |
| `docs/89-NEWS.md:1281` | *"`menubar.menu_gen.generate` is now asynchronous and needs a callback as an argument"* —— 上游**刻意**改成异步 |
| `docs/90-FAQ.md:24-27` | *"All input events (keyboard and mouse) are processed in the main thread. The drawing is also locking the main thread to avoid artifacts and race conditions."* |
| `docs/90-FAQ.md:34-36` | *"prefer ... the GIO async API. Even if you \*think\* a command is fast enough and won't impact the main event loop iteration time, you are wrong. **Every** call to `io.open` is impacted by the system `iowait` queue and can spend hundreds of milliseconds blocked \*before\* being executed."* |

所以主循环确实会在 yield 之间跑。**同步化 = 整个递归扫描期间零让出。**

**会卡在哪**（按 `parser` 实际执行路径）：

1. 递归遍历 `~/.local/share/applications` + 所有 XDG data dir 的 `applications/` 子目录（`menu_gen.lua:28-29` 注释 *"The search is recursive."*）
2. **每个 `.desktop` 文件** `parse_desktop_file`：`KeyFile:load_from_file` 是**同步**文件读（`utils.lua:269-270`），在 `utils.lua:389` 被 `pcall` 包住。**这一步在当前异步版本里也不 yield**——只是每 100 个文件让出一次
3. `menu_gen.lookup_category_icons()`（`menu_gen.lua:86`）

准确说法：**当前版本不是不卡，是把卡顿切成每 100 文件一段；同步化是切成一整段。**

**但影响是一次性的**：`menubar.cache_entries = true`（`init.lua:89`），`menu_gen.generate` 只在首次 `menubar.show()` 调用一次（`init.lua:480-482`），之后复用 `menubar.menu_entries`。卡顿发生在**每次 awesome 会话首次按 Super+P**，不是每次打开菜单。

##### 解法：用 timer 分块，仍然不需要 Async 绑定

R6 的 GLib 绑定面（8.1）本来就要实现 `glib.timeout_add` / `glib.source_remove`（给 `gears/timer.lua:102-120` 用）。**同一个绑定面就能做分块调度**，不需要协程、不需要 Async：

```lua
-- 每个 tick 扫一个目录，tick 之间主循环正常跑输入和绘制
local queue = { unpack(menu_gen.all_menu_dirs) }
glib.timeout_add(glib.PRIORITY_DEFAULT, 0, function()
    local dir = table.remove(queue, 1)
    if dir then
        local entries = parse_dir_sync(dir)      -- 同步扫一个目录
        protected_call(callback, entries)
        return glib.SOURCE_CONTINUE
    end
    return glib.SOURCE_REMOVE
end)
```

让出粒度从"每 100 文件"变"每目录"，但目录数量通常只有个位数（`~/.local/share` + 几个 XDG data dir），粒度足够，且每个目录内部仍是同步扫描、总耗时不变。

**结论**：12.3 的 shim 仍是纯同步 Gio + GLib，不需要 Async；只是 fork 侧 `parse_dir` 改成 timer 驱动而非 `gio.Async.start`。额外代价极小——`glib.timeout_add` 是 R6 本来就要绑的函数。**人天 8-15 不变，但 12.3 的 fork 工作量从"约 50 行"应上调到约 80-100 行**（多一个分块驱动 + 目录队列）。

#### 12.3 方案：同步 Gio shim + fork menubar

| 组件 | 内容 | 工作量 |
|------|------|--------|
| `lgishim_gio.c` | `File.new_for_path` / `enumerate_children` / `get_path` / `get_uri` / `FileInfo.get_file_type` / `FileEnumerator.{next_files,get_child,close}` + 3 常量 | 约 200-300 行 C |
| `lgishim_glib.c` 补充 | `build_filenamev` / `get_home_dir` / `get_user_data_dir` / `get_system_data_dirs` / `KeyFile` / `KeyFileFlags`（6 个，见 12.1） | 约 70 行 |
| fork menubar | `utils.parse_dir` 去 async 包装 + 换同步 API + **改 timer 分块驱动**（见 12.2） | 约 80-100 行 Lua |

**人天：8-15**（原 Gio "2-4"是全砍方案）。

⚠️ **这个 shim 不是 GI 反射**，是手写 C 绑定，可以完全静态链接。它需要链接 `libgio-2.0`，而 3.4 节把"砍 Gio"的理由写成省 `gio-unix` / `libmount` / `libselinux` / `libsystemd` / `libffi` 那条链——所以保留 menubar 就要把这条链静态化。**上一版把这里写成"需要实测验证的硬门槛"，实测结果是否定的，见下。**

##### libgio 依赖链已静态化：docker-x11base 有落地先例

在 `docker-x11base` 仓库里，**`libgio-2.0.a` 的静态链接已经跑通，不是理论可行，是有产物可查**。

`compile/src/v-pcmanfm/build.sh`：

```bash
OB_LIBS="... -lgio-2.0 -lgobject-2.0 -lglib-2.0 -lpcre -lffi"   # gio 三件套 + pcre + ffi
ex0="-lgmodule-2.0 ... -lmenu-cache -luuid -lmount -lpcre -lblkid ..."   # gio 的 mount 依赖
ex1="-lfontconfig -lgio-2.0 -lcairo -lfm -lfm-gtk -lXdamage "
LIBS="$LIBS0" ./configure --prefix=$TARGETPATH
make LDFLAGS="-static " LIBS="-lXinerama -lXfixes -lXrandr $LIBS0"
```

产物（`docs/desk/lxde/pcmanfm.md` 的构建日志）：

```bash
# 静态编译OK;
bash-5.1# echo $?
0
bash-5.1# ls -lh src/pcmanfm
-rwxr-xr-x  1 root root 37.1M Nov 29 15:41 src/pcmanfm
bash-5.1# ldd src/pcmanfm
/lib/ld-musl-x86_64.so.1: src/pcmanfm: Not a valid dynamic program
```

`ldd` 报 "Not a valid dynamic program" = **完全静态，零动态依赖**。构建退出码 0。脚本里还有 `xx-verify --static` 做收尾校验。

**拉进 `libgio-2.0.a` 的只有 3 个目标文件**（从 `musl/10.3.1` 未定义符号日志逐条排查出来的）：

| 目标文件 | 带来的额外链接需求 |
|---------|-------------------|
| `giomodule.c.o` | — |
| `gunixmounts.c.o` | `-luuid -lmount -lblkid` |
| `gzlibdecompressor.c.o` | `-lz` |

**日志里没有出现过 `gdbus*.o`**——因为 pcmanfm 不调 GDBus，链接器只取用到的目标文件。这正是 12.1 第 2 条的意义：menubar 同样零 D-Bus，所以拉进去的还是这 3 个文件，配方可以照抄。

静态库来源是 Alpine 官方 `glib-static 2.70.5-r0`，同时提供 `/usr/lib/libgio-2.0.a`、`libglib-2.0.a`、`libgobject-2.0.a`（`glib-static` 把 gio-unix 并进 `gio-2.0.a`，`gunixmounts.c.o` 就在里面，不需要单独找 `libgio-unix-2.0.a`）。同一仓库里 `v-xlunch/build.sh:52`、`suckless/build.sh:167`、`yad`、`xcompmgr` 都装了 `glib-static`，说明这是仓库的常规做法。

**照抄配方**（menubar 的 Gio shim 需要的最小集）：

```
-lgio-2.0 -lgobject-2.0 -lglib-2.0   # 三件套
-lpcre -lz                            # gio 内部正则 + gzip 解压缩
-lffi                                 # gmodule
-lintl                                # musl 下 glib 的 locale
-luuid -lmount -lblkid                # gunixmounts（一定会被拉进）
```

注意 `-lselinux` / `-lsystemd` 出现在 **pcmanfm 动态构建的 `ldd` 输出里**，但静态构建最终没有它们——那些是 `libfm`/`libmenu-cache` 带进来的，不属于 gio 本身的依赖链。3.4 节把它们列进"要省的链"是宽泛表述，实际 menubar 不碰。

**结论**：libgio 依赖链在 Alpine/musl 上**不是硬门槛，是已验证配方**。剩下的成本是"把 `OB_LIBS` 抄过来 + 跟着未定义符号日志迭代"，不是"从零验证可行性"。

#### 12.4 对 R6 成本的影响

| 子项 | 砍 menubar（原） | 保留 menubar（新） |
|------|-----------------|-------------------|
| Cairo | 0-3 | 0-3 |
| Pango | 15-30 | 15-30 |
| GLib | 3-6 | **4-8**（+4 个 GLib 函数） |
| Gio | 2-4（全砍） | **8-15**（同步 shim + fork） |
| GTK3 | 0 | 0 |
| GdkPixbuf | 0-2 | 0-2 |
| 测试回归 | 6-8 | **8-12**（+menubar 回归） |
| 静态链接 | 10-20 | **6-12**（+libgio 链，配方已验证） |
| **合计** | **38-62** | **47-74** |

**增量：+9 至 +12 人天。**

静态链接行从上一版的 `15-25` 下调到 `6-12`：配方照抄 `v-pcmanfm/build.sh`，剩下的工作是跟未定义符号日志迭代（见 12.3）。因合计由 Pango（15-30）主导，总计维持 47-74 不变，**降的是风险等级，不是工期**。

#### 12.5 三条出路的取舍

| 方案 | 说明 | 判定 |
|------|------|------|
| A. 保留 LGI 整体 | LGI 是 dlopen 反射，保留它就达不到静态化 | ❌ 回到 b15 的 R5 半静态，无实际收益 |
| **B. 同步 Gio shim + fork menubar** | 见 12.3 | ✅ **推荐** |
| C. 放弃 menubar 用 `awful.menu` 手写 | 无 `.desktop` 解析，手动维护菜单 | ❌ 失去能力 |

**方案 B 的关键前提已验证**：libgio 依赖链能静态化。`docker-x11base` 的 `v-pcmanfm` 在 Alpine/musl 上已产出 37.1M 全静态二进制（`ldd` 报 "Not a valid dynamic program"），`libgio-2.0.a` 只拉进 `giomodule.o` / `gunixmounts.o` / `gzlibdecompressor.o` 三个目标文件，配方见 12.3。menubar 零 D-Bus（12.1），所以不会额外拉进 `gdbus*.o`——**这条前提已从"待验证"转为"可照抄"**。

#### 12.6 小结

| 问 | 答 |
|----|-----|
| 保留 menubar 需要保留 LGI 吗 | ❌ **不需要**，绑定层不需 Async，只需同步 Gio shim |
| 额外成本 | +9 至 +12 人天（38-62 → 47-74） |
| ~~libgio 依赖链静态化（musl 上需实测）~~ | ✅ **已消除**，`v-pcmanfm` 先例 + 零 D-Bus |
| 同步化的 UI 卡顿 | ⚠️ **新增风险**，首次 `Super+P` 会卡；用 `glib.timeout_add` 分块规避（见 12.2） |
| 保留理由 | 应用启动器是唯一带 `.desktop` 解析的启动器 |
| 替代 | `modkey+r` promptbox 已能覆盖命令行启动部分 |

**保留 menubar 的成本就落在写 shim（8-15 天）+ 照抄 libgio 静态链接配方（6-12 天）。上一版把它写成"硬门槛"，实测证明不是：docker-x11base 已经用同一条链静态编出 37.1M 的 pcmanfm，menubar 零 D-Bus 所以更不会踩到 `gdbus` 那条分叉。**

**但同步化确实引入了一个新代价：首次打开菜单时会卡 UI**。当前异步实现靠 `coroutine.yield` 让 GLib 主循环在每 100 文件之间继续处理输入（`docs/90-FAQ.md:24` 明确输入与绘制都在主线程）。规避方案是用 `glib.timeout_add` 分目录驱动，**而这个函数本就是 R6 的 GLib 绑定面（8.1）**，所以几乎零额外成本。净效果：代价不是新的人天，是新的一笔需要写对的代码。

---

### 13、待办：把推测值变成实测值

本文档的 4 个最大未知按"收益 / 成本"排序，前 4 项合计约 **3-4 天**，能把最大的 3 个不确定性从推测变成实测。

#### 13.1 Pango 绑定骨架空跑（1-2 天，收益最高）

按 3.2 枚举的约 25 个 API 写 C 骨架，**stub 返回固定值**，先让 `make` 通过、awesome 能启动到能画框。

这一步不追求文本渲染正确，只为了量出**胶水代码实际写了多少行**。它能把 15-30 的区间收窄到实测值，是整份计划里性价比最高的一步——因为 Pango 是合计区间的主体项（7.3）。

#### 13.2 跑现有 spec 建立基线（0.5 天，当前完全没做）

上游自带测试可以直接复用，不需要新写：

```
spec/menubar/
  utils_spec.lua         # 含 parse_desktop_file / KeyFile 解析
  icon_theme_spec.lua
  home/.icons/{icon6.xpm,icon7.svg}   # 9 个真实 fixture 文件
  usr/share/{icon5.png,icon6.xpm,icon7.svg,.filename.png}
  icons/awesome/{index.theme,16x16,32x32,48x48,64x64,scalable}
```

CMake 的 `check-unit` target 就是 `busted`（`CMakeLists.txt:449-462`），在源码目录直接跑。

**先确认它们在改造前是全绿的**，才能作为 shim 完成后的验收依据。这一步是 5、7.1 节"跑纯 Lua 单测子集"的真正落地方式，原文只写了概念没有列具体文件。

#### 13.3 timer 分块原型对比（0.5 天）

在**现有 LGI 环境**上把 `utils.parse_dir` 改成 12.2 的 timer 驱动版本，对比输出与异步版是否一致。

不需要等 shim 写完就能验证 12.2 的设计。这也是 12.3 里 fork menubar "约 80-100 行" 的直接依据。

#### 13.4 awesome 本体静态链接 dry-run（1 天）

在 Alpine 容器里按 12.3 的配方试链**当前 upstream awesome**，确认产物量级和 `ldd` 结果。

12.3 的先例只证明了"pcmanfm 能静态链"，这一步要证明的是"配方可迁移到 awesome"。两者不是一回事——awesome 还要引入 cairo/pango/fontconfig/harfbuzz，虽然同一条链里 pcmanfm 已经静态链过这几个库，但组合方式不同。

#### 13.5 cairo API 语义核查（0.5 天，风险低，排最后）

`cairo.Context` 已数出 28 个方法、约 450 处调用（`cr:line_to` × 83、`cr:set_source` × 60、`cr:translate` × 51、`cr:rectangle` × 38、`cr:paint` × 34、`cr:stroke` × 32……），但 `shape.lua`（28 处）和 `wibox/hierarchy.lua`（12 处）的具体语义还没看过。排在 Pango 后面，因为 cairo 有活的官方库 oocairo 可参照（10.1）。

#### 13.6 做完之后的判断标准

| 结果 | 判断 |
|------|------|
| 13.1 骨架 < 300 行 | Pango 落在 15-20，合计 **38-52** 可信 |
| 13.1 骨架 > 600 行 | Pango 落到 30+，R6 合计可能破 70，需重评 R7（dwm） |
| 13.2 spec 改造前就不全绿 | 5、7.1 的"测试回归 6-8"低估，需重估 |
| 13.4 awesome 链不过 | 12.3 的"已消除"要撤回，回到"硬门槛" |

# b16-260922 | R6 施工方案：抛弃 LGI 的手写 C 绑定

> **来源**：docs/b15-260922-code-repo-analysis.md 章节五（LGI 替代候选实测与最小替换边界）
> **定位**：b15 章节五把 R6（抛弃 GI，纯 C 绑定 + Lua）从 120-240 人天修正为 45-95 人天，并判定"可做但不建议"。本文档是 R6 的**可执行施工方案**，不是可行性论证。
> **结论先行**：R6 不是"重写半个 awesome"，是"**写一个 4 层 700-1000 行的 shim + 砍掉 Gio 和 menubar**"。技术风险只集中在 GLib 主循环一处，其余是体力活。细化后成本 **35-45 人天**，低于 b15 的下限估算。

---

## 一、目标与前置事实

### 1、R6 定义

awesome 静态化的障碍是 `lgi → gobject-introspection → dlopen` 这条链。R6 的做法是**不动 awesome 的 X11 C 内核**（它本来就静态友好：纯 Xlib、无 dlopen、无 GI），只把 Lua 侧的 LGI 绑定层替换为手写 C 绑定。

### 2、LGI 真实调用面（上游 commit `0a5e50c` 实测）

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

### 3、GLib/Gio 是唯一真空缺

GitHub API 全量搜索 `total_count` 全为 0：`lua glib gio binding` / `lgi replacement glib lua` / `lgol lua` / `awesome wm static glib`。GI 反射的 GLib/Gio Lua 绑定从来只有 LGI 一家，且无人做过静态版。**这就是 R6 必须手写的部分。**

---

## 二、第一原则：shim 收敛，不改 39 个文件

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

## 三、逐模块改法

### 3.1 Cairo：0-3 人天，但有个隐蔽坑

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

### 3.2 Pango：10-20 人天，但有更省的绕法

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

### 3.3 GLib 主循环：15-30 人天，成本主体

`lib/gears/timer.lua:60` 的 `require("lgi").GLib` 支撑整个事件循环，是 R6 真正的硬骨头。

**关键认知：障碍不在 glib 库本身**（`libglib-2.0.a` 可静态链接）**，而在"Lua 怎么调它"**。所以手写绑定的面非常小——awesome 只需要 3-4 个 GLib 源相关函数：

```c
// lib/vendor/lgishim_glib.c —— 核心 ~200 行
// 1. source_new(destroy_cb)   → 创建 GLibSource，destroy_cb 是 Lua 函数
// 2. source_attach(src)       → g_source_attach 到 default main context
// 3. source_destroy / source_detach
// 4. timeout_add(ms, func, data)  → 定时器
// 5. idle_add(func, data)           → 空闲回调
```

**最大风险点：GLib source 回调与 Lua 协程的配合。** LGI 用 closure guard 防止 Lua 对象在 C 回调期间被 GC。必须手写等价物：Lua function marshal 成 userdata、引用计数管理、回调时 `lua_pcall`。写错的症状是**随机段错误且堆栈不指向绑定代码**。

可参考 `trip-zip/somewm` 仓库的 `lgi_closure_guard.c`（10KB）+ `lgi_closure_guard.map`（66B）——思路可借，API 不可照抄（somewm 面向 wlroots 的回调模型）。

**验收标准**：1000 个并发定时器下不泄漏、不重入。

### 3.4 Gio：10-20 人天 → **砍到 0-1 人天**

Gio 的 4 处用途逐一定性：

| 位置 | 用途 | 处理 | 依据 |
|------|------|------|------|
| `lib/gears/filesystem.lua` | 文件读写 | **砍**，改回 `io.open` | Gio.File 只是便利封装 |
| `lib/beautiful/init.lua` | 主题文件加载 | **砍**，改回 `io.open` | 同上 |
| `lib/naughty/dbus.lua` | D-Bus 通知图标 | **砍** | awesome C 内核自带 `dbus.c`（30KB），Lua 侧只是通知图标的补充 |
| `lib/menubar/utils.lua` | menubar 配置 | **砍整个 menubar** | 依赖 GTK menubar + Gio，双重依赖 |

砍完后 **Gio 需求从 4 处降到 0**，10-20 人天归零。这是 R6 里最大的成本杠杆。

**代价**：丢 menubar 支持 + 丢 D-Bus 通知图标。对一个容器桌面环境这两个都不是刚需。

### 3.5 GTK3：0 人天

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

### 3.6 GdkPixbuf：0-2 人天

仅 `lib/gears/surface.lua:54` 一处：`GdkPixbuf.Pixbuf.new_from_file(_surface)`。

两条路：
1. **写 50 行 C 绑定**直接调 `libgdk_pixbuf-2.0.a`（可静态链接）——推荐
2. 用 `libpng` 直接解 + oocairo image surface 装载——省一个依赖但要写 PNG 解码路径

---

## 四、编译侧要动的 3 处

```
CMakeLists.txt          → required_modules 里的 lgi 依赖，换成 4 个 lua 模块
build-utils/lgi-check.c → 删除（编译期 lgi 版本检查；shim 里 version 已硬编码）
lib/gears/surface.lua:19-22 → 删除 lgi.version 检查块
```

awesome 已迁 CMake（commit `0a5e50c`），`*.c` 在仓库顶层、Lua 在 `lib/`，无 `src/` 子目录。

---

## 五、施工顺序与验收信号

按"可独立验证"排序，每步都有明确的成功信号：

| 天 | 步骤 | 验收信号 |
|----|------|---------|
| 1-2 | shim 骨架 + Gtk stub + 编译侧 3 处 | `make` 通过，awesome 能启动到 crash |
| 2-3 | Cairo shim（oocairo 包装）+ **5 处 surface 类型标识** | `gears.surface` 能输出纯色图 |
| 3-4 | Pango 最小绑定（60 行手写） | `beautiful.font` 能渲染文字 |
| 5-20 | **GLib 主循环 C 绑定**（含 closure guard） | 1000 定时器压力测试不泄漏、不重入 |
| 20-21 | 砍 Gio 4 处 → `io.open` + C 侧 dbus | 主题加载正常 |
| 21-22 | GdkPixbuf 50 行绑定 | 图片加载正常 |
| 22-28 | 回归：跑 `tests/` 纯 Lua 单测子集 | 无 GI 依赖的测试全绿 |
| 28-38 | 静态链接调试 | 二进制无动态依赖（`ldd` 只剩 libc） |

**总成本 ~35-45 人天**，低于 b15 章节五的 45-95 估算，原因是砍掉了 Gio（省 10-20）和 Pango 整体移植（省 5-15）。

静态链接阶段参照本项目已有方法论（docs/b11 + gitee docker-x11base）：
- libtool 会重排 LDFLAGS，必须用 `-Wl,--start-group` / `-Wl,--end-group` 包住整串库
- Alpine musl 上主动 `--disable` 一批可选功能（参照 openbox 的 7 个 disable）

---

## 六、风险清单

### 6.1 GLib closure guard（高）

C 回调期间 Lua 对象被 GC，症状是**随机段错误，无堆栈指向绑定代码**。somewm 的 `lgi_closure_guard.c` + `lgi_closure_guard.map` 是现成参考，但 API 不可照抄。

### 6.2 cairo surface 类型判别（中，但排查成本最高）

`lib/gears/surface.lua` 5 处判断点（第 35/48/70/109/119 行）。shim 的 metatable 必须能被类型检查识别。**写错不报错，只是画不出图**——预计浪费 2-3 天排查。

### 6.3 测试子集（中）

awesome 的 `tests/` 大量依赖真实 X11 + LGI 的集成测试。静态版大概率只能跑纯 Lua 单测。用 `luatest` 标签过滤出无 GI 依赖的子集，**别指望全绿**。

### 6.4 单作者押注风险（低，但需注意）

oocairo 虽由 awesomeWM 组织维护，实际贡献者集中。若 2025-08 后再次停滞，Cairo 层需要自维护。

---

## 七、成本汇总与结论

### 1、对比表

| 子项 | b15 估算 | 本文细化 | 差异原因 |
|------|---------|---------|---------|
| Cairo 层 | 0-3 | 0-3 | — |
| Pango 层 | 10-20 | **2-4** | 不移植 oopango，手写 60 行最小绑定 |
| GLib 主循环 | 15-30 | 15-30 | 成本主体，无压缩空间 |
| Gio | 10-20 | **0-1** | 全砍，改 `io.open` + C 侧 dbus |
| GTK3 | 0 | 0 | pcall 保护 |
| GdkPixbuf | 0-2 | 0-2 | — |
| 测试回归 | 10-20 | 6-8 | 只跑纯 Lua 子集 |
| 静态链接 | 未单列 | 10-20 | 含 LDFLAGS 调优 |
| **合计** | **45-95** | **35-45** | 砍 Gio + 绕开 oopango |

### 2、R6 在路线排序中的位置

```
R1  保留 lgi           :    0      容器默认
R7  换 dwm 静态        :  5-15     ⭐ 性价比最高
R9  换 somewm(Wayland) : 40-80    需接受后端切换
R6  抛弃 GI 纯 C 绑定  : 35-45    本文；保留 Lua 生态的唯一自研路径
R2  换 LuaGObject      : 20-30    仍动态，非静态化
R3  换 lgob            :100-170   归档 15 年
R5  半静态 GI          : 20-30    无实际收益
R4  换 LuaGnome        :120-240   不可行
```

### 3、结论

- R6 细化后 **35-45 人天**，结论从 b15 的"可做但不建议"收窄为"**有条件建议**"
- 条件：**Lua 生态 + awesome 配置复用对本项目是刚需**
- 若只为"静态 WM"，R7（dwm，5-15 人天）以 1/4 成本拿到同样收益
- R6 的唯一不可替代价值：**保留 60 行调用点背后的整套 Lua widget/layout 生态**

### 4、与 b15 的关系

| 文档 | 内容 |
|------|------|
| b15 章节五 | R6 人天从 120-240 修正为 45-95（调用面实测） |
| **b16（本文）** | R6 施工方案细化，35-45 人天，可执行到"按天排期"粒度 |

# b10-260918 | AwesomeWM 在 musl/Alpine 下的静态编译分析（知识整理）

> 背景：调研"AwesomeWM 能否在 musl 环境（Alpine Linux）全静态编译"。结论先行：**不能，且"外部静态 Lua 运行时替换"与"静态链接 LuaJIT"两条常见思路均为死路**。本文整理结论、根因（重点修正常见误解），并给出容器项目内的落地路径。

## 一、结论

- **不能全静态编译**：[awesomeWM/awesome](https://github.com/awesomeWM/awesome) 深度依赖 XCB / Cairo / Pango / GLib / GObject Introspection，其"编译期绑定 Lua + 运行时 dlopen 动态模块"的架构与全静态不兼容。
- Alpine 官方包（awesome 4.3-r6）为 CMake 动态构建，从未提供静态选项；但这只是现象，不是根因（绝大多数软件包都如此）。
- 容器/项目场景下**直接 `apk add awesome`** 即可，无需也不应追求静态化。

## 二、为什么不能全静态（根因分析）

### 1、核心障碍：运行时 dlopen 依赖链

AwesomeWM 运行时依赖一整条 `dlopen` 链，这是决定性障碍：

- **LGI**（`lua-lgi`）是 Lua 的 C 模块，`require` 时需 dlopen 加载；
- LGI 通过 **GObject Introspection** 读取 `.typelib`，并 dlopen `libgtk` / `libpango` / `libcairo` 等 `.so` 提取运行时类型信息；
- GLib 的 `gmodule`（`GModule`）即该机制本身，type 系统需在运行时注册。

> **全静态 musl 二进制里没有动态链接器，dlopen 不可用**。glibc 下尚可用 `-rdynamic` 做"半静态 + 保留下 dlopen"的折中，musl 下连这条折中都没有。因此哪怕把 LuaJIT、GLib、Cairo、Pango、xcb 全部静态链入，最后一步加载 GI 类型库照样失败。

### 2、编译期绑定 + Lua 版本硬限制

- AwesomeWM 编译时把特定版本 `liblua` 直接链接进主程序（CMake `-DLUA_LIBRARIES` / `-DLUA_LIBRARY`），运行时**不找 lua 可执行文件**；二进制一旦编译完，固定依赖所链接的 Lua。
- 版本限制：仅支持 **Lua 5.1–5.3 或 LuaJIT**（历史上有 `awesome-luajit` 变体），5.4 及更新版本编译期即拒绝。
- 含义：外部静态 Lua 运行时无法"换上去"——it's baked in at build time。

### 3、修正常见误解："Alpine 上依赖库是动态的"不是理由

- musl 本身就是为静态链接设计的：Alpine 上 `gcc -static` 开箱即用，且大量依赖提供 `*-static` 静态库包（如 `xz-static`、`sqlite-static`）。
- 所以"依赖库是动态的 → 跟静态链入冲突"这个说法不成立；真正的障碍只有上面第 1 条的 dlopen/GI 链。

## 三、为什么外部"静态 Lua"方案不适用

`lua_static_battery`（musl 工具链构建静态 Lua）、`slua`（无 libc 的 Lua 5.4 静态构建）、`luastatic`、`minilua`/`onelua` 等，解决的是**"分发一个独立 Lua 运行时/可执行文件"**的问题：

- 它们通常基于 Lua 5.4（版本就与 awesome 冲突）；
- 即便同版本，awesome 需要的也不是"一个 lua 可执行文件"，而是"把自有 C 依赖链静态化"——二者无交集。

一句话：这些项目面向嵌入式脚本引擎与单文件 CLI，与"窗口管理器框架"不是一类问题。

## 四、"静态链接 LuaJIT"为什么是死路

- 换 LuaJIT 只解决解释器本身，**完全不碰 dlopen/GI 这条真正的障碍链**——全静态 musl 下 LGI 照样无法加载。
- 因此这不是"技术难度极高"，而是"换不换都失败"，方向本身无意义。

## 五、可行路径

### 1、常规：`apk add awesome`

Alpine 官方包 4.3-r6，依赖 `lua5.3` / `lua-lgi` / `gdk-pixbuf` / `cairo-gobject` / `pango` 等，全部现成，装上即用。Adelie Linux 的 APKBUILD 可作参考：cmake 动态构建 + 上述依赖链。

### 2、真有"零依赖单文件"需求：换 WM

- **[dwm](https://dwm.suckless.org/)** / `[mackstann/tinywm](https://github.com/mackstann/tinywm)` 等纯 C WM：musl `-static` 秒出单文件；
- **sway**（Wayland）：不用 LGI/GI 生态，静态化/打包容易得多。

> 注意：awesome 的价值正在于"Lua 脚本 + LGI 绑定"这个可编程层，静态化与它的核心价值是反方向的，性能收益也为零。

## 六、对本项目的落地（待办）

- 本项目是容器化桌面，容器镜像本身就是"把依赖打包在一起"的方案——**不存在"无包管理器环境"问题**，AppImage/"半静态打包"建议对容器场景无意义。
- 后续如需 Alpine 跑 awesome：Dockerfile 加 `awesome`，以及在 `entry-x11base.sh` 的 `oneVnc()`/`xvnc2.sh` 中按现有模式注册 perp 服务（可做成 `.arg` 可选开关，如 `AWESOME=1`）。
- 暂未实施；如需要可直接照 b6/b7 的方式新增一个分支。

## 七、社区与 GitHub 调研：案例、挑战与处理（2026-09 补充）

> 本节为对"awesomewm 静态编译"的国内外社区（Reddit / Arch / 中文社区）与 GitHub（awesomeWM、lgi-devs）实证调研。**检索面包括中文社区（知乎/CSDN/V2EX/掘金/Bing）与英文社区，结论均带出处。另有对前文二、四两节的三处勘误，见本节 6（`#### 6.1-6.3`）。**

### 1、调研范围与总体结论

- **没有任何"全静态编译成功"的公开案例**；awesome 官方仓库内搜索 `musl` 返回 0 条 issue（无官方 musl 适配记录）。
- **中文社区此项为空白**：知乎/CSDN/V2EX/掘金/Bing 检索均无静态编译相关讨论，内容全部集中在配置/美化层面——国内基本无人尝试，也无失败记录可引。
- 官方实际使用、有代码实证的形态是**半静态：静态 `liblua` + 动态 lgi/GI 层**（见下）。

### 2、官方源码实证：静态 Lua 库是 CI 标配（勘误一）

`awesomeWM/awesome` 的 `CMakeLists.txt:116-119`（master）：

```
# Enable symbol exports for dynamically loaded modules
# Required for CMake 3.4+ when linking against static Lua libraries on the
# GitHub Actions where we build Lua from source as a static library.
set_target_properties(${PROJECT_AWE_NAME} PROPERTIES ENABLE_EXPORTS ON)
```

- 配套：Linux/GCC 强制 `-rdynamic`（136-146 行，backtrace + dlopen 符号）、FreeBSD `-export-dynamic`（149-153 行）。
- **勘误一**：前文第四节"静态链接 LuaJIT 是死路"表述过强。准确的结论是——**静态 `liblua`（仅 Lua 本身）官方支持且 CI 一直在用**；死路的对象是"**全静态**"（连 glib/cairo/pango/GI 一起静态），因为 `-rdynamic`/`ENABLE_EXPORTS` 恰恰证明 awesome 必须把符号暴露给运行时 dlopen 的 Lua 模块（lgi）用，这条链断不开。
- 衍生含义：即使做成静态 liblua 的"半静态"，对容器部署也无任何收益（见第六节）。

#### 2.1 半静态（仅静态 liblua）方案细化

**定义与做法**：把 Lua 源码编成静态库 `liblua.a`（Lua 官方 Makefile 默认即产出静态库），CMake 指定 `-DLUA_LIBRARY=/path/liblua.a`，并配合 `ENABLE_EXPORTS ON` + `-rdynamic`（Linux/GCC，FreeBSD 则 `-export-dynamic`）。官方 CI 正是此形态——GitHub Actions 从源码构建静态 Lua，目的是**锁定版本、避免发行版 liblua 漂移**，属构建可复现性手段，而非部署手段。

**效果的边界**：主程序因此不再依赖 `liblua.so`（唯一被消掉的动态依赖）；但以下仍然全部动态：

- `lgi.so`：Lua C 模块，`require` 时才 dlopen；
- GI 体系：`.typelib` 文件 + dlopen 的 `libglib`/`libcairo`/`libpango`/`libgdkpixbuf` `.so`。

而这几层恰恰是调研中问题最集中、最易断裂的部分（见本节 4：GLib 2.88 断链、girepository 1.0→2.0 换代未完成、ffi GC 泄漏、LGI 占 97% 运行时间）——半静态一个都没解决。

**技术约束与坑**：

1. **ABI 必须严格一致**：`lgi.so` 要与内嵌的 Lua 同版本（5.1/5.2/5.3/5.4 之间 ABI 不兼容，#1757 即此），发行版的 `lua-lgi` 是按动态 `liblua.so` 链接的，靠主程序 `-rdynamic` 导出符号才能复用——属于"符号借用"式弱耦合，换任何一方的版本都可能静默出问题。
2. **符号导出是硬前提**：静态 liblua 后 `lua_*` 符号只存在于主程序，`lgi.so` 解析不到会直接 `undefined symbol` 崩溃；必须 `ENABLE_EXPORTS`/`-rdynamic`（CMakeLists 117-119，CMake ≥ 3.4）。
3. **LuaJIT 变体另算**：若用 `libluajit.a` 替代标准 Lua，lgi 也得是 LuaJIT 版（AUR `awesome-luajit-git` 的组法见本节 5 表格）。

**收益评估（本容器场景）**：≈ 0。Alpine 里 `liblua5.3` 本就随 apk 自带，少一个 `.so` 无意义；脆弱层（lgi/GI）完全没动。结论：半静态是"官方支持的构建模式"，不是"部署方案"。

### 3、Lua 版本支持实况（勘误二）

前文二.2"5.4 及更新版本编译期即拒绝"只对 4.3 时代成立，社区实测：

- 2021 年 PR #3325 主动加 CMake 检查拒绝 Lua 5.4+；issue #3337 报错原文 *"[awesomeWM/awesome](https://github.com/awesomeWM/awesome) only supports Lua versions 5.1-5.3"*（`awesomeConfig.cmake:78`）。
- 2022 年后 master 已放开 5.4：大量 issue 显示 *"Compiled against Lua 5.4.4/5.4.6/5.4.7"*；#4094 中报错变为 *"5.1-5.4"*（5.5 仍拒）。
- 版本不匹配是**真实崩溃**而非纸面限制：#3123 中 Lua 5.4 的 `math.randomseed` 改整数要求直接触发 `luaA_panic` 重启循环。

### 4、LGI 动态绑定层：最大的实际运维难点

这是比"静态化"更频繁踩坑的地方，均有历年 issue 实证：

- **#4094（2026-03，not_planned）**：GLib 一升到 2.88，lgi 0.9.2 的 cairo override 立刻崩（栈回溯直指 `/usr/share/lua/5.3/lgi/ffi.lua` 的 `load_enum`→`require`→dlopen 链），连 Arch 官方打包都被牵连。
- **lgi PR #337**：girepository 1.0→2.0（GLib 2.80 引入）的移植，2025 至今仍为 **draft 未合并**——GI API 换代是悬在头顶的兼容性债务。
- **lgi #363**：ffi closure 用 `ffi_closure_alloc`（mmap）分配，与 Lua GC 脱钩；`awful.widget.watch` 高频回调一天累积 4GB+ 泄漏。
- **lgi #128**：LGI 曾占 awesome Lua 运行时间**最高 97%**——动态 GI 绑定的性能税。
- **lgi 版本停滞**：0.9.2 停在 2018 年；awesome 维护者（#3338 评论）自认"LGI 比 awesome 更没人维护"，社区讨论转向替代品 `vtrlx/LuaGObject`，但受 4.3 配置 API 兼容性约束迄未切换。

### 5、构建期经典坑与现成处理

| 坑 | 出处 | 处理 |
|---|---|---|
| `lgi-check` 链接报 `undefined reference luaL_*`（静态库未链/顺序错） | #3338 | 装 `liblua*-dev`；可 `AWESOME_IGNORE_LGI=1` 跳过检查（仅构建期跳过，运行时仍需） |
| CMake FindLua 头文件 A 版本、库 B 版本 | #1757 | 显式 `-DLUA_INCLUDE_DIR` / `-DLUA_LIBRARY` / `-DLUA_EXECUTABLE` |
| lgi Makefile 猜死 5.1 路径，多 Lua 共存时装错版本 | #1757 / #3043 / Reddit | `make LUA_LIBDIR=... LUA_SHAREDIR=...` 或 `luarocks install --check-lua-versions lgi` |
| 生成文档阶段 `require('lgi')` 失败 | #3043 | 构建机必须预装同版本 lgi |
| 系统 Lua 版本过新挡住编译 | AUR `awesome-luajit-git` 组法 | 强制 `-DLUA_LIBRARY=/usr/lib/libluajit-5.1.so -DLUA_EXECUTABLE=/usr/bin/luajit -DGENERATE_DOC=OFF` |

### 6、对前文的勘误汇总

#### 6.1 静态 liblua ≠ 全静态（对应前文四节）

前文第四节"静态链接 LuaJIT 是死路"表述过强：静态 `liblua` **官方支持且 CI 一直在用**（`CMakeLists.txt:117`）；真正无解的是"全静态"——`-rdynamic`/`ENABLE_EXPORTS` 证明 dlopen 链断不开。

#### 6.2 Lua 5.4 支持状况（对应前文二.2）

前文"5.4 及更新版本编译期即拒绝"**仅对 4.3 时代成立**：2021 PR #3325 起拒绝 5.4+（#3337 报错原文 5.1-5.3）；2022+ master 放宽到 5.4（5.5 仍拒，见 #4094）。且版本不匹配是真实崩溃而非纸面限制（#3123）。

#### 6.3 "死路"的对象修正

"静态链接 LuaJIT 是死路"应精确定义为"**全静态**（连 glib/cairo/pango/GI 一起）是死路"；仅静态 Lua 库的"半静态"官方可行，但对容器部署无收益。

以上勘误不影响第六节落地结论：**容器内 `apk add awesome` 仍是唯一务实路径**。

## 八、对照实证：Rust + Lua（mlua/Luau）为何可 musl 全静态（2026-09 补充）

> 背景：调研中发现上层目录项目 `fk-tontinton-maki`（Rust 工作区 + Lua 的 AI 编程代理，源：tontinton/maki）在 musl 下可全静态构建，与 awesome 形成直接对照——两者都是"C 核心 + Lua 脚本"混合架构，结论却相反。本节用该仓库源码实证拆解原因。

### 1、结论先行

- maki 能全静态的根因：**Rust musl 目标默认 `crt-static`**（产物中无动态加载器），且其 Lua 层（**mlua + Luau**）是**编译期绑定、零 dlopen 路径**——不存在 awesome 的 GI/dlopen 断点。
- 反向印证前文 `#### 6.1` 勘误一：阻断点从来不是"Lua 能不能静态化"，而是"运行时有没有 dlopen 外挂库的链"。

### 2、Rust 层：musl 全静态是默认约定

- `*-unknown-linux-musl` 为 Rust 官方目标，`crt-static` 默认生效：musl libc、libgcc、vendored C 依赖全部并入二进制。
- 仓库实证 `.cargo/config.toml`：

```toml
# Luau's aarch64 codegen (mlua `luau-jit`) calls __clear_cache from libgcc,
# which rustc's `-nodefaultlibs` musl link would otherwise drop.
[target.aarch64-unknown-linux-musl]
rustflags = ["-C", "link-arg=-lgcc"]
```

- 说明该项目确实在做 musl 全静态，且已踩过"静态链接时 libgcc 符号被 rustc 丢掉"的边角坑（`__clear_cache`）。

### 3、Lua 层：mlua + Luau，编译期绑定、零 dlopen

`Cargo.toml:157`：`mlua = { version = "0.11", features = ["luau", "luau-jit", "async", ...] }`，要点：

- **Luau**（Roblox 沙箱 Lua VM）作为纯 C/C++ 源码编入二进制，mlua 通过 C API 嵌入；`maki-lua/src/runtime.rs:2078` 直接调 `ffi::luau_codegen_compile`（原生代码生成器）。
- **Luau 无 FFI**：脚本无法 `require` 外部 `.so`；插件（init.lua 等）是纯 Lua 源码，不存在运行时加载 C 模块的路径。
- 无 GObject-Introspection / `.typelib` / gmodule / lgi——即前文七.4 里全部脆弱环节在本架构中**不存在**。

### 4、与 awesome 的逐项对照

| 维度 | awesome | maki（mlua + Luau） |
|---|---|---|
| Lua 嵌入方式 | 编译期链 liblua/luajit（静态 liblua 官方支持，见七.2） | 编译期链 Luau（vendored C++） |
| 脚本/配置层 | Lua + lgi → GI → dlopen `.typelib`/`.so` | 纯 Lua 源码，无 FFI、无 dlopen |
| 图形依赖 | glib/cairo/pango/gdkpixbuf 需 GI 化的动态库 | 无（TUI，crossterm） |
| 符号导出 | 必须 `-rdynamic`/`ENABLE_EXPORTS`（dlopen 模块要用） | 不需要 |
| musl 全静态 | 不可行（dlopen 链断） | 可行（crt-static） |

### 5、边界与启示

- **"可行"是条件性的**：maki 一旦引入 C 插件 dlopen 或给 Luau 加 FFI，就会撞上 awesome 同款问题；`aarch64 -lgcc` 补丁已是边角问题的预告。
- 对项目的启示：若真出现"全静态单文件"需求，应选"**解释器 + 宿主、无运行时外挂库**"的架构（Rust/mlua，或纯 C WM 如 dwm），而不是 awesome 这类"运行时外挂"架构——这与前文第五节的结论一致。

## 九、对照实证：OpenResty（Nginx + LuaJIT）为何可静态编译（2026-09 补充）

> 背景：延续"哪些 C+Lua 项目可静态"的对照问题。结论：**OpenResty 能，且比 awesome 简单一个数量级**——Lua 层（LuaJIT）默认就是静态链入 nginx 二进制的，且无 GI/dlopen 链；全静态（含 libc）在 musl 下可行。

### 1、结论先行

- 静态程度分三级看：**默认**（LuaJIT 静态链入）→ **半静态**（再并 OpenSSL/PCRE/zlib）→ **全静态**（加 `-static` + musl，含 libc）。
- 与 awesome 的本质差异：**没有任何一条不可绕开的运行时 dlopen 链**——Lua 层不走 lgi/GI/typelib，NSS/OpenSSL/动态模块等外挂点全部可在配置期关闭。
- 与 maki 同型（解释器 + 宿主、无运行时外挂），印证八章结论：能全静态的 C+Lua 项目去掉"运行时外挂库"即可。

### 2、默认源码构建：LuaJIT 已静态链入（无需 libluajit.so）

- OpenResty `./configure --with-luajit`（默认）使用捆绑的 luajit2，编译产出 `libluajit-5.1.a` **静态链入 nginx 主程序**；官方镜像的 `nginx` 二进制 ldd 中无 luajit，单独拷贝即可运行。
- 辨析：网上常见的 `--with-ld-opt="-Wl,-rpath,.../luajit/lib"` + ldd 显示 `libluajit-5.1.so.2` 属"手搓 Nginx + ngx_lua"（把 LuaJIT 装为系统动态库），不是官方 OpenResty 做法。

### 3、三级静态路径的配置骨架

```
# 默认（LuaJIT 静态）：官方源码 ./configure 即为此形态
./configure --with-luajit ...

# 半静态：依赖源码一并编入
./configure --with-luajit \
  --with-openssl=/path/openssl-1.1.x --with-openssl-opt='no-shared' \
  --with-pcre=... --with-zlib=... -j2

# 全静态（musl，建议 Alpine 构建）
./configure --with-luajit \
  --with-cc-opt='-static -O2' \
  --with-ld-opt='-static' \
  --with-openssl=... --with-openssl-opt='no-shared' ...
```

### 4、难点与处理（均为"可绕开"项，非架构刚需）

| 难点 | 说明 | 处理 |
|---|---|---|
| glibc NSS | glibc 域名解析走 dlopen 加载 `nss_*.so`，全静态二进制解析不了域名 | 换 **musl**（Alpine 构建）；musl 解析器内置，无 dlopen |
| OpenSSL 3.x providers | provider 默认编为独立 `.so`（dlopen 加载） | `no-shared` + provider 编入 libcrypto；或退回 OpenSSL 1.1.x（无 provider 机制，最省事） |
| nginx 动态模块 | `--add-dynamic-module` / `load_module` 即 dlopen | 全静态时禁用；第三方模块一律 `--add-module` 静态编入 |
| LuaJIT 静态符号 | 全静态下可能丢 libgcc 符号（`__clear_cache` 类） | 补 `-lgcc`——同八章 maki `.cargo/config.toml` 那类问题的另一实例 |

### 5、三方对照归纳

- **awesome**：lgi → GI → dlopen `.typelib`/`.so` 是**内核刚需**，无关闭开关 → musl 全静态不可行。
- **OpenResty**：Lua 层为编译期 C API 绑定（lua-nginx-module 直接调 lua_State），resty 脚本不 require C 模块、无 FFI、无 GI；外挂点（NSS/OpenSSL/动态模块）全部可选关闭 → 全静态可行。
- **maki（mlua + Luau）**：解释器 vendored、无 FFI、无 GI → crt-static 全静态可行。

> 三者共同印证本章主线（七.2 / 6.1 勘误一）：**阻断全静态的从来不是"Lua 能不能静态化"，而是"运行时必须 dlopen 外挂库的链"是否存在、是否可关闭**。

### 6、定位与落地

- 全静态 OpenResty 的价值场景：无包管理器环境（路由器/ARM/极小系统）、单二进制分发。
- 容器内照旧 `apk add openresty`（Alpine 有官方包）即可，与第六节对 awesome 的结论一致。

## 十、dlopen 拆解：awesome 的动态加载链用在哪、为什么消不掉（2026-09 补充）

> 背景：承接九章对照，回答"awesome 的 dlopen 用在哪、哪些功能依赖、为什么编译期消灭不了"。结论先行：**dlopen 不是 C+Lua 的必需，是"反射式 GUI 绑定"的必需**——这正是它无法全静态的最深一层原因。

### 1、dlopen 的三处入口

1. **`require()` 加载 Lua C 模块**：内嵌 Lua 处理 `require("lgi")` 时走 `loadlib` → dlopen `.so`（Lua 标准机制；awesome 的 C 模块主角是 lgi）。
2. **lgi → GI 反射（大头）**：lgi 运行时读 `.typelib` 才知道类型/函数结构，再 dlopen `libcairo` / `libpango` / `libgdkpixbuf` / `libglib` / `libgio` 等 `.so` 取函数地址——不对任何库写死胶水代码，所以"编译期无从绑定"。
3. **GLib GModule 机制**：gio modules（TLS 后端、gvfs 等）与动态类型注册走 gmodule 的 dlopen。

### 2、dlopen 喂给的具体功能（全是日常 API）

| 功能 | 走的链 | 证据 |
|---|---|---|
| wibox 绘制（widget 的 draw 回调拿 cairo 上下文画） | `require("lgi").cairo` → dlopen libcairo | 官方文档 16-using-cairo |
| 壁纸 `gears.wallpaper.maximized()` | lgi.cairo surface | 同上 |
| 通知 `naughty`（图标缩放、文字排版） | lgi.GdkPixbuf + lgi.Pango | 源码依赖 |
| 图片加载 `gears.surface.load()` | lgi.cairo image surface | — |
| 颜色解析 `gears.color`（枚举/Pattern） | lgi.cairo override | #4094（GLib 2.88 崩的就是它） |
| 事件循环集成（GLib main loop 接入 awesome 自身 poll） | lgi.GLib + `a_glib_poll` | #2832 栈回溯实证 |
| 异步 spawn / 读子进程输出（`awful.widget.watch`） | lgi.Gio 异步流 | #2832 / lgi #363 |
| 系统集成（文件监视、DBus 会话等） | lgi.Gio / GLib | — |

### 3、为什么"编译期消灭"不掉

- **GI 的设计目标就是运行时反射**：库版本一换，binding 自动跟随；代价是必须 dlopen。官方文档原话："The interface of Awesome is mostly based on a library called LGI … using the GObject-introspection framework"。
- 去掉 dlopen 只有两条路，都是重写级工程：
  1. 放弃 GI、手写全套 C 绑定——≈ 重写 awesome 的一半（GH 上是否有先例：见 `#### 3.1`）；
  2. 全静态 + 禁 GI——配置核心 `gears` 从一开始就 `require lgi`，直接跑不起来。
- 现实佐证：lgi 0.9.2 停滞多年、GLib 一升级就崩（#4094）也没人敢换——因为换 = 重写 API 层。

#### 3.1 案例调研：GH 上是否有"放弃 GI、手写全套 C 绑定"的工程

**结论：没有做成先例。** 手写全套 C 绑定 ≈ 重写半个 awesome，GitHub 上无人走通——"没有先例"本身就是此路不通的实证。

- **LuaGObject 勘误**：`vtrlx/LuaGObject` 常被当作"去 GI 替代方案"（讨论出发点：awesome #3338），实为 **lgi 的 fork 且保留 GI**：
  - README 原话："dynamically generates Lua bindings to libraries which support GObject-Introspection such as GTK, GLib, Gio, Pango…"；
  - 构建强依赖 `GIRepository-2 >= 2.80.0`（`libgirepository-2.0-dev`）；
  - 性质：lgi **维护续命 fork**（改名 + 移植 GIRepository-2 + 持续修 GLib 兼容，0.10.x 截至 2026-02 仍活跃）；
  - 对 dlopen 问题毫无帮助——解决的是"lgi 停更"，不是"GI 依赖"。b10 参考中原"lgi 替代路线"措辞按此修正。
- **真正"手写 C 绑定（无 GI）"的现存案例全是单库级**：
  - `lua-nginx-module`（OpenResty 核心）：手写绑定 nginx C API，生产级（Cloudflare/淘宝）；
  - `luvit/luv`：手写绑定 libuv；
  - Love2D 内部自研 C++↔Lua 绑定层；
  - 老 `lua-gtk`（GTK2 手写绑定）：已死。
  - 规律：**全是"只绑一个库"**；awesome 要的 cairo + pango + gdkpixbuf + glib + gio + GTK 一套无任何先例。
- 深层原因：GI 的存在意义就是"免手写"；手写全套 = 抛弃 GI 初衷 = 重写级成本——无人完成即支撑本节"换 = 重写 API 层"的结论。

### 4、对照：OpenResty / maki 为什么没有这条链（呼应九章）

- 它们绑定的是**己方 C 库**（nginx 的 `lua_State*`、Luau 的 C API），属编译期写死的 C API 绑定，不需要"运行时才知道库长什么样" → 无 dlopen 链 → 全静态无障碍。
- 总结：**dlopen 是"反射式 GUI 绑定"的架构必需，不是"C 核心 + Lua"的必需**——这也是 b10 全部分析收敛到的同一根因（见 `#### 6.1` 勘误一与 2.1 半静态细化）。

## 十一、Xorg 平铺窗口管理器静态编译可行性分级（2026-09 补充）

> 背景：把本系列收敛出的判据套用到 X11 平铺 WM 选型（选型对比见 b11）。结论：**X11 平铺 WM 中，除脚本语言运行时系外，"理论上可静态"是普遍属性**——分野不在 WM 本身，而在是否栖身 GI / 脚本语言 C 扩展这类 dlopen 生态。

### 1、判据（三条）

1. 依赖库是否都有静态版本——musl/Alpine 下基本都有（`*-static` 包）；
2. 运行时是否**必须 dlopen 外挂库**——GI 反射、脚本语言 C 扩展、模块引擎；
3. C 核心是否干净——无 glib/gmodule 刚需、无 Python/Ruby/Lisp 运行时。

### 2、A 级：天生可静态（纯 Xlib/XCB，零 dlopen）

musl `-static` 基本一把梭，**dwm 是标杆**：

- **dwm**（Xlib + Xft + fontconfig + freetype）
- **[baskerville/bspwm](https://github.com/baskerville/bspwm)**（libxcb + xcb-util 全家，无 glib、无脚本运行时）
- **[dimatura/ratpoison](https://github.com/dimatura/ratpoison)**、**[0intro/wmii](https://github.com/0intro/wmii)**（Xlib + libixp）、**[venam/2bwm](https://github.com/venam/2bwm) / [c00kiemon5ter/monsterwm](https://github.com/c00kiemon5ter/monsterwm) / [pyknite/catwm](https://github.com/pyknite/catwm)**（Xlib 小 WM）、**[xorg/app/twm](https://gitlab.freedesktop.org/xorg/app/twm)**（古董）、**[enticeing/musca](https://github.com/enticeing/musca)**（已死但极简）

### 3、B 级：理论可行、有工作量（依赖面大但无 dlopen 刚需）

难点全在**静态 glib/pango/cairo/fontconfig 全套**的编译工程，属工程量而非架构否决：

- **[i3/i3](https://github.com/i3/i3) / i3-gaps**：cairo + pango + glib + yajl + libev + xcb-util 系列 + libxkbcommon + startup-notification；
- **[danakj/openbox](https://github.com/danakj/openbox)**（同族、非平铺）：glib2 + libxml2 + pango + cairo + xkbcommon；
- **[herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm)**：glib 主循环 + xcb-util 系列 + xkbcommon；
- **[conformal/spectrwm](https://github.com/conformal/spectrwm)**：xcb-util 系为主，接近 A 级。

### 4、C 级：理论上可能但代价不成比例

- **[xmonad/xmonad](https://github.com/xmonad/xmonad)**（Haskell/GHC）：musl 静态 GHC 工具链可做，但二进制巨大、构建链痛苦；
- **notion / ion3**（Xlib + Lua 5.1）：Lua 静态官方可行（呼应 `#### 6.1`），但项目已死，纯考古；
- **[stumpwm/stumpwm](https://github.com/stumpwm/stumpwm)**（SBCL）、**subtle**（Ruby）：脚本运行时静态 ≈ 不现实。

### 5、D 级：走八章（maki）路线的天然静态

- **[leftwm/leftwm](https://github.com/leftwm/leftwm)**（Rust）：纯 Rust + x11rb/xcb 纯 Rust 绑定 → `crt-static` 直接出单文件，与 maki 同型。

### 6、与 awesome 的对照（关键一刀）

- **i3/openbox/herbstluftwm 依赖比 awesome 还多（同为 glib/pango/cairo），却理论上可行**——因为它们的文本/绘制绑定是**编译期写死的 C API**（直接链 pango/cairo），没有 awesome 的 lgi→GI→dlopen `.typelib` 反射链（见第十章）。
- **[qtile/qtile](https://github.com/qtile/qtile)（Python）反面验证判据**：python-xlib 是纯 Python，但 xcffib 走 cffi 加载 libxcb，且 CPython 的 C 扩展本质是 dlopen——全静态时 Python 层 C 模块照样加载不了，与 lgi 完全同构；xmonad/stumpwm 同理。
- 结论：**X11 平铺 WM 里静态与动态的分野，归根结底还是 b10 那根"运行时 dlopen 外挂库的链"**；A 级（dwm/bspwm）musl `-static` 可实践验证。

### 7、其他用 Lua 的窗口管理器（补充）

> X11 生态里"用 Lua"是 ion3/awesome 一脉的小众传统：其余 WM 要么纯配置文件（i3）、要么 Shell（herbstluftwm）、要么编译期定死（dwm）。除 awesome 外可查到的 Lua WM 极少，且**静态可行性完全由绑定方式决定**（沿用本章判据）。

#### 7.1 编译期 C API 绑定（理论可静态）

| 项目 | 架构 | 说明 |
|---|---|---|
| **notion / ion3** | C（Xlib）+ Lua 5.1 | 纯 Xlib、无 GI，静态 Lua 官方可（呼应 `#### 6.1`）；项目已死 |
| **[tonybanters/oxwm](https://github.com/tonybanters/oxwm)**（tonybanters） | **Zig** + Lua 5.4 | Xlib 的 Zig 绑定 + 内嵌 Lua，配置热重载 |
| **[kelseythedreamer/librarywm](https://codeberg.org/kelseythedreamer/librarywm)**（kelseythedreamer） | C++ + Lua 5.4 | XCB 系 + Cairo-XCB + Lua 5.4 嵌入，热重载 |
| **[srdusr/srdwm](https://github.com/srdusr/srdwm)**（srdusr） | Rust + Lua 5.4 | 跨平台多后端（X11/Wayland/Win/mac） |

无 GI/typelib 层，按本章判据属**理论可静态**（C++ 系工程量更大，Zig/Xlib 系更干净）。

#### 7.2 运行时 FFI 绑定（与 awesome 同病：静态必死）

- **[vifino/ljwm](https://github.com/vifino/ljwm)**（vifino）：LuaJIT + XCB 的 FFI 绑定。LuaJIT FFI 本质是运行时 dlopen 加载 xcb——**与 qtile/cffi、与 lgi 完全同构**（见第十章），musl 全静态下加载不了。这是"用 Lua 但照样不能静态"的第二个样本，补齐判据的反面清单。

#### 7.3 外部进程 / IPC 脚本（Lua 不在 WM 里，与静态无关）

- **[bartman/wmii-lua](https://github.com/bartman/wmii-lua)**（bartman）：给 wmii 写的 wmiirc 替代脚本，Lua 以独立进程经 9p 控制 wmii——WM 本身 C/Xlib 不受影响；
- **Wayfire 系**（Wayland）：核心插件是 dlopen 的 `.so`，Lua 走 `[Javyre/wf-lua](https://github.com/Javyre/wf-lua)`（实验性）/ Python 走 `[WayfireWM/pywayfire](https://github.com/WayfireWM/pywayfire)` IPC——均为外置脚本。

#### 7.4 小结

- 静态可行性由**绑定方式**决定，与"是否 Lua"无直接关系：编译期嵌入 → 可静态；运行期 FFI → 不可静态（与 GI 链同源）。
- 对项目选型的启示：若目标是"Alpine 可跑 + 保留将来单文件可能"，**[tonybanters/oxwm](https://github.com/tonybanters/oxwm)（Zig）或 [kelseythedreamer/librarywm](https://codeberg.org/kelseythedreamer/librarywm)（C++、纯 XCB 无 GI）**比 awesome 更符合本系列结论——但均为新/小项目，成熟度远不及 awesome（选型完整对比见 b11）。

### 8、仓库清单（GitHub 链接 + Stars 快照 2026-09）

> 颗粒度按正文分级（A/B/C/D 与 7 节 Lua 系）；**Stars 为 GitHub API 2026-09 快照**，随搜索时间变动。无官方 GH 仓库者注明镜像/原址。

| WM | Stars | 仓库 | 备注 | 亮点概要 |
|---|---|---|---|---|
| **① Lua 系** | | | | |
| awesome (C+Lua) | 6957 | [awesomeWM/awesome](https://github.com/awesomeWM/awesome) | 本文主角 | Lua 完全可编程；wibox/naughty/gears 生态最大 |
| [tonybanters/oxwm](https://github.com/tonybanters/oxwm) (Zig+Lua) | 951 | [tonybanters/oxwm](https://github.com/tonybanters/oxwm) | 7.1（Zig+Lua） | Zig+Lua 热重载，LSP 配置补全 |
| [Javyre/wf-lua](https://github.com/Javyre/wf-lua) (Zig+Lua) | 16 | [Javyre/wf-lua](https://github.com/Javyre/wf-lua) | 7.3（实验性） | Wayfire Lua 自动化脚本层（实验） |
| ion3/notion (C+Lua) | 10 | [jan0sch/Ion3](https://github.com/jan0sch/Ion3) | 镜像；ion3 与 notion 均已停维护 | 分屏会话制平铺鼻祖（Lua 配置） |
| wmii-lua (Lua) | 9 | [bartman/wmii-lua](https://github.com/bartman/wmii-lua) | 7.3（9p 外置脚本） | Lua 实现 wmiirc（省电替代 Ruby 版） |
| [srdusr/srdwm](https://github.com/srdusr/srdwm) (Rust+Lua) | 0 | [srdusr/srdwm](https://github.com/srdusr/srdwm) | 7.1（新建） | 跨平台多后端（X11/Wayland/Win/mac） |
| [vifino/ljwm](https://github.com/vifino/ljwm) (Lua) | 0 | [vifino/ljwm](https://github.com/vifino/ljwm) | 7.2 负面样本 | LuaJIT+XCB 自制 WM 工具包（FFI 反面） |
| [kelseythedreamer/librarywm](https://codeberg.org/kelseythedreamer/librarywm) (C++) | — | codeberg.org/kelseythedreamer/librarywm（非 GH） | 7.1（C++/XCB） | 纯 XCB 无 GI，OOP+Cairo，配置热重载 |
| **② C/C++ 系** | | | | |
| [i3/i3](https://github.com/i3/i3) (C) | 10568 | [i3/i3](https://github.com/i3/i3) | B 级；i3-gaps 已并入上游 | 命令式配置 + 树布局，X11 平铺用户量第一 |
| [baskerville/bspwm](https://github.com/baskerville/bspwm) (C) | 8315 | [baskerville/bspwm](https://github.com/baskerville/bspwm) | A 级 | 二叉树平铺，bspc 消息式控制 |
| [conformal/spectrwm](https://github.com/conformal/spectrwm) (C) | 1408 | [Conformal/spectrwm](https://github.com/Conformal/spectrwm) | B 级（近 A） | 滚动布局 + 多屏（Xinerama）强 |
| [herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm) (C++) | 1165 | [herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm) | B 级 | Shell 命令式标签/布局控制 |
| [venam/2bwm](https://github.com/venam/2bwm) (C) | 853 | [venam/2bwm](https://github.com/venam/2bwm) | A 级 | 极简、浮动为主 |
| [danakj/openbox](https://github.com/danakj/openbox) (C) | 728 | [danakj/openbox](https://github.com/danakj/openbox) | 镜像；官方 git 在 [danakj/openbox](https://github.com/danakj/openbox).org | 老牌堆叠 WM，可作桌面替换 |
| [c00kiemon5ter/monsterwm](https://github.com/c00kiemon5ter/monsterwm) (C) | 342 | [c00kiemon5ter/monsterwm](https://github.com/c00kiemon5ter/monsterwm) | A 级 | [dwm](https://dwm.suckless.org/) 系极简变体 |
| [pyknite/catwm](https://github.com/pyknite/catwm) (C) | 253 | [pyknite/catwm](https://github.com/pyknite/catwm) | fork；原 ckanet/catwm 已移除 | 极简"cat 风"平铺 |
| [0intro/wmii](https://github.com/0intro/wmii) (C) | 137 | [0intro/wmii](https://github.com/0intro/wmii) | 镜像；原 gitorious 已死 | 9p 文件系统控制（wmiirc） |
| [enticeing/musca](https://github.com/enticeing/musca) (C) | 22 | [enticeing/musca](https://github.com/enticeing/musca) | 镜像；项目已死 | 极简纯键盘平铺 |
| [dimatura/ratpoison](https://github.com/dimatura/ratpoison) (C) | 15 | [dimatura/ratpoison](https://github.com/dimatura/ratpoison) | 镜像；官方在 savannah.gnu.org | 无鼠标、GNU Screen 式操作 |
| [dwm](https://dwm.suckless.org/) (C) | — | git.suckless.org/dwm（无官方 GH） | A 级标杆 | suckless 极简标杆、补丁文化 |
| [xorg/app/twm](https://gitlab.freedesktop.org/xorg/app/twm) (C) | — | gitlab.freedesktop.org/xorg/app/twm | X.Org 官方 | X.Org 默认 WM（始祖） |
| **③ Rust 系** | | | | |
| [leftwm/leftwm](https://github.com/leftwm/leftwm) (Rust) | 3047 | [leftwm/leftwm](https://github.com/leftwm/leftwm) | D 级（Rust） | Rust 单二进制，crt-static 天然静态 |
| subtle (Rust) | 4 | [unexist/subtle-rs](https://github.com/unexist/subtle-rs) | 原 GH 已移除；作者 Rust 重写 | 原 subtle 理念的 Rust 续作 |
| **④ 其他语言系（Python/Haskell/Common Lisp）** | | | | |
| [qtile/qtile](https://github.com/qtile/qtile) (Python) | 5297 | [qtile/qtile](https://github.com/qtile/qtile) | Python 反面样本 | 纯 Python 可编程（C 扩展 dlopen 反面） |
| [xmonad/xmonad](https://github.com/xmonad/xmonad) (Haskell) | 3595 | [xmonad/xmonad](https://github.com/xmonad/xmonad) | C 级 | Haskell 类型化配置 |
| [stumpwm/stumpwm](https://github.com/stumpwm/stumpwm) (Common Lisp) | 2027 | [stumpwm/stumpwm](https://github.com/stumpwm/stumpwm) | C 级 | 全 Lisp 可编程桌面 |
| [WayfireWM/pywayfire](https://github.com/WayfireWM/pywayfire) (Python) | 18 | [WayfireWM/pywayfire](https://github.com/WayfireWM/pywayfire) | 7.3（Wayfire IPC） | Wayfire IPC 官方 Python 客户端 |

## 十二、awesome 核心库速览与横向对比亮点（2026-09 补充）

> 背景：承接十一章选型与仓库清单，补两问——三个核心 Lua 库（gears/wibox/naughty）分别干什么；awesome 对比其他 WM 还有哪些细节级亮点（含诚实的短板）。

### 1、核心 Lua 库速览：gears / wibox / naughty（+ awful）

- **gears = 工具函数库（地基）**：`gears.color`（颜色，走 lgi.cairo 枚举）、`gears.surface`（图片→cairo surface）、`gears.wallpaper`（壁纸）、`gears.shape`（圆角/多边形）、`gears.object`（信号/属性 OOP 基类）、`gears.timer`、`gears.protected_call` 等，被全部模块依赖。
- **wibox = 图形组件/布局系统（UI 层）**：`awful.wibar`（状态栏容器）、`wibox.widget.*`（textbox/iconbox/graph/progressbar）、`wibox.layout.*`、`wibox.container.*`；每个 widget 的 `draw` 回调拿 **cairo 上下文**绘制（`require("lgi").cairo`）。
- **naughty = 通知系统**：`naughty.notify`，支持图标/动作/主题/位置；底层 `lgi.GdkPixbuf` + `lgi.Pango`。
- **awful = WM 逻辑**（tag/rule/键盘绑定/标题栏/spawn/菜单），与前三者同属 Lua 侧。

```
gears（工具/地基）
  └─ wibox（UI 组件层，画界面）
  └─ naughty（通知）
  └─ awful（WM 逻辑：tag/rule/键盘/标题栏/spawn）
```

> 三者底层依赖即第十章 dlopen 功能对照表的上半部分（lgi.cairo / GdkPixbuf / Pango）——"Lua 可编程"买点与"静态不可行"病根同源。

### 2、与其他 WM 的对比亮点（细节级）

#### 2.1 运行时可编程性（最核心分水岭）

| WM | 改"逻辑"的方式 |
|---|---|
| [i3/i3](https://github.com/i3/i3) | 改配置文件 → reload，布局算法不可改 |
| [baskerville/bspwm](https://github.com/baskerville/bspwm) | 只能 bspc 命令行调用预设动作 |
| [dwm](https://dwm.suckless.org/) | 改 C 源码重编译（suckless 哲学） |
| [xmonad/xmonad](https://github.com/xmonad/xmonad) | 改 Haskell 重编译 |
| [herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm) | shell 命令驱动 |
| **awesome** | **rc.lua 即程序**：运行时建 wibox、动态改按键、`awesome-client` 经 DBus 注入任意 Lua |

细节：`awful.placement`（放置策略）、`awful.layout.suit.*`（布局套件可运行中切换）、`gears.object` 信号系统（`property::active` 响应式更新，非轮询）。

#### 2.2 内置 UI 组件引擎（wibox）——别家基本没有

- i3 状态栏 = 外部工具拼**文本流**（i3status/i3blocks）；dwm = root window title hack；bspwm 无 UI。
- awesome = 真 widget 框架：graph/progressbar/icon + `awful.popup`（任意浮窗）、`awful.tooltip`、`awful.menu`、`awful.prompt`——桌面小组件/音乐浮窗/OSD 全内建可编程。

#### 2.3 对象模型与规则引擎

- client / tag / screen 为一级可编程对象；`awful.rules` 一条规则同时匹配 class/instance/name + 设定 screen/tag/布局/浮动/焦点——i3 的 assignment 只到"哪个 workspace"，dwm 要改源码。
- tag 模型支持多 tag 重叠窗口、动态增删，比 i3 固定 workspace 灵活。

#### 2.4 主题与热重载

- `beautiful` 主题库（配色/字体/图标/壁纸统一），**运行中 `beautiful.init()` 热换**；对比 dwm 换主题 = 改代码重编、i3 = 手改颜色串。

#### 2.5 协议与生态

- EWMH/ICCCM 合规度高（polybar/任务栏可正确识别）；DBus 双向集成（外部脚本可控 WM）；模块化分层 + 完整 API 参考文档。

### 3、诚实的短板（选型必看）

| 短板 | 说明 |
|---|---|
| 学习曲线陡 | Lua + 组件树 + 信号，默认 rc.lua 数百行，新手劝退 |
| 版本停滞 | 4.3 发布多年，v4.4 拖延至今 |
| LGI/GI 脆弱链 | GLib 升级即崩（#4094）、lgi 停更（第十章全篇） |
| 生态规模 | stars/社区远小于 [i3/i3](https://github.com/i3/i3)，现成配置少 |
| 静态/部署 | 全静态不可能（本系列结论）；i3/dwm 至少理论可静态 |

### 4、一句话总结

awesome 是 X11 里唯一"把 WM 做成可编程平台"的（类似 Emacs 之于编辑器）；代价是绑定 lgi/GI 这条脆弱且静态无解的链——**强到极致 ≠ 适合"Alpine 可跑 + 可静态"的项目诉求**，与十一、九、八章结论指向一致。

## 十三、i3 / LeftWM / awesome 三方横向对比（2026-09 补充）

> 背景：补全十一/十二章未覆盖的两个对比对象——i3wm（B 级 C 系代表）与 LeftWM（D 级 Rust 系代表），与 awesome 三方比优劣势。

### 1、i3wm 细节亮点项

- **C 实现、树形布局模型**（split/tabbed/stacked 容器）；`~/.config/i3/config` 纯声明式，`Mod+Shift+R` 重载/重启；
- **IPC socket + `i3-msg`**：外部脚本可查/改状态；
- **workspace + 多屏**：`workspace N → output`、双屏互转；
- 浮动窗、resize 模式、modes（按键层）、scratchpad；
- **i3bar 内置托盘** + i3status/i3blocks/py3status/polybar 外部喂文本；
- **gaps 已合入上游（4.22+）**；`assign` / `for_window` 规则；
- 短板：**无运行时可编程**、无 widget 框架、树模型有学习成本；静态为 B 级（pango/glib/cairo 全家）。

### 2、LeftWM 细节亮点项（Rust，官方文档核验）

- **Rust + x11rb（纯 Rust 后端）**；配置为 **RON**（0.4.0 由 TOML 迁移，0.6.0 移除 TOML）；`leftwm-check` 校验、`leftwm-config` 生成/编辑（TUI beta）；
- **主题即文件夹**：`themes/<NAME>/theme.ron` + 随主题附带的 **`polybar.ini` 与 `picom.conf`**——换主题连状态栏/合成器配置一起换；
- **布局可编程**：内建 13+ 布局 + `layout_definitions` **参数化自定义**（flip/rotate/columns/main size DSL）；`layout_mode: Workspace / Tag`；
- window_rules（for_window 钩子）、scratchpad、insert_behavior、focus_behaviour 细粒度开关；
- **工具链完整**：`leftwm-state`（JSON 喂 bar）、`leftwm-command`（IPC）、`leftwm-worker`/`watchdog`；
- **编译期特性开关**：lefthk/journald/xlib/x11rb——**Rust + musl 可静态（D 级，八章路线）**；
- 短板：无内置 bar（依赖 polybar/waybar）、声明式非运行时编程、生态小（约 3k stars）、开发节奏间歇。

### 3、三者优缺点对比表

| 维度 | i3wm | LeftWM | awesome |
|---|---|---|---|
| 实现语言 | C | **Rust** | C + Lua |
| 配置方式 | 声明式文本 | 声明式 RON + 布局 DSL | **Lua 编程** |
| 运行时可编程 | ✘（仅 IPC） | ✘（soft-reload） | **✔︎（rc.lua + awesome-client）** |
| 内置 UI/bar | i3bar（文本+tray） | ✘（主题附 polybar 配置） | **wibox widget 框架** |
| 布局可自定义 | 仅内置 | **layout_definitions DSL** | **Lua 布局套件** |
| 主题系统 | 手改颜色串 | **主题文件夹即插即用** | beautiful 热换 |
| 规则引擎 | assign/for_window | window_rules | **awful.rules（最全）** |
| 通知/弹窗 | 外部 | 外部 | **naughty/awful.popup 内建** |
| 多屏 | 好 | 好 | 好 |
| 热重载 | config reload | 软重载保留状态 | 完整运行时 |
| **musl 全静态** | 理论可行（B 级） | **天然可行（D 级）** | ✘（dlopen 链） |
| 生态/文档 | 最大、最成熟 | 小、wiki 完善 | 中、API 文档最全 |
| 学习曲线 | 中 | 中低 | **高** |

### 4、选型结论（三句话）

- **要稳、要规模**：i3——文档最全、社区最大、行为可预期，代价是"只是配置"。
- **要新、要单文件**：LeftWM——Rust 静态可部署、主题/布局声明式且系统化，代价是生态小、无 bar、无运行时编程。
- **要极致可编程**：awesome——唯一"WM 即平台"，代价是 lgi/GI 脆弱链 + 静态无解（本系列结论）。

## 十四、tiling window manager 检索补遗：C/C++/Rust 系新发掘（2026-09）

> 背景：按关键词 `tiling window manager` 在 GH（按语言过滤）与国内外社区（ArchWiki 中文对照表、维基百科、中文博客系列）检索。结论：**权威清单与 b10 已收录一致，增量全在 GH 长尾**；且 2025-2026 出现 C/C++ 平铺"复苏信号"。

### 1、检索范围

- 论坛/专业文档：ArchWiki 中文《平铺窗口管理器对比》、维基百科《X 窗口管理器比较》、geek-blogs 中文系列长文（2025-10~12）；
- GitHub API：`q=tiling window manager + language:C / C++ / Rust`，按 stars 排序；
- 深查（2026-09 第二轮）：换关键词 `dynamic window manager` 补齐 dwm 家族（FrankenWM/modwm/adwm/katriawm）；并对 7 个新 WM 做依赖核验（见 `#### 5.1`）；
- 平台口径：以 Linux X11 为主，Wayland / Win / macOS 单列备注。

### 2、C 系新发掘（X11，理论可静态 A/B 级）

| WM | Stars | 仓库 | 亮点 | 状态 |
|---|---|---|---|---|
| ragnar | 1252 | [cococry/ragnar](https://github.com/cococry/ragnar) | [i3/i3](https://github.com/i3/i3) 风格、极简灵活、活跃开发（2026-09 仍在推） | 活跃 |
| sxwm | 982 | [uint23/sxwm](https://github.com/uint23/sxwm) | feature-rich 动态平铺（netcat.uk 出品） | 活跃 |
| dvtm | 964 | [martanne/dvtm](https://github.com/martanne/dvtm) | console（终端内）平铺，非 X11——旁注 | 维护 |
| howm | 657 | [HarveyHunt/howm](https://github.com/HarveyHunt/howm) | **vim 风格操作**（hjkl 分屏/移动）、纯 XCB | 半停（2022） |
| FrankenWM | 286 | [sulami/FrankenWM](https://github.com/sulami/FrankenWM) | [dwm](https://dwm.suckless.org/) fork + 丰富布局（深查新增） | 活跃 |
| modwm | 145 | [plasmoduck/modwm](https://github.com/plasmoduck/modwm) | 模块化动态 WM（深查新增） | 维护 |
| zwm | 92 | [yazeed1s/zwm](https://github.com/Yazeed1s/zwm) | XCB BSP 树、配置语法可读、releases 至 2026-01 | 活跃 |
| adwm | 65 | [bbidulock/adwm](https://github.com/bbidulock/adwm) | advanced dynamic WM，dwm/CFWN 系（深查新增） | 维护 |
| katriawm | 55 | [vain/katriawm](https://github.com/vain/katriawm) | 动态平铺 + 装饰、非 reparenting（深查新增） | 维护 |

### 3、C++ 系新发掘（X11，B 级；chamferwm 含 Vulkan 链）

| WM | Stars | 仓库 | 亮点 | 状态 |
|---|---|---|---|---|
| Hypr | 1309 | [hyprwm/Hypr](https://github.com/hyprwm/Hypr) | C++20/XCB；X11 平铺——**注意与 Hyprland 是两个项目** | 2024 后停滞 |
| wmderland | 408 | [aesophor/wmderland](https://github.com/aesophor/wmderland) | 空间划分树（space partitioning）、纯 Xlib | 半停（2023） |
| chamferwm | 258 | [jaelpark/chamferwm](https://github.com/jaelpark/chamferwm) | X11 平铺 **+ 内置 Vulkan 合成器** | 活跃 |
| miracle-wm | 807 | [miracle-wm-org/miracle-wm](https://github.com/miracle-wm-org/miracle-wm) | C++/Mir，Wayland 版——旁注 | 活跃 |

> sirenwm（C++/Lua，X11+WL 双后端）与 cwc（C，Wayland）已分别在十三章/十一章 7 节收录，不重复。

### 4、Rust 系新发掘（多为非 X11 平台，D 级天然静态）

- **Windows**：[komorebi](https://github.com/LGUG2Z/komorebi)（15189★）、[nog](https://github.com/TimUntersberger/nog)（697★）；
- **macOS**：[glazewm](https://github.com/glzr-io/glazewm)（12774★，Win/mac）、[paneru](https://github.com/karinushka/paneru)（2271★）、[rift](https://github.com/acsandmann/rift)（2251★）、[glide](https://github.com/tmandry/glide)；
- **X11**：[penrose](https://github.com/sminez/penrose)（1351★，库型）、[wtftw](https://github.com/Kintaro/wtftw)（2377★）、[leftwm](https://github.com/leftwm/leftwm)（3047★）、[gar](https://github.com/gardesk/gar)（Rust+Lua）——均已在前文收录；
- **X11 长尾（深查新增）**：[mwm](https://github.com/monroeclinton/mwm)（290★）、[hadlock](https://github.com/AdaShoelace/hadlock)（157★）、[pgwm](https://github.com/MarcusGrass/pgwm)（70★）、[lanta](https://github.com/mjkillough/lanta)（66★）、[marswm](https://github.com/jzbor/marswm)（55★，动态平铺 Rust 新作）。

### 5、静态分级与依赖核验（深查证据版）

#### 5.1 依赖核验（2026-09 深查：从"理论"升为"证据"）

抓取 7 个新发掘 WM 的 README 依赖清单，**全部无 glib / gmodule / dlopen**：

| WM | 实际依赖 | 静态判定 |
|---|---|---|
| ragnar | libx11 + libxcb + xcb-util | A 级 |
| sxwm | libx11 + xcb-util | A 级 |
| howm | xcb + cottage（配置库）+ sxhkd | A 级 |
| zwm | libxcb + xcb-util 系列 | A 级 |
| wmderland | 纯 Xlib | A 级 |
| Hypr | XCB（非合成器，需 xmodmap 绑键） | A/B |
| chamferwm | xlib + Vulkan + fontconfig/freetype | B |

结论：无 dlopen/GI 链这条判据**全数通过**，与全文主线互相印证；chamferwm 的 B 级仅因 Vulkan 链路工程量大。

#### 5.2 "复苏信号"点评

- C 系（ragnar/sxwm/howm/zwm 及 dwm 族 FrankenWM/modwm/adwm/katriawm）：纯 XCB/Xlib 直连、无 GI——**A 级**；
- C++ 系：**B 级**；chamferwm 因 Vulkan 合成器链路工程量大；
- Rust 系：**D 级**（crt-static，八章路线）；
- 信号：2025-2026 新建的 C/C++ 平铺明显增多且都走"无 GI 直连 XCB"——与本系列结论反向印证（避开 dlopen 反射链 = 可静态）。

## 参考

- Adelie Linux awesome APKBUILD：cmake 动态构建，`makedepends` 即完整依赖链清单
- Termux x11-packages `awesome/build.sh`：依赖项与 `awesome-luajit` 变体佐证（支持 LuaJIT / 拒绝之外的组合）
- build-your-own.org《Effortless static linking on Alpine》：musl 静态链接开箱即用、Alpine `*-static` 包机制
- [awesomeWM/awesome](https://github.com/awesomeWM/awesome) `CMakeLists.txt`（master）：`ENABLE_EXPORTS` / `-rdynamic` / `-export-dynamic`
- awesomeWM issues：#3325、#3337（5.1-5.3 检查）、#3123（Lua5.4 崩溃）、#4094（GLib 2.88 断链）、#3338（lgi-check 链接）、#3043、#1757（lgi 路径/版本错配）
- [lgi-devs/lgi](https://github.com/lgi-devs/lgi)：#337（girepository-2.0 移植 draft）、#363（GC 泄漏）、#128（性能占比）
- [vtrlx/LuaGObject](https://github.com/vtrlx/LuaGObject)：lgi **维护续命 fork**（保留 GI / 移植 GIRepository-2.0，非去 GI 方案；讨论出发点在 awesome #3338，勘误见 `#### 3.1`）
- Arch AUR `awesome-luajit-git`：显式指定 Lua 库参数的构建组法
- [tontinton/maki](https://github.com/tontinton/maki)（本地 `fk-tontinton-maki`）：Rust 工作区 + [mlua-rs/mlua](https://github.com/mlua-rs/mlua)(Luau) 全静态对照实证；`.cargo/config.toml`、`maki-lua` crates
- [mlua-rs/mlua](https://github.com/mlua-rs/mlua)（0.11，features `luau`/`luau-jit`/`async`）：Rust Lua 绑定，编译期嵌入 Luau
- Rust `*-unknown-linux-musl` 目标：`crt-static` 默认全静态
- OpenResty 官方安装文档 / 官方博客《安装 OpenResty》（`./configure --with-luajit`、捆绑 luajit2 构建）
- lua-nginx-module（openresty 分支）：编译期 C API 绑定 LuaJIT，resty 脚本无 FFI/GI（九章对照依据）
- OpenSSL 3.x providers / glibc NSS dlopen 问题：九章难点表的处理依据（musl/Alpine 路径）
- b11《Xorg 平铺窗口管理器选型对比知识整理》：本章（十一）选型对照的交叉参考
- [dwm](https://dwm.suckless.org/)（suckless）：Xlib + Xft + fontconfig（A 级标杆）；[baskerville/bspwm](https://github.com/baskerville/bspwm)：libxcb/xcb-util 系列（A 级）
- [i3/i3](https://github.com/i3/i3) / [danakj/openbox](https://github.com/danakj/openbox) / [herbstluftwm/herbstluftwm](https://github.com/herbstluftwm/herbstluftwm)：依赖清单（pango/cairo/glib/yajl/xkbcommon 等，B 级依据）
- [leftwm/leftwm](https://github.com/leftwm/leftwm)（Rust）：x11rb/xcb 纯 Rust 绑定，`crt-static` 天然静态（D 级，走八章路线）
- [qtile/qtile](https://github.com/qtile/qtile)（Python）：xcffib/cffi 加载 libxcb——"脚本运行时 C 扩展 = dlopen"的反面实例
- 其他 Lua WM（十一章 7 节）：ion3/notion（Xlib+Lua5.1）、[tonybanters/oxwm](https://github.com/tonybanters/oxwm)（Zig+Lua5.4）、[kelseythedreamer/librarywm](https://codeberg.org/kelseythedreamer/librarywm)（C++/XCB+Lua5.4）、[srdusr/srdwm](https://github.com/srdusr/srdwm)（Rust+Lua5.4）、[vifino/ljwm](https://github.com/vifino/ljwm)（LuaJIT FFI+XCB，负面样本）、wmii-lua（9p 外部脚本）、wf-lua/pywayfire（Wayfire IPC 外置脚本）
- 十一章 8 节仓库清单：Stars 为 GitHub API 2026-09 快照；无官方 GH 仓库者（dwm/twm/librarywm/ion3 等）已注明镜像或原址
- [leftwm/leftwm](https://github.com/leftwm/leftwm)（Rust）：config.ron / theme.ron、layout_definitions、leftwm-state 工具链（十三章依据，docs.rs + Codeberg wiki）
- 十四章检索来源：ArchWiki 中文《平铺窗口管理器对比》、维基百科《X 窗口管理器比较》、geek-blogs.com 平铺 WM 系列文；Stars 为 GitHub API 2026-09 快照
- 十四章新发掘 WM：ragnar、sxwm、howm、zwm、Hypr（hyprwm，与 Hyprland 区分）、wmderland、chamferwm、miracle-wm、dvtm、komorebi/glazewm/paneru/rift/nog（Rust 非 X11 平台）
- 十四章深查补充（2026-09）：`dynamic window manager` 关键词补齐 [dwm](https://dwm.suckless.org/) 族（FrankenWM/modwm/adwm/katriawm）与 Rust X11 长尾（mwm/hadlock/pgwm/lanta/marswm）；依赖核验依据各仓库 README/PKGBUILD（见 `#### 5.1`）
# b7-260917 | src/bin/input.sh 脚本作用分析

## 一、input.sh 脚本分析

### 1、概述

X11 输入设备配置生成脚本。物理 HDMI 模式（`HEADLESS=false`）下，由 `xvnc2.sh:13`（xorg 分支）在启动 Xorg 前调用（`sudo bash /usr/local/bin/input.sh`）。

- **路径**：`src/bin/input.sh`（容器启动时挂载到 `/usr/local/bin/`）
- **产物**：`/etc/X11/xorg.conf.d/10-input.conf`
- **幂等**：先 `rm -f` 再重建，重启容器自动生效

### 2、脚本内容（三段）

#### 1、ServerFlags：关闭自动探测

```bash
Section "ServerFlags"
     Option "AutoAddDevices" "False"
EndSection
```

容器为 `privileged + /dev 直通`，Xorg 能看到宿主全部输入设备。`AutoAddDevices False` 禁止 Xorg 自动探测，改为显式声明，规避自动探测导致的键鼠识别错乱。

#### 2、Mouse0：基础鼠标兜底

```bash
Section "InputDevice"
	Identifier  "Mouse0"
	Driver      "mouse"
	Option	    "Protocol" "auto"
	Option	    "Device" "/dev/input/mouse0"
EndSection
```

传统 `mouse` 驱动 + `/dev/input/mouse0`，保证基础鼠标可用。

#### 3、逐设备声明：evdev 显式加载

```bash
ls event* | grep -v event7 | while read input; do
    Section "InputDevice"
    Identifier "$input"
    Option "Device" "/dev/input/$input"
    Option "AutoServerLayout" "true"
    Driver "evdev"
    ...
```

遍历 `/dev/input/event*`，为每个设备生成独立 `InputDevice` 段落（`AutoServerLayout true` 自动加入布局）。

### 3、踩坑史（注释依据）

| 坑 | 处理 |
|----|------|
| 顶部 `exit 0`（默认模式）→ s11 键盘不能用，容器 tty2/tty7 全废 | 禁用 exit，改显式逐设备声明 |
| `event7` 是 touchPad，加载它 → 键鼠**全卡死**（即使先停 lightdm） | `grep -v event7` 排除 |
| `DontVTSwitch`（禁 ctrl+alt+fx 切屏）、`GrabDevice`、`DontZap` | 曾考虑开启，现注释掉（副作用大） |

### 4、一句话总结

容器内 Xorg 面对宿主全部输入设备时，用 `AutoAddDevices False + 逐设备 evdev 声明` 精确控制加载范围，规避自动探测导致的键盘/触摸板失灵。

## 二、udev 自动识别可行性分析（AutoAddDevices on）

> 议题：容器内置 udev 服务后，input.sh 是否可不再调用，让 Xorg 自动识别设备（含热拔插）？

### 1、理论机制

Xorg 自动识别 + 热拔插 = `AutoAddDevices on`（默认值）+ 容器内 udevd 稳定运行（Xorg 经 libudev 枚举 `/dev/input/event*` 并监视插拔事件）。两条件满足时，input.sh 可退役。

### 2、历史实测反例（docs/b3-260518-multiDesk.md）

| 时间 | 实验 | 结果 |
|------|------|------|
| 260518 12:00 | input.sh 顶部 `exit 0`（= 无配置 = AutoAddDevices 默认 on） | s11 键盘全废，容器 tty2/tty7 全不能用（b3:32） |
| 260519 | 自动加载 event7（touchPad） | 键鼠全卡死，即使先停 lightdm（b3:302） |
| 260520 14:50 | AutoAddDevices=False + InputDevice+synaptics | 触摸板才可用（b3:374） |
| 260520 | 当时结论 | `TODO: udev 未挂到容器内`（b3:384）——当初必须手动声明设备的直接原因 |

### 3、当前仍未满足的两个前提

- **udevd 未完全跑通**：b3:166 记录 `service udev start 方可; xvnc2.sh 当前直接启 systemd-udevd 方式暂还不行`；xvnc2.sh:42-43 自述副作用——pulse 失败重试致 sysd-udev 多进程累加（机器卡）、进而 tty7 触摸左键单机失效
- **s11 触摸板 libinput 自动模式实测失败**：b3:388 `ubt22: libinput/evdev:bad`，仅 `Driver "synaptics" + SoftButtonAreas` 显式声明可用；而 AutoAddDevices on 时 Xorg 走 40-libinput.conf 默认匹配

### 4、建议路径（渐进，勿一步删除）

1. **先修 udevd 稳定性**：解决 xvnc2.sh 注释中的多进程累加（lock 防重入、sv 单实例），确保 `sv s /etc/perp/xN-udev` 稳定 up
2. **用 InputClass 精细匹配替代全禁**：去掉 `AutoAddDevices "False"`，触摸板改用
   ```xorg
   Section "InputClass"
       Identifier "touchpad-synaptics"
       MatchIsTouchpad "on"
       Driver "synaptics"
       Option "SoftButtonAreas" "50% 0 82% 0 0 0 0 0"
   EndSection
   ```
   键盘/鼠标走自动（支持热拔插），触摸板仍走 synaptics，兼顾两者
3. **逐机器实测**：weipai-s11（synaptics 依赖）、genMachine（amdgpu）、ap34 各验键盘/触摸/热拔插，再决定是否删除 input.sh

### 5、结论

udev 服务"内置"≠"稳定可用"；且 s11 触摸板在自动（libinput）模式下为已知死路。直接删 input.sh 大概率复现键盘全废/触摸板卡死。推进方向应为「InputClass 替代全禁 + 先稳定 udevd」。




### 260518 11:20|weipai-s11-deb9调试多tty启动(deb9-bunsen桌面在tty7已跑:Xorg-0)

- ref deb9.ali-mirror `http://mirrors.aliyun.com/debian-archive/debian`
  - fk-jackyzy823-fxa-selfhosting//single/entry.sh
  - docker-x11base//distros/src/oth/Dockerfile.apt-debian
  - quickstart-actions//data/press-builder/Dockerfile.deb9
  - dotfiles//docs/250920-perl-asbru.md
- sys-vers
  - debian7-kx-xorg1.12
  - debian8-kx-xorg1.16
  - debian9-k4.9-xorg1.19(7.7) `touchPad:inputDevice.synaptics`
  - ubuntu20-k5.4-xorg1.20(7.7) `touchPad:inputDevice.synaptics[ubt20/22/24]`
- sys-glibc https://distrowatch.com/table.php?distribution=ubuntu #ubuntu/debian
  - ubt26-2.43|ubt24-2.39|**ubt22-2.35|ubt20-2.31|ubt18-2.27**|ubt16-2.23|ubt14-2.19|`ubt12-2.15|ubt10-2.11@2010|ubt8-2.7|ubt6-2.3@2006`
  - deb13-2.41|**deb12-2.36|deb11-2.31|deb10-2.28**|deb9-2.24|deb8-2.19@2015|deb7-2.13@2013`|deb6-2.11@2011|deb5-2.7@2009|deb4-2.3@2007|deb3-2.2@2002|deb2-2.0@1998`
  - vers
    - node24|2.28+
    - opencode-1.15.10|2.17+ `strings /_ext/opencode |grep GLIBC_ |sort -V`
    - ubt18-2.27/deb10-2.28
    - ubt20-2.31/deb11-2.31
    - ubt22-2.35/deb12-2.36

```bash
# insDocker.sh升级Docker: deb9-apt-docker-ce17.12不能下载到docker-hdmi-desktop相关tag镜像, 升级docker-20.10.24后可以
# entry.sh并行桌面在tty2启动: sudo Xorg :1 &; export DISPLAY=:1
  1.vid: 可在tty2启动，图像加载正常,键盘可用,触摸板暂不能用; (mice/mouse0未加载到input?)
  2.aud: pulse-control能显示"HDA intel PCH"设备, 但play ~/3476.mp3无音(deb9-bunsen桌面是可以的; 容器内aplay-L可识别设备)

# 12:00调试touchMouse
  1.input.sh顶部直接exit0不做conf指定:# exit 0 #默认模式:会导致s11的键盘也不能用<容器tty2/tty7全不能用了..>
  2.强制重启后,stop lightdm; dcp start; #修正input.sh-exit0再退lightdm, dcp-start也卡死?
  3.再启试:stop lightdm; ct容器开始在跑/但xorg未启成功; 
     手动进入启Xorg-:1及startxfce4/openbox-session:前者也不能用鼠标/后者headless下跑的:无显?; 
     再kill/start容器; 可进到openbox-session环境:键盘可用/touch鼠标不行(tty4显示了,不在tty2)
  4.touchMouse不兼容ubt24-Xorg?(有一堆特性提示kernel需>4.16); DO:换usb鼠标尝试=>晚上:usb鼠标可用

# 14:50-15:35-16:15|xorg-try2 键鼠切换控制
  0.指定tty: #Xorg :1 vt8
  1.novtswitch/DontVTSwitch不能设定,导致ctl+alt+fx不可切换
  #entry.sh|#sudo Xorg :1 vt8 -novtswitch &
  #input.sh|#Option "DontVTSwitch" "on"
  #宿主机xorg-lightdm有设定novtswitch(仍可切换,why?)|/usr/lib/xorg/Xorg :0 -seat seat0 -auth /var/run/lightdm/root/:0 -nolisten tcp vt7 -novtswitch
  3.hdmi-desk.TODO: chvt@kbd / nmcli@network-manager的安装

# 260519 10:00|docker-hdmi-desktop:core-debian-8尝试(昨晚编译)=> Xorg :1启动err(no screen found)
# 260519 10:20|play ~/3*.mp3音频播放OK; 
   12  2026-05-19 10:15:31 pactl unload-module module-alsa-sink #plughw:0,3做卸载(/entry.sh尾部默认自动加载之:对应HDMI的默认输出口[card0,device3])
   13  2026-05-19 10:15:35 pactl load-module module-alsa-sink device=plughw:0,0 #非HDMI,指定第一个即可(重启后不做lightdm登录,免设备被bunsen桌面占用)
  # 11:20|lightdm-session命令行退出
  # loginctl
    loginctl list-sessions
    loginctl terminate-session xx; #bunsen桌面-headless下跑Xorg导致替显黑屏?: c1-lightdm杀后还未释放, 2号也kill才恢复到lightdm-login页; 4号:tty5控制台;
  # dm-tool
    dm-tool switch-to-greeter #需在X环境下执行

# oth1: tty8/9容器xorg多跑后, tty7-lightdm休眠锁定卡lock图标=>电源管理免休眠锁定即可(0519-dseek查资料时有提及)
#################################
# 260520 11:40|ref deb9-bunsen//usr/share/X11/xorg.conf.d/; event0/event7单独调试=>touchOK
#   0.tty7-lightdm-bunsen桌面: 不用停,event0/7可在两边切换;
#   1.event7挂上后deb9.pulseaudio异常: dbus org.pulsAudio1占用??
#   2.deb9.tty9停=>ubt22.tty8启: libinput/evdev/synaptics全不行了.. [ubt22不行:因未更新image,不带xserver-xorg-input-synaptics驱动] (0521shangwu:deb12-touch可用)
#   3.12:50=>#  Option "AutoAddDevices" "False" ##注释之,免影响InputClass的动态加载(dseek: 设False则InputClass匹配规则失效)
#   4.14:50=> AutoAddDevices=False, InputDevice+synaptics: [ubt20/22/24]可以用touch板了! (前者为新pull, 后两者需pull更新image)
#   5.tty8.ubt/tty9.deb9多跑: pulghw:0,0声卡被deb9抢占,需停之再重启ubt容器即可


# TODO
  1.容器内基于lightdm做桌面加载
  2.xfce4-power-manager|容器内电源管理(0519-try1:启动无tray图标)
  3.network-manager|网络连接<cur:deb9-bunsen桌面控制的wifi连接; TODO:配置写死/nmcli操作>(network-manager安装,同上1条:都依赖dbus) `/entry.sh add: dbus-daemon --system --nofork &`

```

### 0529周五|x11vnc验证

> 0529上午, entry更名entrypoint2; 新加entry-x11base.sh<Xorg+ssh/xrdp/noVnc的结合>

- 下午|intel.weipai-s11, x11vnc调试

```bash
# 昨晚/今早?: genMachine_headless_dev环境下,手动下载运行x11dev: win10_vncviewer可显可控;
# 15:50|黑屏验证: /_ext/x11vnc从deb9内拷贝,手动运行
#  0.中午1:30(还未休)：noVnc_52081黑屏/鼠标可控; deb9_bunsen_remmina_5902一样情况
#  1.deb9-bunsen环境跑: 可显
#  2.ct-hdmi-xorg: deb9/ubt22黑屏; xhost +;再启x11vnc也黑屏
#  3.ct-hdmi-Xvnc: ubt22> x11vnc-5903可显可控(有ibus-rime?)
# 

# ubt22-xorg.TODO: xorg-scrap组件??|x0vncserver也黑屏
  # ubt-x0vncserver
    apt install tigervnc-standalone-server
    apt install tigervnc-scraping-server #x0vncserver 
    x0vncserver -rfbport 5903 #启动需设定6位密码, remmina_5902按密码连接后也黑屏;(ps -ef; perl脚本>X0tigervnc)
    # 01: x0vncserver.headless跑> 换root下跑:也是黑屏
    # 02: apt install x11vnc; 用安装版(跑5902端口,/_ext/arg1.txt全参数), 也是黑屏
      x11vnc -display :2 -rfbport 5902 -forever -loop -noxdamage -repeat -shared -capslock -nomodtweak

  # oe2203|ref jdus-arch-draft/2026/05-0202-x11vnc-build.md
    35  dnf install tigervnc-server #装它才有;内带x0vncserver
    # https://cloud.tencent.com/developer/article/1860273
    vncpasswd  vnc.pass.file
    x0vncserver -PasswordFile=./vnc.pass.file -AlwaysShared=on -AcceptPointerEvents=off -AcceptKeyEvents=off
    x0vncserver -PasswordFile=./vnc.pass.file -AlwaysShared=on ##启用kb,mouse; vncviewer键鼠ok; xrdp键鼠也ok


```

- 晚上|amd.genMachine, x11vnc调试

```bash
# 20:35, 11.07:dbg01
  # 1. x11vnc|noVNC可显, xrdp暂不行; (glxinfo显示vendor:AMD, 但明细还是纯Mesa信息) ==>0530.9:20|x11vnc-shared免独占
    # xrdp暂不行:细看无log，TODO.apt安装与static版做对比(关novnc,ubt_dev4可连,免独占即可);
  # 2. vid|换xfce4-session可动态改分辨率(openbox-session.TODO: dbus?)==>dseek:是这样,TODO.deb9-bunsen的实现; ==> 运行xfsettingsd即可
  # 3. aud|TODO: pulseaudio/pavucontrol未就绪, pactl操作connReject(相比static静编版,sock路径?) ==> fix:#-n取默认即出Dummy; device=plughw:0,3(现在hdmi屏:aplay-l无音频?=>0530.9:20|加用户组:usermod -a -G audio $u1)
  # 4. lang|xfce4下不显示中文==> fix:entry-x11base内不要删emoji文件
  # 5. ibus|ubt22二次进入后，中文wubi/pinyin可直接用==> fix:上1条fix后,ubt22首进直接zh可用的;

```

### 0531周日|

- ct-hdmi-TODO|0531-16:40
  - powerManager:~~点击管理器>运行实例后，可托盘设定@genM~~
  - lightdm
    - 启动配置脚本/手动设定
    - 在已有Xorg环境下运行
  - sysd-udev
    - ~~pulseaudio设备自动探测/免手动指定~~
    - networkManager接管wifi特定网卡设备: ~~轻量net管理工具~~, dcp.多卡先行验证
  - vid/aud `amd.ok, intel.TODO黑屏/驱动与内核需对应`
    - ~~0601上午|intel.apt34: x11vnc可显~~
    - Xorg.Dummy_xvnc + 物理屏幕Mirror/即插即显
    - aud本地播放/xrdp-sink + parec
  - input:kb/mouse
    - gMachine盒子:~~x11vnc远程操作免键鼠~~
    - wepaiS11本子:本地kb/touch,~~udev_id_path匹配~~

```bash
# ff.dseek"Shell let加法用法": 
  # 00.tini-perpd
  #   nitro vs perpd; (nitro无日志管理/dep依赖弱 + s6组合)
  #   runit.svlogd vs perpd.tinylog
  # 01.sysd-netd默认/netManager默认未装
  #   netplay[yaml] + systemd-networkd(/etc/systemd/network/xx.network)/NetworkManger(nmcli/nmtui)
  # 02.deps:dbus/polkit/udev
  #   system-dbus(netMgr,sysd,udev) vs session-dbus
  #   dbus[ubt1204开始集成]/polkit[已装未激活]/udev[已装+激活]
# 0601  8:10|intel.apt34: x11vnc可显
# 0601  9:00|distroRef: peppermint,antix,puppy
# 0601 10:10|udev
  mkdir -p /run/udev #无时/etc/init.d/udev脚本有检测
  service udev start #调用/lib/systemd/systemd-udevd
  # 1.之后sv restart x1-pulse; pulse可自动检测到可用的HDMI_Input/Output

# udev:
  /usr/lib/systemd/systemd-udevd #/lib -> /usr/lib
  /etc/init.d/udev
  /run/udev

# pulse
  启了udev后，直接可激活可和的音频口 
  pavucontrol最后页:有配置项列表了
  # 注: service udev start方可; xvnc2.sh当前直接启systemd-udevd方式暂还不行;

# 0601 22:45|netManager
  1.启动:之前宿主机网首启OK，之后试改bridge网则不行了:ret1/无errLog ==>需启了dbus才可启(rm -f /run/dbus/pid)
  2.管理UI: 
    nm前端: nm-applet<network-manager-gnome:40M+>, nm-tray.qt.lite<编辑:xterm.nmtui-edit>; 
    connman+cmst: connmand/connmanctl + wpasupplicant.wifi; 2.6M.lite;
    wicd: wicd.py2.ubt16/18才有(独立后端:wicd-daemon,无nm依赖); 

# 0602 9:30|weipai_s11-x11vnc-try2
  0.新img-ctRecreate还是黑屏
  1.机器重启,关lightdm,启tty9:本地firefox-115esr:可查看到vnc界面<img.loop>
  2.启lightdm到tty7,firefox-128esr:还是黑屏,倒回tty9:vnc还可看到
  3.同机查看影响?:换手机远程ip:52081,查看也是黑屏
  # power|xf-power-manager启实例/显trayIcon:可正常显示图标,调亮度:无反应/console有warn;
  # xfsettingsd|已跑; deb9-bunsen:无xf-display-manager/xfsettingsd;
  # udev|service udev start后; 不用sv restart x2-pulse;自动可寻得新out/in设备;
  # x11vnc|ap34.deb950()>s11.deb920(4.9.0-4-amd64)内核差异?(否): TODO.ali-archive-repo升级内核:sudo apt install linux-image*amd64
    linux-image-4.9.0-19-amd64
    linux-image-4.19.0-0.bpo.19-amd64

# 0603 8:57|xorg-tty9非激活时,xorg休眠/x11vnc黑屏; ref src/xvnc2.sh
    exec x11vnc -display :$offsetLimitIndex -rfbport $port1 -rfbauth /etc/xrdp/vnc_pass -forever -shared -capslock   -nomodtweak -noxdamage  -noshm  -noxrecord
    # x11vnc -display :32 -forever
    # x11vnc -forever -loop -repeat -shared -capslock -nomodtweak -noxdamage -rfbport 5900
    # x11vnc -forever -loop -repeat -shared -capslock -nomodtweak -noxdamage -rfbport 5900 -auth guess -rfbauth ~/.vnc/passwd
      # blackScreen tty-switchd, dseek: -noxrecord[加与不加:手机ip:52081查看,tty9激活时可看屏/出tty9则都黑屏]; -rawfb /dev/fb0 [always black]

  # 9:30|alpine
    3.13-xorg1.20.11: 切换到tty9时会crash(导致tty7.lightdmSession也重置),手动Xorg :2 vt9效果一样
    3.14
    3.19-xorg1.21.1.16: Xorg启正常; kb可用/mouse暂不行;
  # 16:25@genM@home
    1. ubt20: xorg-err /usr/lib/dri/radeonsi_dri.so找不到
    2. alpine313/314: xorg-err Error loading shared library libEGL.so.1: No such file [apk add mesa-egl]; 316/319/323已带mesa-egl
    # alpine313.无sakura,其它OK; DO:alpine.musl-locale.zh_CN??=>从deb/ubt拷贝/usr/share/locale即可
    # eudev启动, pulse还不可用; TODO.拷贝ubt.pulse的udev规则

# 0604 11:43|ubt-vers细化
  1. ubt24-big 1.7g+; pkg.800+(ubt22:600+)
  2. ubt20/22/24: net-mgr-gnome带入整个gnome桌面依赖; ubt20.ibus-rime.err(ubt22.ok)
  3. ubt18:上1条不会; ibus-rime.ok; ubt22.nm-applet就绪(ubt18/20未就绪conning)
  4. deb11: xfce-4.16?; net-mgr-gnome不会带入整个依赖

```

## 附

### 0518-input.sh-1

```bash
# create new input device file
cat > $conf <<_EOF_
Section "ServerFlags"
     #ff-hdmi-ref.exists
     Option "AutoAddDevices" "False"
     
     #禁止快捷键切屏(ctl+alt+fx)
     #Option "DontVTSwitch" "on"
     #强制焦点独占，失焦释放
     #Option "GrabDevice" "on"
     #防ctl+alt+backspace杀掉Xorg 
     #Option "DontZap" "on"
EndSection
_EOF_


# weipai-s11-touchMouse|dseek.ask|加后xorg不可启..
# cat >> $conf <<_EOF_
#     Section "InputClass"
#     Identifier "Event Mouse"
#     Driver "evdev"
#     Option "Device" "/dev/input/by-path/pci-0000:00:16.2-platform-i2c_designware.2-event-mouse"
# EndSection
# _EOF_
# 
# 260519 10:50|try2自动加载触摸板到容器=>加上无影响,但touchPad也不能用
cat >> $conf <<_EOF_
##try1:libinput######################
# ref dseek's: synaptics> libinput; 指定event7还是不行
# Section "InputClass"
#     Identifier "My Touchpad"
#     MatchIsTouchpad "on"
#     Driver "libinput"
#     #Option "NaturalScrolling" "on"
#     #Option "Tapping" "on"
#     Option "Device" "/dev/input/event7"
# EndSection

##try3:mice######################
# ref cat /_ext/xorg.conf.new-hostBunsen |grep -i mice -C 5 ##Xorg :2 -configure生成之
Section "InputDevice"
	Identifier  "Mouse0"
	Driver      "mouse"
	Option	    "Protocol" "auto"
  #mice/mouse0
	Option	    "Device" "/dev/input/mouse0"
	# Option	    "ZAxisMapping" "4 5 6 7"
EndSection

##try2:synaptics######################
# ref deb9-bunsen:/usr/share/X11/xorg.conf.d/70-synaptics.conf
#   ct-hdmi: xinput list; 还是无/apps.xf-mouse-settings也无
#   mv /usr/share/X11/xorg.conf.d/40-libinput.conf-bk
# Section "InputClass"
#         Identifier "touchpad catchall"
#         Driver "synaptics"
#         MatchIsTouchpad "on"
#         MatchDevicePath "/dev/input/event*"
# EndSection
# Section "InputClass"
#         Identifier "touchpad ignore duplicates"
#         MatchIsTouchpad "on"
#         MatchOS "Linux"
#         MatchDevicePath "/dev/input/mouse*"
#         Option "Ignore" "on"
# EndSection

# This option is only interpreted by clickpads.
# Section "InputClass"
#         Identifier "Default clickpad buttons"
#         MatchDriver "synaptics"
#         Option "SoftButtonAreas" "50% 0 82% 0 0 0 0 0"
#         Option "SecondarySoftButtonAreas" "58% 0 0 15% 42% 58% 0 15%"
# EndSection
# This option disables software buttons on Apple touchpads. # This option is only interpreted by clickpads.
# Section "InputClass"
#         Identifier "Disable clickpad buttons on Apple touchpads"
#         MatchProduct "Apple|bcm5974"
#         MatchDriver "synaptics"
#         Option "SoftButtonAreas" "0 0 0 0 0 0 0 0"
# EndSection
_EOF_

cd /dev/input
#for input in event* do
# 当前启动后event7为touchPad, 上一段落打开时, 本处如再使用event7:会导致键鼠全卡死(即使新启时stopped lightdm)
ls event* |grep -v event7 |while read input; do
cat >> $conf <<_EOF_
    Section "InputDevice"
    Identifier "$input"
    Option "Device" "/dev/input/$input"
    Option "AutoServerLayout" "true"
    Driver "evdev"
EndSection
_EOF_
done

```

### 0518-input.sh-2

```bash
# $ cat /proc/bus/input/devices   |egrep "Name|Handler"
# N: Name="AT Translated Set 2 keyboard"
# H: Handlers=sysrq kbd leds event0 
  # N: Name="Intel HID events"
  # H: Handlers=kbd event1 rfkill 
  # N: Name="Lid Switch"
  # H: Handlers=event2 
  # N: Name="Power Button"
  # H: Handlers=kbd event3 
  # N: Name="Video Bus"
  # H: Handlers=kbd event4 
  # N: Name="PC Speaker"
  # H: Handlers=kbd event5 
  # N: Name="USB 2.0 Camera"
  # H: Handlers=kbd event6 
# N: Name="SYNA3602:00 0911:5288 Touchpad"
# H: Handlers=mouse0 event7 
# # N: Name="HDA Intel PCH Mic"
# # H: Handlers=event8 
# # N: Name="HDA Intel PCH Headphone"
# # H: Handlers=event9 
# # N: Name="HDA Intel PCH HDMI/DP,pcm=3"
# # H: Handlers=event10 
# # N: Name="HDA Intel PCH HDMI/DP,pcm=7"
# # H: Handlers=event11 
# # N: Name="HDA Intel PCH HDMI/DP,pcm=8"
# # H: Handlers=event12
test -d /usr/share/X11/xorg.conf.d && mv /usr/share/X11/xorg.conf.d /usr/share/X11/xorg.conf.d-bk
cat > $conf <<_EOF_
Section "ServerFlags"
    # 设置false, event7:InputDevice.Driver=synaptics才有效(注释之:即使上2条mv了,也导致InputDevice不能注册上event7)
    Option "AutoAddDevices" "False"
EndSection
Section "InputDevice"
    Identifier "kb event0"
    Option "Device" "/dev/input/event0"
    Option "AutoServerLayout" "true"
    Driver "evdev"
EndSection

##00-keyboard.conf #dseek.for_xfce4_session=>none.effect || setxkbmap@opbox/autostart
# Section "InputClass"
#     Identifier "Keyboard Defaults"
#     MatchIsKeyboard "on"
#     Option "XkbRules" "evdev"
#     Option "XkbModel" "pc105"
#     Option "XkbLayout" "us"
# EndSection

#################################
# 260520 11:40|ref deb9-bunsen//usr/share/X11/xorg.conf.d/; event0/event7单独调试=>touchOK
#   0.tty7-lightdm-bunsen桌面: 不用停,event0/7可在两边切换;
#   1.event7挂上后deb9.pulseaudio异常: dbus org.pulsAudio1占用??
#   2.deb9.tty9停=>ubt22.tty8启: libinput/evdev/synaptics全不行了.. [ubt22不行:因未更新image,不带xserver-xorg-input-synaptics驱动]
#   3.12:50=>#  Option "AutoAddDevices" "False" ##注释之,免影响InputClass的动态加载(dseek: 设False则InputClass匹配规则失效)
#   4.14:50=> AutoAddDevices=False, InputDevice+synaptics: [ubt20/22/24]可以用touch板了! (前者为新pull, 后两者需pull更新image)
#   5.tty8.ubt/tty9.deb9多跑: pulghw:0,0声卡被deb9抢占,需停之再重启ubt容器即可
#################################
# deb9: InputDevice.ok; InputClass.bad
# Section "InputClass"
Section "InputDevice"
        Identifier "touch event7-12"
        # MatchIsTablet "on"
        # MatchDevicePath "/dev/input/event7"
        Option "Device" "/dev/input/event7"
        # TODO: udev未挂到容器内.
        # Option "Device" "/dev/input/by-path/pci-0000:00:16.2-platform-i2c_designware.2-event-mouse"
        # 
        # deb9: libinput/evdev:bad; synaptics:ok
        # ubt22:libinput/evdev:bad; synaptics:bad [InputDevice,InputClass全一样]=>驱动?
        # Driver "libinput"
        # Driver "evdev"
        Driver "synaptics"
        # for左右按键(不带:则只能移动/单点选择); ubt22:无时可左双击/无右键
        Option "SoftButtonAreas" "50% 0 82% 0 0 0 0 0" #单开此行:ubt右键ok; tty7不会出现单击不可用(之前两项全开:最初可以/近3天不行@260611)=>pulse.fail.udev频设定导致
        Option "SecondarySoftButtonAreas" "58% 0 0 15% 42% 58% 0 15%"
EndSection

# copy2 test: deb9-还是无效
# Section "InputClass"
#         Identifier "libinput pointer catchall"
#         # MatchIsPointer "on"
#         # MatchIsTouchpad "on"
#         MatchDevicePath "/dev/input/event7"
#         # Driver "libinput"
#         Driver "evdev"
#         # Driver "synaptics"
# EndSection


# 260529:weipai-s11--intel.i915(xserver-xorg-video-intel, all内不含)==>TODO.xorg不配置时,可自动匹配?
#==10-amdgpu.conf
# Section "OutputClass"
# 	Identifier "AMDgpu"
# 	MatchDriver "amdgpu"
# 	Driver "amdgpu"
# EndSection

# sam @ debian in /usr/share/X11/xorg.conf.d |10:54:24  
# $ ls /usr/share/X11/xorg.conf.d/* |while read one; do echo -e "\n#==$one"; cat /usr/share/X11/xorg.conf.d/$one |egrep -v "^#|^$" ; done
#==10-amdgpu.conf
# Section "OutputClass"
# 	Identifier "AMDgpu"
# 	MatchDriver "amdgpu"
# 	Driver "amdgpu"
# EndSection

#==10-evdev.conf
# Section "InputClass"
#         Identifier "evdev pointer catchall"
#         MatchIsPointer "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "evdev"
# EndSection
# Section "InputClass"
#         Identifier "evdev keyboard catchall"
#         MatchIsKeyboard "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "evdev"
# EndSection
# Section "InputClass"
#         Identifier "evdev touchpad catchall"
#         MatchIsTouchpad "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "evdev"
# EndSection
# Section "InputClass"
#         Identifier "evdev tablet catchall"
#         MatchIsTablet "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "evdev"
# EndSection
# Section "InputClass"
#         Identifier "evdev touchscreen catchall"
#         MatchIsTouchscreen "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "evdev"
# EndSection

#==10-quirks.conf
# Section "InputClass"
#         Identifier "ThinkPad HDAPS accelerometer blacklist"
#         MatchProduct "ThinkPad HDAPS accelerometer data"
#         Option "Ignore" "on"
# EndSection
# Section "InputClass"
#         Identifier "Xen Virtual Pointer axis blacklist"
#         MatchProduct "Xen Virtual Pointer"
#         Option "IgnoreAbsoluteAxes" "off"
#         Option "IgnoreRelativeAxes" "off"
# EndSection
# Section "InputClass"
#         Identifier "Tag trackballs as XI_TRACKBALL"
#         MatchProduct "trackball"
#         MatchDriver "evdev"
#         Option "TypeName" "TRACKBALL"
# EndSection
# Section "InputClass"
#         Identifier "Tag Mionix Naos 5000 mouse XI_MOUSE"
#         MatchProduct "La-VIEW Technology Naos 5000 Mouse"
#         MatchDriver "evdev"
#         Option "TypeName" "MOUSE"
# EndSection

#==40-libinput.conf
# Section "InputClass"
#         Identifier "libinput pointer catchall"
#         MatchIsPointer "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "libinput"
# EndSection
# Section "InputClass"
#         Identifier "libinput keyboard catchall"
#         MatchIsKeyboard "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "libinput"
# EndSection
# Section "InputClass"
#         Identifier "libinput touchpad catchall"
#         MatchIsTouchpad "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "libinput"
# EndSection
# Section "InputClass"
#         Identifier "libinput touchscreen catchall"
#         MatchIsTouchscreen "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "libinput"
# EndSection
# Section "InputClass"
#         Identifier "libinput tablet catchall"
#         MatchIsTablet "on"
#         MatchDevicePath "/dev/input/event*"
#         Driver "libinput"
# EndSection

#==70-synaptics.conf
# Section "InputClass"
#         Identifier "touchpad catchall"
#         Driver "synaptics"
#         MatchIsTouchpad "on"
# EndSection
# Section "InputClass"
#         Identifier "touchpad ignore duplicates"
#         MatchIsTouchpad "on"
#         MatchOS "Linux"
#         MatchDevicePath "/dev/input/mouse*"
#         Option "Ignore" "on"
# EndSection
# Section "InputClass"
#         Identifier "Default clickpad buttons"
#         MatchDriver "synaptics"
#         Option "SoftButtonAreas" "50% 0 82% 0 0 0 0 0"
#         Option "SecondarySoftButtonAreas" "58% 0 0 15% 42% 58% 0 15%"
# EndSection
# Section "InputClass"
#         Identifier "Disable clickpad buttons on Apple touchpads"
#         MatchProduct "Apple|bcm5974"
#         MatchDriver "synaptics"
#         Option "SoftButtonAreas" "0 0 0 0 0 0 0 0"
# EndSection

#==70-wacom.conf
# ...
_EOF_

```
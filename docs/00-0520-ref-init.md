

- fk1 https://github.com/MarcelCoding/docker-desktop-hdmi
- fk2 https://github.com/schreinerman/rpi-nodered-dashboard-hdmi-docker
- repos
  - https://cr.console.aliyun.com/repository/cn-shenzhen/infrasync/v2025/images #sldev `registry.cn-shenzhen.aliyuncs.com`
  - https://console.qingcloud.com/docker_images/docker_repos #hua.e6 `dockerhub.qingcloud.com`
  - https://console.cloud.tencent.com/tcr/repository @q2219
    - ccr.ccs.tencentyun.com
    - hkccr.ccs.tencentyun.com
    - pw
      - https://console.cloud.tencent.com/tcr/?rid=5 `概况> 个人版> 更多> 重置登录密码` up1@250819
      - https://github.com/organizations/infrastlabs/settings/secrets/actions  `DOCKER_REGISTRY_TENCLOUD_USER/PASS` @tenvm2

### 1)imgs

```bash
# https://docker.13140521.xyz/r/ceph/ceph/tags #失效
# https://docker.cmliussss.net/_/docker/tags
# https://docker.cmliussss.net/r/balenalib

# x64, arm32
# https://docker.cmliussss.net/r/hilschernetpi/netpi-desktop-hdmi/tags
  # docker pull docker.io/hilschernetpi/netpi-desktop-hdmi:1.3.0
  # desktop-1  | exec /etc/init.d/entrypoint.sh: exec format error
  latest linux/arm 388.58 MB
  1.4.0 linux/arm 388.58 MB
  1.3.0 linux/amd64 351.06 MB #real: arm32?
  1.2.2 linux/amd64 234.37 MB #real: arm32?

# https://github.com/MarcelCoding/docker-desktop-hdmi
# https://github.com/marcelcoding/docker-desktop-hdmi/pkgs/container/desktop-hdmi/67486992?tag=edge
  docker pull ghcr.io/marcelcoding/desktop-hdmi:edge #linux/arm64
  docker pull docker.io/marcelcoding/desktop-hdmi:edge
    edge linux/arm64 237.02 MB

# https://github.com/schreinerman/rpi-nodered-dashboard-hdmi-docker
  ioexpert/armv6-nodered-dashboard-hdmi

# trans
  registry.cn-shenzhen.aliyuncs.com/infrasync/v2025:$ns--$img---$tag
  registry.cn-shenzhen.aliyuncs.com/infrasync/v2025:hilschernetpi--netpi-desktop-hdmi---1.3.0
```

### 2)Dockerfile

```bash
# fix1,2
 && addgroup input; adduser $USER input \
 && mkdir -p /etc/sudoers.d; echo $USER " ALL=(root) NOPASSWD:ALL" >> /etc/sudoers.d/$USER \

# fix3 apt -y> apt -yq;  >> 换到 FROM balenalib/amd64-debian:buster
  #9 80.03 Please select the layout matching the keyboard for this machine.

# fix4
#  && git clone --depth 1 https://github.com/raspberrypi/firmware
#  #11.98 mv: cannot stat '/tmp/firmware/hardfp/opt/vc': No such file or directory

# fix5
# # 5.793 E: Unable to locate package realvnc-vnc-server

```

### 3)Build

```bash
# ERR1: 换过cache名; drop",mode=max"; 都无效;  ##与docker版本有关??
ERROR: failed to solve: error writing manifest blob: failed commit on ref "sha256:276169ff9123e53dac3c98008c7e9cfb32a51eadb7855b72adf371e2fcca1145": unexpected status from PUT request to https://registry.cn-shenzhen.aliyuncs.com/v2/infrastlabs/docker-hdmi-desktop/manifests/hdmi-cache: 403 Forbidden
  # ubt20.04: gh.EOF

  # ubt22.04:
    Server: Docker Engine - Community
    Engine:
      Version:  28.0.4

# https://github.com/gfk-kube/fk-edgecore-indocke
  # gitac: ubt-latest
  jobs:
    build:
      runs-on: ubuntu-latest ##
  # docker-ver
  Server: Docker Engine - Community
  Engine:
    Version:  28.0.4
    API version:      1.48 (minimum version 1.24)

# 0521:
  # 转到ccr.tencentyun即可; https://console.cloud.tencent.com/tcr/repository/
  hkccr.ccs.tencentyun.com/infrastlabs/docker-hdmi-desktop:latest-cache
```


### 4)Run

#### 4.1) 0520|ap34's--hdmi-ipad4_01

- ap34's--hdmi-ipad4_01(xorg_root_run)

```bash
# Xorg:暂需sudo启;
# testuser@deb1013:/$ sudo /usr/bin/startx -- :0 
  # 1. 显示正常(console> Xorg; 长时待机关显; 拔了再插有显/换显示器无显;)
  # 2. 键鼠操作正常
  # 3. 多屏单独切换: 不重启无fb2; 重开Xorg:直接识别到第二屏(默认左右扩展模式); 
  # 4. 多屏同显: (如上1条); 重启后:依旧只有/dev/fb0(可双显); docker容器外挂entry:重建容器后,开机自动显示双屏~~

# info
  root@ap34:~# ls /dev/fb*
  /dev/fb0
  root@ap34:~# cd /dev/
  root@ap34:/dev# ls -lh fb* input snd* tty*
  ... #见附
```

- ap34--non-root(`root.Xorg+nonRoot.startxfce4`)

```bash
root@ap34:/# Xorg :0 &
  [1] 71
  root@ap34:/# 
  X.Org X Server 1.20.4
  X Protocol Version 11, Revision 0
  Build Operating System: Linux 6.1.0-20-amd64 x86_64 Debian
  Current Operating System: Linux ap34 4.18.0-0.bpo.1-amd64 #1 SMP Debian 4.18.6-1~bpo9+1 (2018-09-13) x86_64
  Kernel command line: root=/dev/mmcblk1p1 ro quiet
  Build Date: 15 April 2024  11:30:14AM
  xorg-server 2:1.20.4-1+deb10u14 (https://www.debian.org/support) 
  Current version of pixman: 0.36.0
    Before reporting problems, check http://wiki.x.org
    to make sure that you have the latest version.
  Markers: (--) probed, (**) from config file, (==) default setting,
    (++) from command line, (!!) notice, (II) informational,
    (WW) warning, (EE) error, (NI) not implemented, (??) unknown.
  (==) Log file: "/var/log/Xorg.0.log", Time: Sun May 25 12:11:32 2025
  (==) Using config directory: "/etc/X11/xorg.conf.d"
  (==) Using system config directory "/usr/share/X11/xorg.conf.d"
  (II) modeset(0): Initializing kms color map for depth 24, 8 bpc.


root@ap34:/# su - testuser
  testuser@ap34:~$ export DISPLAY=:0.0
  testuser@ap34:~$ xfce4-terminal
  testuser@ap34:~$ startxfce4 
  /usr/bin/startxfce4: X server already running on display :0.0

```


#### 4.2) 0521|genMachine--deb1013--ipad4

- 0520|genMachine--deb1013--未接屏

```bash
# TODO
  # 未接屏时开机: 新接屏>> genMachine开机后 不能显示上新加屏?? (deb1013, xbt.livecd都一样)

# ERR1
  desktop-1  | sudo: unable to resolve host deb1013: Name or service not known
  # dcp>> hostname: deb1013

# ERR2
  # /dev/fb0
  desktop-1  | sudo: unable to resolve host deb1013: Name or service not known
  desktop-1  | chmod: cannot access '/dev/fb0': No such file or directory
  desktop-1  | starting X on display 0 ...
  desktop-1  | hostname: Name or service not known
  desktop-1  | xauth: (stdin):1:  bad display name "deb1013:0" in "add" command

```

- genMachine--deb1013--ipad4

```bash
# 外接ipad4
root @ deb1013 in ~ |12:00:43  
$ ls /dev/fb* 
/dev/fb0

# 改接VOC屏:一样情况; >> 拔掉换ipad4屏:屏无信号,/dev/fb0设备还在;
root @ deb1013 in .../apps/docker-hdmi-desktop |12:08:24  |sam-custom ✓| 
$ ls /dev/fb*
/dev/fb0

# ERR1
Fatal server error:
(EE) Cannot run in framebuffer mode. Please specify busIDs  for all framebuffer devices
```

- TRY01.DRIVER

```bash
# TRY01.DRIVER
root @ deb1013 in ~ |11:48:14  
# $ apt install xorg  
  Need to get 32.5 MB of archives.
  After this operation, 54.5 MB of additional disk space will be used.

# $ apt install xserver-xorg-video-all
  Need to get 18.5 MB of archives.
  After this operation, 31.4 MB of additional disk space will be used.

# apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev
  # $ apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev
  Need to get 13.9 MB of archives.
  After this operation, 21.7 MB of additional disk space will be used.

  # --no-install-recommends: 13.9 MB> 7373 kB
  # $ apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev --no-install-recommends
  Need to get 7373 kB of archives.
  After this operation, 13.3 MB of additional disk space will be used.


# cmds
  5300  2025-05-21 11:52:24 apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev --no-install-recommends
  5301  2025-05-21 11:53:59 apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev 
  5302  2025-05-21 11:54:44 apt install xserver-xorg-video-all
  5303  2025-05-21 11:55:51 apt install xorg       
  5304  2025-05-21 11:58:46 which Xorg 
  5308  2025-05-21 12:00:43 /usr/bin/Xorg :1

# root @ deb1013 in ~ |12:00:38  
$ /usr/bin/Xorg :1    
  X.Org X Server 1.20.4
  X Protocol Version 11, Revision 0
  Build Operating System: Linux 6.1.0-20-amd64 x86_64 Debian
  Current Operating System: Linux deb1013 4.19.0-21-amd64 #1 SMP Debian 4.19.249-2 (2022-06-30) x86_64
  Kernel command line: BOOT_IMAGE=/boot/vmlinuz-4.19.0-21-amd64 root=UUID=0eca2d6c-1453-4c38-bb8c-536cdd5fe521 ro quiet apparmor=0
  Build Date: 15 April 2024  11:30:14AM
  xorg-server 2:1.20.4-1+deb10u14 (https://www.debian.org/support) 
  Current version of pixman: 0.36.0
    Before reporting problems, check http://wiki.x.org
    to make sure that you have the latest version.
  Markers: (--) probed, (**) from config file, (==) default setting,
    (++) from command line, (!!) notice, (II) informational,
    (WW) warning, (EE) error, (NI) not implemented, (??) unknown.
  (==) Log file: "/var/log/Xorg.1.log", Time: Wed May 21 12:00:43 2025
  (==) Using system config directory "/usr/share/X11/xorg.conf.d"
  (EE) 
  Fatal server error:
  (EE) Cannot run in framebuffer mode. Please specify busIDs  for all framebuffer devices
  (EE) 
  (EE) 
  Please consult the The X.Org Foundation support 
    at http://wiki.x.org
  for help. 
  (EE) Please also check the log file at "/var/log/Xorg.1.log" for additional information.
  (EE) 
  (EE) Server terminated with error (1). Closing log file.
```

- TRY02.BUSID.CONF
  - https://blog.csdn.net/luowei505050/article/details/130234887 `2023-04-19=零刻EQ 12pro 安装PVE_零刻eq12安装pve-CSDN博客`
  - https://forum.proxmox.com/threads/generic-solution-when-install-gets-framebuffer-mode-fails.111577/ `EQ12.Greenwatts@Apr 8, 2023; /usr/share/X11/xorg.conf.d/driver-nvidia.conf==Generic Solution when install gets FrameBuffer Mode Fails | Proxmox Support Forum`

```bash
# TRY02.BUSID.CONF
  https://blog.csdn.net/luowei505050/article/details/130234887
  https://forum.proxmox.com/threads/generic-solution-when-install-gets-framebuffer-mode-fails.111577/
  # lspci| grep -i vga 
  # /usr/share/X11/xorg.conf.d/driver-nvidia.conf
  Section "Device"
      Identifier "Card0"
      Driver "fbdev"
      BusID "pci0:01:0:0:"
  EndSection

####################
root @ deb1013 in ~ |13:48:19  
  $ ls /dev/fb*
  /dev/fb0
  root @ deb1013 in ~ |13:48:22  
  $ lspci| grep -i vga  ##04:00.0
  04:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Device 164c (rev c1) #host: ati也有装，如下
  $ dpkg -l |grep ati |grep video
  ii  xserver-xorg-video-ati       1:19.0.1-1      amd64  X.Org X server -- AMD/ATI display driver wrapper

root @ deb1013 in ~ |13:49:10 
  $ ls /usr/share/X11/xorg.conf.d/
    10-amdgpu.conf  10-quirks.conf  10-radeon.conf  40-libinput.conf  70-wacom.conf
  $ cat /usr/share/X11/xorg.conf.d/10-amdgpu.conf 
  Section "OutputClass"
    Identifier "AMDgpu"
    MatchDriver "amdgpu"
    Driver "amdgpu"
  EndSection

# BusID "pci0:01:0:0:">> BusID "pci0:04:0:0:"
mkdir -p /usr/share/X11/xorg.conf.d/
touch /usr/share/X11/xorg.conf.d/driver-fbdev.conf
cat > /usr/share/X11/xorg.conf.d/driver-fbdev.conf <<EOF
Section "Device"
    Identifier "Card0"
    Driver "fbdev"
    BusID "pci0:04:0:0:"
EndSection
EOF

# hostRetry,startOK; ipad4屏显示: 由console到全黑空屏;
root @ deb1013 in ~ |13:54:09  
$ /usr/bin/Xorg :1
  X.Org X Server 1.20.4
  X Protocol Version 11, Revision 0
  Build Operating System: Linux 6.1.0-20-amd64 x86_64 Debian
  Current Operating System: Linux deb1013 4.19.0-21-amd64 #1 SMP Debian 4.19.249-2 (2022-06-30) x86_64
  Kernel command line: BOOT_IMAGE=/boot/vmlinuz-4.19.0-21-amd64 root=UUID=0eca2d6c-1453-4c38-bb8c-536cdd5fe521 ro quiet apparmor=0
  Build Date: 15 April 2024  11:30:14AM
  xorg-server 2:1.20.4-1+deb10u14 (https://www.debian.org/support) 
  Current version of pixman: 0.36.0
    Before reporting problems, check http://wiki.x.org
    to make sure that you have the latest version.
  Markers: (--) probed, (**) from config file, (==) default setting,
    (++) from command line, (!!) notice, (II) informational,
    (WW) warning, (EE) error, (NI) not implemented, (??) unknown.
  (==) Log file: "/var/log/Xorg.1.log", Time: Wed May 21 13:54:17 2025
  (==) Using system config directory "/usr/share/X11/xorg.conf.d"

# ctRetry.OK, ipad4屏显示xf桌面;
root@deb1013:/# sudo /usr/bin/startx -- :0  ##root下跑: 直接OK
testuser@deb1013:/$ /usr/bin/startx -- :0   ##testuser用户: 不报无权限错,但提示:No protocol specified
  hostname: Name or service not known
  xauth:  timeout in locking authority file /home/testuser/.Xauthority
  xauth:  timeout in locking authority file /home/testuser/.Xauthority
  _XSERVTransmkdir: ERROR: euid != 0,directory /tmp/.X11-unix will not be created.
  X.Org X Server 1.20.4
  X Protocol Version 11, Revision 0
  Build Operating System: Linux 6.1.0-20-amd64 x86_64 Debian
  Current Operating System: Linux deb1013 4.19.0-21-amd64 #1 SMP Debian 4.19.249-2 (2022-06-30) x86_64
  Kernel command line: BOOT_IMAGE=/boot/vmlinuz-4.19.0-21-amd64 root=UUID=0eca2d6c-1453-4c38-bb8c-536cdd5fe521 ro quiet apparmor=0
  Build Date: 15 April 2024  11:30:14AM
  xorg-server 2:1.20.4-1+deb10u14 (https://www.debian.org/support) 
  Current version of pixman: 0.36.0
    Before reporting problems, check http://wiki.x.org
    to make sure that you have the latest version.
  Markers: (--) probed, (**) from config file, (==) default setting,
    (++) from command line, (!!) notice, (II) informational,
    (WW) warning, (EE) error, (NI) not implemented, (??) unknown.
  (==) Log file: "/home/testuser/.local/share/xorg/Xorg.0.log", Time: Wed May 21 06:00:35 2025
  (==) Using config directory: "/etc/X11/xorg.conf.d"
  (==) Using system config directory "/usr/share/X11/xorg.conf.d"
  No protocol specified

  waiting for X server to begin accepting connections .
  No protocol specified
  ..
  No protocol specified
  ..
  No protocol specified
  ..
```

- x11-base:ubt's

```bash
apt.sh   xserver-xorg pulseaudio  xserver-xorg-input-evdev 
#  1.ap34--intel 正常了;
#  2.genMachine--amd 不行(Xorg提示:识别不到屏幕); >> fk's img: 指定BUSID: 800X600分辨率;
  testuser@deb1013:/$ dpkg -l |grep xorg
  ii  xorg-sgml-doctools      1:1.11-1     all    Common tools for building X.Org SGML documentation
  ii  xserver-xorg  1:7.7+19     amd64  X.Org X server
  ii  xserver-xorg-core       2:1.20.4-1+deb10u14    amd64  Xorg X server - core server
  ii  xserver-xorg-input-all  1:7.7+19     amd64  X.Org X server -- input driver metapackage
  ii  xserver-xorg-input-evdev    1:2.10.6-1   amd64  X.Org X server -- evdev input driver
  ii  xserver-xorg-input-libinput       0.28.2-2     amd64  X.Org X server -- libinput input driver
  ii  xserver-xorg-video-all  1:7.7+19     amd64  X.Org X server -- output driver metapackage
  ii  xserver-xorg-video-amdgpu   18.1.99+git20190207-1  amd64  X.Org X server -- AMDGPU display driver
  ii  xserver-xorg-video-ati  1:19.0.1-1   amd64  X.Org X server -- AMD/ATI display driver wrapper
  ii  xserver-xorg-video-fbdev    1:0.5.0-1    amd64  X.Org X server -- fbdev display driver
  ii  xserver-xorg-video-nouveau  1:1.0.16-1   amd64  X.Org X server -- Nouveau display driver
  ii  xserver-xorg-video-radeon   1:19.0.1-1   amd64  X.Org X server -- AMD/ATI Radeon display driver
  ii  xserver-xorg-video-vesa     1:2.4.0-1    amd64  X.Org X server -- VESA display driver
  ii  xserver-xorg-video-vmware   1:13.3.0-2   amd64  X.Org X server -- VMware display driver
  headless @ deb1013 in ~ |01:57:45  
  $ dpkg -l |grep xorg
  ii  xserver-xorg       1:7.7+19ubuntu14    amd64  X.Org X server
  ii  xserver-xorg-core  2:1.20.13-1ubuntu1~20.04.20     amd64  Xorg X server - core server
  ii  xserver-xorg-input-evdev       1:2.10.6-1    amd64  X.Org X server -- evdev input driver

# x11-base:ubt's手动尝试（安装xserver-xorg-video-all）
#  1.装后可启Xorg, openbox-session进到桌面;
#  2.不用再设定BUSID?  但还是800X600分辨率(不能识别到显示器参数);
headless @ deb1013 in ~ |01:58:27  
  $ sudo apt install --no-install-recommends xserver-xorg-video-all
  $ sudo bash src/bin/input.sh
  $ sudo Xorg :0
  headless @ deb1013 in ~ |02:00:17  
  $ export DISPLAY=:0.0
  $ openbox-session 
  # 未设置busid; ref src\entrypoint.sh
  root@deb1013:/# cat /usr/share/X11/xorg.conf.d/driver-fbdev.conf
  cat: /usr/share/X11/xorg.conf.d/driver-fbdev.conf: No such file or directory


```

## 附

- ap34-dev-detail

```bash
# root@ap34:~# cd /dev/; ls -lh fb* input snd* tty*
crw-rw---- 1 root video   29,  0 May 20 20:38 fb0
crw-rw-rw- 1 root tty      5,  0 May 20 20:38 tty
crw--w---- 1 root tty      4,  0 May 20 20:38 tty0
crw--w---- 1 root tty      4,  1 May 20 20:39 tty1
..
crw-rw---- 1 root dialout  4, 67 May 20 20:38 ttyS3

# input:
total 0
drwxr-xr-x 2 root root     120 May 20 20:38 by-id
drwxr-xr-x 2 root root     140 May 20 20:38 by-path
crw-rw---- 1 root input 13, 64 May 20 20:38 event0
crw-rw---- 1 root input 13, 65 May 20 20:38 event1
..
crw-rw---- 1 root input 13, 73 May 20 20:38 event9
crw-rw---- 1 root input 13, 63 May 20 20:38 mice
crw-rw---- 1 root input 13, 32 May 20 20:38 mouse0

# snd:
total 0
drwxr-xr-x 2 root root       60 May 20 20:38 by-path
crw-rw---- 1 root audio 116, 11 May 20 20:38 controlC0
crw-rw---- 1 root audio 116,  9 May 20 20:38 hwC0D0
crw-rw---- 1 root audio 116, 10 May 20 20:38 hwC0D2
crw-rw---- 1 root audio 116,  3 May 20 20:38 pcmC0D0c
..
crw-rw---- 1 root audio 116,  7 May 20 20:38 pcmC0D9p
crw-rw---- 1 root audio 116,  1 May 20 20:38 seq
crw-rw---- 1 root audio 116, 33 May 20 20:38 timer
```

- genMachine-deb1013-apt-xorg-detail

```bash
root @ deb1013 in ~ |11:48:14  
# $ apt install xorg  
  The following NEW packages will be installed:
    libegl-mesa0 libegl1 libegl1-mesa libepoxy0 libevdev2 libfontenc1 libgbm1 libglu1-mesa libinput-bin libinput10 libmtdev1 libpipeline1 libwacom-bin libwacom-common libwacom2 libwayland-client0 libwayland-server0
    libxatracker2 libxaw7 libxcb-shape0 libxcb-util0 libxcomposite1 libxcursor1 libxfont2 libxft2 libxinerama1 libxkbfile1 libxmu6 libxpm4 libxrandr2 libxss1 libxt6 libxvmc1 libxxf86dga1 man-db x11-apps x11-session-utils
    x11-utils x11-xkb-utils x11-xserver-utils xbitmaps xfonts-100dpi xfonts-75dpi xfonts-base xfonts-encodings xfonts-scalable xfonts-utils xinit xorg xorg-docs-core xserver-common xserver-xorg xserver-xorg-core
    xserver-xorg-input-all xserver-xorg-input-libinput xserver-xorg-input-wacom xserver-xorg-legacy xserver-xorg-video-all xserver-xorg-video-amdgpu xserver-xorg-video-ati xserver-xorg-video-fbdev xserver-xorg-video-intel
    xserver-xorg-video-nouveau xserver-xorg-video-qxl xserver-xorg-video-radeon xserver-xorg-video-vesa xserver-xorg-video-vmware xterm
  0 upgraded, 68 newly installed, 0 to remove and 123 not upgraded.
  Need to get 32.5 MB of archives.

# $ apt install xserver-xorg-video-all
  The following NEW packages will be installed:
    libegl-mesa0 libegl1 libegl1-mesa libepoxy0 libfontenc1 libgbm1 libwayland-client0 libwayland-server0 libxatracker2 libxaw7 libxcb-util0 libxcursor1 libxfont2 libxinerama1 libxkbfile1 libxmu6 libxpm4 libxrandr2 libxss1
    libxt6 libxvmc1 x11-xkb-utils xfonts-base xfonts-encodings xfonts-utils xserver-common xserver-xorg-core xserver-xorg-video-all xserver-xorg-video-amdgpu xserver-xorg-video-ati xserver-xorg-video-fbdev
    xserver-xorg-video-intel xserver-xorg-video-nouveau xserver-xorg-video-qxl xserver-xorg-video-radeon xserver-xorg-video-vesa xserver-xorg-video-vmware
  0 upgraded, 37 newly installed, 0 to remove and 123 not upgraded.
  Need to get 18.5 MB of archives.


# apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev
  # $ apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev
  The following NEW packages will be installed:
    libegl-mesa0 libegl1 libegl1-mesa libepoxy0 libfontenc1 libgbm1 libwayland-client0 libwayland-server0 libxaw7 libxfont2 libxkbfile1 libxmu6 libxpm4 libxt6 x11-xkb-utils xfonts-base xfonts-encodings xfonts-utils
    xserver-common xserver-xorg-core xserver-xorg-video-amdgpu xserver-xorg-video-fbdev
  0 upgraded, 22 newly installed, 0 to remove and 123 not upgraded.
  Need to get 13.9 MB of archives.

  # --no-install-recommends: 13.9 MB> 7373 kB
  # $ apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev --no-install-recommends
  The following NEW packages will be installed:
    libegl-mesa0 libegl1 libegl1-mesa libepoxy0 libfontenc1 libgbm1 libwayland-client0 libwayland-server0 libxaw7 libxfont2 libxkbfile1 libxmu6 libxpm4 libxt6 x11-xkb-utils xserver-common xserver-xorg-core
    xserver-xorg-video-amdgpu xserver-xorg-video-fbdev
  0 upgraded, 19 newly installed, 0 to remove and 123 not upgraded.
  Need to get 7373 kB of archives.

```
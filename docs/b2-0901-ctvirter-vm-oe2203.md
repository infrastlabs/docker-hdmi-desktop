

```bash
# lspci
[root@localhost systemd]# dnf install pciutils
[root@localhost systemd]# lspci 
  00:00.0 Host bridge: Intel Corporation 440FX - 82441FX PMC [Natoma] (rev 02)
  00:01.0 ISA bridge: Intel Corporation 82371SB PIIX3 ISA [Natoma/Triton II]
  00:01.1 IDE interface: Intel Corporation 82371SB PIIX3 IDE [Natoma/Triton II]
  00:01.2 USB controller: Intel Corporation 82371SB PIIX3 USB [Natoma/Triton II] (rev 01)
  00:01.3 Bridge: Intel Corporation 82371AB/EB/MB PIIX4 ACPI (rev 03)
  00:02.0 VGA compatible controller: Virtio: Virtio GPU (rev 01) ##
  00:03.0 Ethernet controller: Intel Corporation 82540EM Gigabit Ethernet Controller (rev 03)
  00:04.0 Ethernet controller: Virtio: Virtio network device
  00:06.0 SCSI storage controller: Virtio: Virtio SCSI
  00:07.0 SCSI storage controller: Virtio: Virtio block device
  00:08.0 Unclassified device [00ff]: Virtio: Virtio memory balloon
  00:09.0 Unclassified device [00ff]: Virtio: Virtio RNG
# lsmod
[root@localhost ~]# lsmod  |grep virtio
  virtio_net             65536  0
  net_failover           24576  1 virtio_net
  virtio_balloon         24576  0
  virtio_gpu             65536  0
  virtio_dma_buf         16384  1 virtio_gpu
  drm_kms_helper        286720  1 virtio_gpu
  drm                   638976  2 drm_kms_helper,virtio_gpu
  virtio_blk             20480  3
  virtio_scsi            24576  0

[root@localhost _docker]# yum install xorg*
  Total download size: 183 M
  Installed size: 628 M
  [root@localhost _docker]# #dnf install xorg-x11-drivers

# xorg-x11-server
  xorg-x11-drivers
  xorg-x11-drv-amdgpu
  xorg-x11-drv-ati
  xorg-x11-drv-dummy
  xorg-x11-drv-fbdev
  xorg-x11-drv-intel
  xorg-x11-drv-vesa
  xorg-x11-drv-vmware
  xorg-x11-xauth
  xorg-x11-xinit
  xorg-x11-xkb-utils

# xorg
  [root@localhost _docker]# dnf install xorg-x11-drivers ##xorg-x11-server
  Package  Architecture        Version Repository  Size
  =====================
  Installing:
  xorg-x11-drivers  x86_64     7.7-29.oe2203sp4 OS         3.1 k
  Installing dependencies:
  duktape  x86_64     2.7.0-1.oe2203sp4         OS         139 k
  ft_surface        x86_64     1.0.0-1.oe2203sp4         OS         6.8 k
  hwdata   noarch     0.353-3.oe2203sp4         OS         1.7 M
  libICE   x86_64     1.0.10-5.oe2203sp4        OS 49 k
  libSM    x86_64     1.2.3-5.oe2203sp4         OS 18 k
  libXScrnSaver     x86_64     1.2.3-5.oe2203sp4         OS         9.4 k
  libXaw   x86_64     1.0.14-2.oe2203sp4        OS         156 k
  libXdmcp x86_64     1.1.3-5.oe2203sp4         OS 15 k
  libXfont2         x86_64     2.0.5-3.oe2203sp4         OS         139 k
  libXmu   x86_64     1.1.3-2.oe2203sp4         OS 50 k
  libXpm   x86_64     3.5.13-5.oe2203sp4        OS 37 k
  libXt    x86_64     1.2.1-4.oe2203sp4         OS         164 k
  libXv    x86_64     1.0.11-12.oe2203sp4       OS 12 k
  libXvMC  x86_64     1.0.13-2.oe2203sp4        OS 16 k
  libXxf86vm        x86_64     1.1.5-2.oe2203sp4         OS 12 k
  libdrm   x86_64     2.4.109-7.oe2203sp4       OS         140 k
  libevdev x86_64     1.13.0-1.oe2203sp4        OS 34 k
  libfontenc        x86_64     1.1.6-1.oe2203sp4         OS 14 k
  libglvnd x86_64     1:1.3.4-4.oe2203sp4       OS 59 k
  libglvnd-egl      x86_64     1:1.3.4-4.oe2203sp4       OS 34 k
  libglvnd-glx      x86_64     1:1.3.4-4.oe2203sp4       OS         107 k
  libgudev x86_64     237-2.oe2203sp4  OS 27 k
  libinput x86_64     1.19.2-2.oe2203sp4        OS         183 k
  libpciaccess      x86_64     0.16-3.oe2203sp4 OS 21 k
  libunwind         x86_64     2:1.6.2-8.oe2203sp4       OS 52 k
  libwacom x86_64     1.12-2.oe2203sp4 OS 40 k
  libwacom-data     noarch     1.12-2.oe2203sp4 OS 95 k
  libxkbfile        x86_64     1.1.0-6.oe2203sp4         update      79 k
  libxshmfence      x86_64     1.3-9.oe2203sp4  OS         7.4 k
  llvm-libs         x86_64     12.0.1-7.oe2203sp4        OS 23 M
  mesa-libEGL       x86_64     21.3.1-6.oe2203sp4        OS         103 k
  mesa-libGL        x86_64     21.3.1-6.oe2203sp4        OS         134 k
  mesa-libgbm       x86_64     21.3.1-6.oe2203sp4        OS 27 k
  mesa-libglapi     x86_64     21.3.1-6.oe2203sp4        OS 26 k
  mesa-libxatracker x86_64     21.3.1-6.oe2203sp4        OS         1.9 M
  mtdev    x86_64     1.1.6-3.oe2203sp4         OS 15 k
  polkit   x86_64     0.120-11.oe2203sp4        update     107 k
  polkit-libs       x86_64     0.120-11.oe2203sp4        update      55 k
  polkit-pkla-compat         x86_64     0.1-21.oe2203sp4 OS 28 k
  xcb-util x86_64     0.4.0-14.oe2203sp4        OS 11 k
  xorg-x11-drv-ati  x86_64     19.1.0-4.oe2203sp4        OS         151 k
  xorg-x11-drv-dummy         x86_64     0.4.0-1.oe2203sp4         OS 12 k
  xorg-x11-drv-evdev         x86_64     2.10.6-5.oe2203sp4        OS         108 k
  xorg-x11-drv-fbdev         x86_64     0.5.0-6.oe2203sp4         OS 23 k
  xorg-x11-drv-intel         x86_64     2.99.917-47.oe2203sp4     OS         656 k
  xorg-x11-drv-libinput      x86_64     1.2.0-2.oe2203sp4         OS 66 k
  xorg-x11-drv-nouveau       x86_64     1:1.0.17-2.oe2203sp4      OS         280 k
  xorg-x11-drv-qxl  x86_64     0.1.6-1.oe2203sp4         OS 82 k
  xorg-x11-drv-v4l  x86_64     0.3.0-2.oe2203sp4         OS 13 k
  xorg-x11-drv-vesa x86_64     2.6.0-1.oe2203sp4         OS 16 k
  xorg-x11-drv-vmware        x86_64     13.4.0-1.oe2203sp4        OS 73 k
  xorg-x11-drv-wacom         x86_64     1.1.0-1.oe2203sp4         OS 85 k
  xorg-x11-server   x86_64     1.20.11-36.oe2203sp4      update     1.4 M
  xorg-x11-server-common     x86_64     1.20.11-36.oe2203sp4      update      22 k
  xorg-x11-xauth    x86_64     1:1.1.2-1.oe2203sp4       OS 22 k
  xorg-x11-xkb-utils         x86_64     7.8-1.oe2203sp4  OS         158 k
  ===========================
  Install  57 Packages
  Total download size: 32 M
  Installed size: 126 M

  [root@localhost _docker]# ls /dev/|grep fb
  [root@localhost _docker]# 

  [root@localhost _docker]# X :0
  X.Org X Server 1.20.11
  Fatal server error:
  (EE) no screens found(EE)
```

- lightdm,xfce4

```bash
# lightdm
  [root@localhost _docker]# dnf install lightdm
  Package Architecture        Version  Repository  Size
  =======================
  Installing:
  lightdm x86_64     1.30.0-14.oe2203sp4        EPOL       189 k
  Installing dependencies:
  accountsservice  x86_64     0.6.55-4.oe2203sp4         OS         110 k
  dbus-x11         x86_64     1:1.12.20-11.oe2203sp4     OS 16 k
  iso-codes        noarch     4.7.0-3.oe2203sp4 update     3.7 M
  libxklavier      x86_64     5.4-21.oe2203sp4  OS 56 k
  lightdm-gobject  x86_64     1.30.0-14.oe2203sp4        EPOL        52 k
  mcpp    x86_64     2.7.2-29.oe2203sp4         OS 73 k
  sgml-common      noarch     0.6.3-52.oe2203sp4         OS 48 k
  systemd-pam      x86_64     249-81.oe2203sp4  OS         197 k
  xorg-x11-server-utils     x86_64     7.7-30.oe2203sp4  OS         125 k
  xorg-x11-xinit   x86_64     1.4.1-3.oe2203sp4 OS 46 k
  =============================
  Install  11 Packages
  Total download size: 4.6 M
  Installed size: 21 M

  [root@localhost _docker]# systemctl start lightdm
  Job for lightdm.service failed because the control process exited with error code.
  See "systemctl status lightdm.service" and "journalctl -xeu lightdm.service" for details.
  [root@localhost _docker]# journalctl -xeu lightdm
  [root@localhost systemd]# find / 2>/dev/null |grep lightdm.ser
  /usr/lib/systemd/system/lightdm.service

  [root@localhost systemd]# cat /usr/lib/systemd/system/lightdm.service
    [Service]
    Type=dbus
    ExecStart=/usr/sbin/lightdm
    Restart=always
    IgnoreSIGPIPE=no
    BusName=org.freedesktop.DisplayManager
    LimitMEMLOCK=16777216
  [root@localhost systemd]# /usr/sbin/lightdm
  [root@localhost systemd]# echo $?
  1

# xfce4 
# ref https://blog.csdn.net/FHY1221/article/details/140936836
   75  dnf install xfwm4 xfdesktop
   76  dnf install xfce4-*
   77  dnf install xfce4-session
   78  startx
   79  startxfce4 
  Fatal server error:
  (EE) no screens found(EE)

# oe2203sp4
[root@localhost ~]# rpm -qa
  xfce4-calculator-plugin-0.7.1-2.oe2203sp4.x86_64
  xfce4-battery-plugin-1.1.4-1.oe2203sp4.x86_64
  xfce4-appfinder-4.16.0-1.oe2203sp4.x86_64
```

- /dev/fb

```bash
# framebuffer
[root@localhost ~]# zcat /proc/config.gz  |grep FRAMEBUFF
  CONFIG_FRAMEBUFFER_CONSOLE=y
  # CONFIG_FRAMEBUFFER_CONSOLE_LEGACY_ACCELERATION is not set
  CONFIG_FRAMEBUFFER_CONSOLE_DETECT_PRIMARY=y
  CONFIG_FRAMEBUFFER_CONSOLE_ROTATION=y
  # CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER is not set

# kvm环境下启用framebuffer
# https://metaso.cn/search/8650749448357933057?q=kvm%E7%8E%AF%E5%A2%83%E4%B8%8B%E5%90%AF%E7%94%A8framebuffer
# sudo apt install xserver-xorg-video-qxl xserver-xorg-video-vesa
[root@localhost ~]# rpm -qa |grep xorg
  xorg-x11-drv-qxl-0.1.6-1.oe2203sp4.x86_64
  xorg-x11-drv-vesa-2.6.0-1.oe2203sp4.x86_64
# grub.cfg@oe-vm
[root@localhost boot]# cat ./grub2/grub.cfg |egrep "linux|initrd"
	linux	/vmlinuz-5.10.0-216.0.0.115.oe2203sp4.x86_64 root=UUID=dab374de-af8c-4f1f-b0b7-b54ad6a71f21 ro console=tty1 console=ttyS0 rootfstype=ext4 nomodeset quiet oops=panic softlockup_panic=1 nmi_watchdog=1 rd.shell=0 selinux=0 crashkernel=256M panic=3 
	initrd	/initramfs-5.10.0-216.0.0.115.oe2203sp4.x86_64.img
# grub.cfg@deb11-genM
root @ deb11-11 in /boot |15:06:18  
$ cat grub/grub.cfg |egrep "linux|initrd"
	linux	/boot/vmlinuz-5.10.0-32-amd64 root=/dev/nvme0n1p2 ro  quiet
	initrd	/boot/initrd.img-5.10.0-32-amd64

# qemu ##virtMgr: {QXL|VGA|Virtio}
root @ deb11-11 in ~ |15:01:48  
  $ ps -ef |grep qemu |grep vga |wc
        3     267    8750
  $ ps -ef |grep qemu |grep vga ##-device virtio-vga,id=video0,max_outputs=1,bus=pci.0,addr=0x2
  # virtMgr: Virtio>QXL>>也无fb0; 换VGA:也无;
  [root@localhost ~]# ll /dev/ |grep fb
  [root@localhost ~]# 

# modprobe fbdev @oe-vm
  [root@localhost ~]# modprobe fbdev
  [root@localhost ~]# echo $?
  0
  [root@localhost ~]# lsmod |grep fb
  fb_sys_fops            16384  1 drm_kms_helper
  [root@localhost ~]# ls /dev/ |grep fb
  [root@localhost ~]# 
  # modprobe fbdev @deb11-genM
  root @ deb11-11 in /boot |15:06:27  
  $ ls /dev/ |grep fb
  fb0
  $ lsmod |grep fb #none
  $ modprobe fbdev
  $ lsmod |grep fb #none
```


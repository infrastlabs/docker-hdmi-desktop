
- cust {hdmi屏显示: `ap34.deb9正常`, `genM.deb10只能800*600`}
  - img,dockerfile,buildx
  - 4.1) 0520|ap34's--hdmi-ipad4_01 `多屏也是fb0,xorg自动识别多屏`
    - xorg需root下跑
  - 4.2) 0521|genMachine--deb1013--ipad4 `kernel-4.19`
    - 不接屏,无/dev/fb0
    - 接屏后,BUSID问题 加配`/usr/share/X11/xorg.conf.d/10-amdgpu.conf `
- docs/01-0525-alsa-pulseaudio `org's img`
  - ap34-pulse `aplay -l; pactl load-module module-alsa-sink device=plughw:0,3 #ok`
  - alsa.aplay/sox.play `aplay 3476.mp3`; `play  3476.mp3`
- docs/02-0525-x11base-ubt2004 `x11base容器内装pkg,验:video/audio`
  - 0525|ap34-n3410-intel `x11base:ubt20: --no-install-recommends`
    - xorg 14.6 MB; xserver-xorg 4762 kB; pulseaudio 7255 kB
    - test `/dev/input/$input` `xserver-xorg-input-evdev`
    - pulse `pactl load-module module-alsa-sink device=plughw:0,3 #ok` pavucontro:` dummy> "HDA Intel PCH"`
  - 0526|genMachine-5700u-amdgpu
    - amd-5700u尝试驱动 `xserver-xorg-video-amdgpu` `mesa-vulkan-drivers` `org:amdgpu-install_6.4.60401-1_all.deb`
    - genM_livecd:xbt20/24可高清显示; `xbt1710/deb1012:800x600`
- docs/b1-0527-host-deb1211 `genM.换装deb12/11, 验:video/audio`
  - 0527|debian12.11 `kernel-6.1`
  - 0527|debian11.11 `kernel-5.10` `alsa-utils; aplay -l` `cat /proc/asound/cards`
  - 0528|换miniHDMI+供电线; 在宿主机安装xfce4 `可放音(需pavucontrol:选择hdmi卡,默认usb卡)`
  - 0528|deb11-xfce4,装后手动启pulse调试，拷贝配置到ct内运行无果
  - 0528|next TODO x4
  - 0528晚|ap34.x11base's无法取得声卡列表，ZH显示
  - 0529|重装deb11,`aplay -L |grep plughw ##有显，可加0,3 但无音`
  - 0529|try1, xfce4-subIns `libgl1-mesa-dri` `{libdrm-amdgpu1 libdrm-radeon1 libdrm2}`
  - 0529|try2, pulseaudio,xorg `#启前试，plughw:0,3/7/8/9; 都不行` `#重启后: 0,3也不行`
  - 0529下午|anayPkgs, recov.deb11-init.tar.gz `try-lightdm`
  - 260516|周六晚23:10(隔一年)，解决音频问题/多机多屏插线验证

```bash
##[cust]#######################
# org-img@genM_deb1013
  apt install xserver-xorg-video-amdgpu xserver-xorg-video-fbdev --no-install-recommends

  # busid
  cat > /usr/share/X11/xorg.conf.d/driver-fbdev.conf <<EOF
Section "Device"
    Identifier "Card0"
    Driver "fbdev"
    BusID "pci0:04:0:0:"
EndSection
EOF
  # startx
  startx -- :0   ##root下跑: 直接OK
  startx -- :0   ##testuser用户: 不报无权限错,但提示:No protocol specified


# x11-base:ubt@genM_deb1013
  apt.sh   xserver-xorg pulseaudio  xserver-xorg-input-evdev 
  #  1.ap34--intel 正常了;
  #  2.genMachine--amd 不行(Xorg提示:识别不到屏幕); >> fk's img: 指定BUSID: 800X600分辨率;

  # x11-base:ubt's手动尝试（安装xserver-xorg-video-all）
  #  1.装后可启Xorg, openbox-session进到桌面;
  #  2.不用再设定BUSID?  但还是800X600分辨率(不能识别到显示器参数);


##[b1-0527-host-deb1211]#######################
  # 0527|debian12.11 `kernel-6.1` > 低版ubt-xorg不行?(x11base内干扰??); 高版:pulse音频添加失败/deb10.无音输出.
  - x11base-ubt2004 `X Server 1.20.13`
    - `(EE) Caught signal 6 (Aborted). Server aborting`
  - x11base-ubt2204 `X Server 1.20.13`
    - `(EE) Caught signal 6 (Aborted). Server aborting`
  - x11base-ubt2404
    - `xorg OK; pulse 添加module-alsa-sink失败`
  - x11base-alpine319 `X Server 1.21.1.16`
    - `xorg OK; pulse 添加module-alsa-sink失败`
  - latest[hdmi].deb10 `X Server 1.20.4`
    - `xorg OK; pulse 添加module-alsa-sink成功,播放无音??{try:3,7,8,9; 重插屏一样}`

# 0528|next TODO x4
# pre:
  root @ deb11-11 in ~ |14:06:46  
  $ aplay -l |grep card
    card 0: Generic_1 [HD-Audio Generic], device 3: HDMI 0 [HDMI 0]
    card 0: Generic_1 [HD-Audio Generic], device 7: HDMI 1 [HDMI 1]
    card 0: Generic_1 [HD-Audio Generic], device 8: HDMI 2 [HDMI 2]
    card 0: Generic_1 [HD-Audio Generic], device 9: HDMI 3 [HDMI 3]
    card 1: HID [USB Audio and HID], device 0: USB Audio [USB Audio]
  # pactl load-module
    testuser@debian11-11:/etc$ pactl load-module module-alsa-sink device=plughw:1,3
    Failure: Module initialization failed
    testuser@debian11-11:/etc$ pactl load-module module-alsa-sink device=plughw:0,3
    19
    # aplay; apt install alsa-utils
    testuser@debian11-11:/etc$ aplay -L |grep plughw -A 2 #cat /proc/asound/cards
      plughw:CARD=Generic_1,DEV=3
          HD-Audio Generic, HDMI 0
          Hardware device with all software conversions
      plughw:CARD=Generic_1,DEV=7
          HD-Audio Generic, HDMI 1
          Hardware device with all software conversions
      plughw:CARD=Generic_1,DEV=8
          HD-Audio Generic, HDMI 2
          Hardware device with all software conversions
      plughw:CARD=Generic_1,DEV=9
          HD-Audio Generic, HDMI 3
          Hardware device with all software conversions
      --
      plughw:CARD=HID,DEV=0
          USB Audio and HID, USB Audio
          Hardware device with all software conversions
    testuser@debian11-11:/etc$ pactl load-module module-alsa-sink device=plughw:CARD=Generic_1,DEV=7 ##CARD=Generic_1,DEV=7
    20
    # 添加后: 两个同名output "HD-Audio Generic"
    # play /host/testuser/3xxx.mp3 >> 0,3不行; 0,7号卡:可以!!
    # TODO:
    #  1.受xfce4安装(带audio)的影响?
    #  2.转mini.hdmi线的影响?
    #  3.host-deb11下, ubt20,ubt22-xorg的启动验证;
    #  4.deb11/12下，不插线启/换口插>> 可亮屏/有音?

# 添加后: 两个同卡output "HD-Audio Generic"
# play /host/testuser/3xxx.mp3 >> 0,3不行; 0,7号卡:可以!!
  # TODO:
  #  1.受xfce4安装(带audio)的影响?
  #    是: 重装deb11后，再启进容器内有显无音了; @5.29早 8.20-9.20
  #  2.转mini.hdmi线的影响?
  #    否: 直接typec线(接屏上面的口)，也是有音频输出的;
  #  3.host-deb11下, ubt20,ubt22-xorg的启动验证;(之前deb12: ubt20/ubt22-xorg启报错)
  #    ubt20不行，同deb12.kernel时的错
  #    ubt22可以;
  #    ubt24可以;  
  #  4.deb11/12下，不插线启/换口插>> 可亮屏/有音?
  #    1)ct换genM.HDMI口插入不行:不亮屏; host换genM.HDMI不行(换到typec一线通也不行)
  #    2)deb11.kernel5.10: 不带屏启, 再插入typec屏有console显示; (可动态识别; 改插mini.HIMI有显/换genM口也有显; 换回typec:下口不识别/上口可以)


# 0529下午|anayPkgs, recov.deb11-init.tar.gz `try-lightdm`
  # 装lightdm,xserver-xorg: 
  #  1.未启lightdm前,启ct音频不行;
  #  2.启lightdmOK(进无桌面又退出),启ct音频不行;

  # xfce4/xfce4-goodies + pulseaudio pavucontrol
  #  1.未启lightdm前,启ct音频不行;
  #  2.启lightdmOK(进无桌面又退出),启ct音频:OK; (默认到usb卡, pavucontrol手动切换)
  # 
  #  3.amixer可手动切换?
  #  3.1 先在host.pavucontrol换回usb; ct可行?>>  [也可播放了]
  #  3.2 启lightdm进xf,play播放+pavucontrol选卡; (系统层面生成了啥?/设备打通??)

  # ref src/entrypoint.sh
  # #set ALSA sound to HDMI output
  # sudo amixer cset numid=3 2     
  # sudo amixer cset numid=1 100%

  # disk
  $ df -h |grep nvme
    /dev/nvme0n1p2   69G  2.0G   63G   3% /  #1.2G> 2.0G
```


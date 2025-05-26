#!/bin/bash

# input.sh @entrypoint.sh
# add input devices and their events to X11 configuration
mkdir -p /etc/X11/xorg.conf.d/
conf=/etc/X11/xorg.conf.d/10-input.conf
rm -f $conf

# exit 0 #默认模式:会导致s11的键盘也不能用<容器tty2/tty7全不能用了..>
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


# 
# 260519 10:50|try2自动加载触摸板到容器=>加上无影响,但touchPad也不能用
cat >> $conf <<_EOF_
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

# exit 0
echo cat $conf
cat $conf

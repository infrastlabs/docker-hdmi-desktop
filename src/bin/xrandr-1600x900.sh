#!/bin/bash
# ref env-bsnux\system\xrandr-shell\1600x900.sh
dst=default #eDP-1 HDMI-1

gtf 1600 900 60 #genMachine: same with botom.
xrandr --newmode "1600x900_60.00"  119.00  1600 1696 1864 2128  900 901 904 932  -HSync +Vsync
xrandr --addmode $dst "1600x900_60.00"
xrandr --output  $dst --mode "1600x900_60.00"




- ap34-pulse `aplay -l; pactl load-module module-alsa-sink device=plughw:0,3 #ok`
- alsa.aplay/sox.play `aplay 3476.mp3`; `play  3476.mp3`

```bash
# org's img
root@ap34:/opt/apps/docker-hdmi-desktop# cat /_ext/cmds-dbg-pulse.txt 
    1  aplay -l #view
    2  cd /_ext/
    3  ls
    4  aplay 3476.mp3 
    5  sox 3476.mp3 
    6  lame  3476.mp3 
    7  find /etc/ |grep pulse
   10  pulseaudio 
    # 
    1  cat /entrypoint.sh 
    2  pactl 
    5  pacmd #help
    6  pactl load-module module-alsa-sink device=plughw:0,1
    7  pactl load-module module-alsa-sink device=plughw:0,3 #ok
    8  pactl load-module module-alsa-sink device=plughw:0,0
    # 
    1  pavucontrol 
    4  cd /etc
    5  ls
    6  mv pulse/ pulse00
    7  cp -a /_ext/deb9-bsnux-pulse/ pulse
    8  find pulse
    9  pavucontrol 
    # 
    1  cd /_ext/
    4  aplay 3476.mp3 #alsa.aplay
   10  play  3476.mp3 ##sox.play
   11  history 
   12  history >> /_ext/cmds-dbg-pulse.txt 

```
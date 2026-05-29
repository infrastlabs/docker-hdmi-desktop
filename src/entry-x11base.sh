#!/bin/bash


# ============================================================
# 1. Helper Functions
function trim(){
    local var=$1
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

function addPerpService(){
    local xn=$1 svc=$2 cmd=$3
    local dest=/etc/perp/$xn-$svc
    mkdir -p $dest/
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^$cmd^g" > $dest/rc.main
}

function rclog(){
    local one=$1
    cat > /etc/perp/$one/rc.log <<EOF
#!/bin/sh
if test \${1} = 'start' ; then
  exec tinylog_run \${2}
fi
exit 0
EOF
}


# ============================================================
# 2. Configuration Loading
# Load .arg config file
if [ -f /.arg ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [ -z "$key" ] && continue
        value="${value%%#*}"
        key=$(trim "$key")
        value=$(trim "$value")
        # echo export "$key=$value"
        export "$key=$value"
    done < /.arg
fi
# env |egrep "HOME|START_SESSION|VNC_"


# ============================================================
# 3. Default Values
test -z "$DISPLAY" && export DISPLAY=:1
dispNum=${DISPLAY#*:}; dispNum=${dispNum%.*}
# if PORT_XXX not set, quick set mode
if [ $dispNum -gt 0 ] && [ "$dispNum" -lt 7 ]; then
    test -z "$PORT_SSH" && export PORT_SSH=$((50000+$dispNum*1000+22))
    test -z "$PORT_RDP" && export PORT_RDP=$((50000+$dispNum*1000+89))
    test -z "$PORT_VNC" && export PORT_VNC=$((50000+$dispNum*1000+81))
    test -z "$PORT_OC" && export PORT_OC=$((50000+$dispNum*1000+96))
fi

test -z "$PORT_SSH" && export PORT_SSH=10022
test -z "$PORT_RDP" && export PORT_RDP=10089
test -z "$PORT_VNC" && export PORT_VNC=10081
test -z "$PORT_OC" && export PORT_OC=10096
echo "entry.sh: DISPLAY=$DISPLAY, quick set PORT_SSH=$PORT_SSH, PORT_RDP=$PORT_RDP, PORT_VNC=$PORT_VNC, PORT_OC=$PORT_OC"
#
test -z "$SSH_PASS" && export SSH_PASS=headless
test -z "$VNC_PASS" && export VNC_PASS=headless
test -z "$VNC_PASS_RO" && export VNC_PASS_RO=View123

# TODO: check port: ssh, rdp, vnc
# sudo: unable to resolve host x11-ubuntu: Name or service not known
sudo -V > /dev/null 2>&1; test "0" == "$?" && sudo=sudo
match1=$(grep "^127.0.0.1 $HOSTNAME" /etc/hosts)
test ! -z "$match1" && echo "[hosts] existed, skip." || echo "127.0.0.1 $HOSTNAME" >> /etc/hosts


# ============================================================
# 4. oneVnc
function oneVnc(){
    local N=$1
    local name1=$2
    local user1=xvnc$N
    local port1=$((5900 + N))
    echo "oneVnc: id=$N, name=$name1"

    # createUser
    if [ "headless" != "$name1" ]; then #固定headless名?
        echo "SKEL=/etc/skel2" |$sudo tee -a /etc/default/useradd
        useradd -ms /usr/sbin/nologin xvnc$N;
        sed -i "s^SKEL=/etc/skel2^# SKEL=/etc/skel2^g" /etc/default/useradd
    else
        user1=headless #xvnc$N
    fi
    # HOME
    test -z "$HOME" && HOME=/home/$user1; mkdir -p $HOME #dcp.env HOME=/_ext/home/headless
    export HOME=$HOME #setXServer> oneVnc; export for botom script's use
    # rsync+chown
    test "$HOME" != "/home/$user1" && rsync -avzhP --ignore-existing --exclude=.cache --exclude=.npm /home/$user1 ${HOME%/*} > /dev/null 2>&1
    test "$HOME" != "/home/$user1" && chown -R headless:headless $HOME

    # ap-spi drop run
    rm -f $HOME/.config/autostart/at-spi-dbus-bus.desktop #删后at-spi进程还有,TODO.apt remove at-api2-core
    # 260612 11:30|在openbox/autostart内注入:有启进程,但console没有环境变量,启codium无中文;


    dst=$HOME/.config/autostart/setxkbmap.desktop
    mkdir -p ${dst%/*}; touch $dst;  chmod +x $dst; chown headless:headless $dst
    echo """
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Name=setxkbmap
Comment=
Exec=setxkbmap -rules evdev -model pc105 -layout us
;OnlyShowIn=XFCE;
StartupNotify=false
Terminal=false
Hidden=false
    """ |$sudo tee $dst > /dev/null 2>&1

    # SV: xvnc$N.conf
    local xn="x$N"
    rm -rf /etc/perp/$xn-* #drop old

    # PERP service generation
    envcmd="export DISPLAY=:$N; export HOME=$HOME"
    decmd="export USER=headless; export SHELL=/bin/bash; export TERM=xterm"

    if [ "true" == "$HEADLESS" ]; then
        addPerpService "$xn" "xvnc" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh xvnc $N\""
    else
        addPerpService "$xn" "xorg" "exec su-exec headless bash -c \"exec /xvnc2.sh xorg $N\""
        addPerpService "$xn" "x11vnc" "exec su-exec headless bash -c \"exec /xvnc2.sh x11vnc $N\""
    fi
    addPerpService "$xn" "chansrv" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh chansrv $N\""
    addPerpService "$xn" "dbus" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh dbus $N\""
    addPerpService "$xn" "udev" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh udev $N\""
    addPerpService "$xn" "pulse" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh pulse $N\""
    # addPerpService "$xn" "opencode" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh opencode $N\""
    # addPerpService "$xn" "cloudcli" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh cloudcli $N\""
    addPerpService "$xn" "chvt" "exec su-exec root bash -c \"while true; do sleep 1; bash /usr/local/bin/f12_to_tty1.sh; done\""

    # DBUS
    # ~/.xinitrc
    #   exec dbus-launch --exit-with-session openbox-session
    START_SESSION2=$START_SESSION
    test "Xopenbox-session" == "X$START_SESSION2" && START_SESSION2="dbus-launch --exit-with-session openbox-session"
    #
    # de: su-exec headless bash -c "xxx"
    dest=/etc/perp/$xn-de; mkdir -p $dest
    # exec startfluxbox > /dev/null 2>\&1
    # source /.env2;
    # kbcmd="setxkbmap -rules evdev -model pc105 -layout us -variant , ;" #dseek; ubt22-kbMap异常=> opbox/autostart
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; $decmd; env |grep -v PASS |sort; source /.env; $kbcmd sleep 1; exec $START_SESSION2\"^g" > $dest/rc.main


    # XRDP /etc/xrdp/xrdp.ini
    echo """
[Xvnc$N]
name=Xvnc$N
lib=libvnc.so
username=asknoUser
password=askheadless
ip=127.0.0.1
port=$port1
chansrvport=DISPLAY($N)
    """ |$sudo tee $tmpDir/xrdp-sesOne$N.conf > /dev/null 2>&1
    # $N atLast
    local line=$(grep -n "^# \[PRE_ADD_HERE\]" /etc/xrdp/xrdp.ini |cut -d':' -f1)
    line=$((line - 1))
    sed -i "$line r $tmpDir/xrdp-sesOne$N.conf" /etc/xrdp/xrdp.ini
    rm -f $tmpDir/xrdp-sesOne$N.conf

    # noVNC /usr/local/webhookd/static/index.html
    # TODO: fk-webhookd: wsconn识别display10参数;
    mkdir -p /etc/novnc
    echo "display$N: 127.0.0.1:$port1" |$sudo tee -a /etc/novnc/token.conf
    #
    # echo "<li>[<a href=\"javascript:void(0);\" onclick=\"openVnc('display$N', 'vnc')\">$N-resize</a>&nbsp;&nbsp; <a href=\"javascript:void(0);\" onclick=\"openVnc('display$N', 'vnc_lite')\">lite</a>] | $name1</li>" |$sudo tee -a $tmpDir/novncHtml$N.htm
    echo "<li><a href=\"javascript:void(0);\" onclick=\"openVnc('display$N', 'vnc')\">display$N</a></li>" |$sudo tee $tmpDir/novncHtml$N.htm > /dev/null 2>&1
    echo "<li><a href=\"javascript:void(0);\" onclick=\"openVnc('display$N', 'vnc_lite')\">display$N-lite</a></li>" |$sudo tee -a $tmpDir/novncHtml$N.htm > /dev/null 2>&1
    local line2=$(grep -n "ADD_HERE" /usr/local/webhookd/static/index.html |cut -d':' -f1)
    line2=$((line2 - 1))
    sed -i "$line2 r $tmpDir/novncHtml$N.htm" /usr/local/webhookd/static/index.html
    rm -f $tmpDir/novncHtml$N.
}

# oneVnc "$id" "$name"

# ============================================================
# 5. setXserver
function setXserver(){
    #tpl replace: each revert clean;
    cat /etc/xrdp/xrdp.ini.tpl > /etc/xrdp/xrdp.ini
    cat /etc/novnc/index.html > /usr/local/webhookd/static/index.html
    # /xvnc2.sh pulse X; oneVnc: xrdp,novnc sed_add_tmpfile
    # busybox: chown headless:headless > chmod 777
    tmpDir=/tmp/.headless; mkdir -p $tmpDir && chmod 777 -R $tmpDir ; #pulse: default-xx.pa

    # setPorts; sed port=.* || env_ctReset
    sed -i "s/port=ask5900/ port=ask5900/g" /etc/xrdp/xrdp.ini #avoid the botom sed
    sed -i "s/^port=.*/port=$PORT_RDP/g" /etc/xrdp/xrdp.ini #[Globals].port=3389
    sed -i "s/EFRp .*/EFRp $PORT_SSH/g" /etc/perp/ssh/rc.main #perp
    sed -i "3a\PORT_VNC=$PORT_VNC" /usr/local/webhookd/run.sh #+ ##todo: if -z, add
    # run.sh line4: PORT_VNC=${PORT_VNC:-10091}; echo "PORT_VNC: $PORT_VNC"

    # sesman
    # SES_PORT=$(echo "${PORT_RDP%??}50") #ref PORT_RDP, replace last 2 char
    SES_PORT=$((PORT_RDP + 1000)) #$(($PORT_RDP + 101)); #without sesman's run?
    sed -i "s/ListenPort=3350/ListenPort=${SES_PORT}/g" /etc/xrdp/sesman.ini

    # xvnc0-de
    # 清理历史 DISPLAY 遗留的 perp 服务: DISPLAY 变化时(如 :1->:2),
    # 旧 x$oldN-* 目录残留会随 perpd 启动, 拉起历史 DISPLAY 的 xvnc/xorg 等。
    # glob x[0-9]*-* 仅匹配 xN-xxx, 不影响 ssh/tpl-rc.main 等服务。
    rm -rf /etc/perp/x[0-9]*-*
    port0=$((0 + dispNum)) #vnc: 5900+10; VNC_OFFSET>dispNum
    oneVnc "$port0" "headless" #sv

    # clearPass: if not default
    if [ "headless" != "$VNC_PASS" ]; then
        sed -i "s/password=askheadless/password=ask/g" /etc/xrdp/xrdp.ini
        sed -i "s/value=\"headless\"/value=\"\"/g" /usr/local/webhookd/static/index.html
    fi

    # SSH_PASS VNC_PASS VNC_PASS_RO — 每次重启均可调整
    echo "headless:$SSH_PASS" |chpasswd > /dev/null 2>&1
    echo -e "$VNC_PASS\n$VNC_PASS\ny\n$VNC_PASS_RO\n$VNC_PASS_RO" |vncpasswd /etc/xrdp/vnc_pass > /dev/null 2>&1
    chmod 644 /etc/xrdp/vnc_pass

    if [ ! -f "$lock" ]; then
        # USERMOD（仅首次）
        u1=headless
        vals=$(echo "sudo|tty|video|input|audio|pulse" |sed "s/|/ /g"); arr=($vals)
        for one in "${arr[@]}"; do
            usermod -a -G $one $u1
        done
        groups $u1 #view
    fi
    unset SSH_PASS VNC_PASS VNC_PASS_RO #unset, not show in desktopEnv.
    unset LOC_XFCE LOC_APPS LOC_APPS2 DEBIAN_FRONTEND LOCALE_INCLUDE
}



# ============================================================
# 6. Main Execution
# Dump environment variables
# https://hub.fastgit.org/hectorm/docker-xubuntu/blob/master/scripts/bin/container-init
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export PATH=/_ext/_env/node/bin:$PATH
# export DISPLAY=:$VNC_OFFSET #dcp.env
if [ ! -z "$L" ]; then #export LANG,LANGUAGE
    charset=${L##*.}; test "$charset" == "$L" && charset="UTF-8" || echo "charset: $charset"
    lang_area=${L%%.*}
    export LANG=${lang_area}.${charset}
    export LANGUAGE=${lang_area}:en #default> en
    echo "====LANG: $LANG, LANGUAGE: $LANGUAGE=========================="
fi


# startCMD
# test -z "$START_SESSION" || sed -i "s/startfluxbox/$START_SESSION/g" /etc/systemd/system/de-start.service
# test -z "$START_SESSION" || sed -i "s/startfluxbox/$START_SESSION/g" /etc/perp/x$VNC_OFFSET-de/rc.main
test -z "$START_SESSION" && export START_SESSION=startfluxbox

#| grep -Ev '^(.*PASS.*|PWD|OLDPWD|HOME|USER|SHELL|TERM|([^=]*(PASSWORD|SECRET)[^=]*))=' \
 #   =/usr/local/static/3rd/bin/bash >> causeErr@ubt20: sudo: policy plugin failed session initialization
env |sed 's/^[[:blank:]]*//' |grep -Ev "^=" \
 |grep -Ev '_PASS.*|^SHLVL|^HOSTNAME|^PWD|^OLDPWD|^HOME|^USER|^SHELL|^TERM|^=' \
 |grep -Ev "LOC_|DEBIAN_FRONTEND|LOCALE_INCLUDE" | sort |$sudo tee /etc/environment > /dev/null 2>&1
# source /.env
: |$sudo tee /.env
while read one; do echo "export $one" | $sudo tee -a /.env > /dev/null 2>&1; done < /etc/environment
echo "export XMODIFIERS=@im=ibus" |$sudo tee -a /.env;\
echo "export GTK_IM_MODULE=ibus" |$sudo tee -a /.env;\
echo "export QT_IM_MODULE=ibus" |$sudo tee -a /.env;
# \
echo "export XMODIFIERS=@im=ibus" |$sudo tee -a /etc/profile;\
echo "export GTK_IM_MODULE=ibus" |$sudo tee -a /etc/profile;\
echo "export QT_IM_MODULE=ibus" |$sudo tee -a /etc/profile;


lock=/.1stinit.lock
setXserver

# --- L/TZ 值变化检测 ---
old_L=$(grep "^L=" $lock 2>/dev/null | cut -d= -f2-)
old_TZ=$(grep "^TZ=" $lock 2>/dev/null | cut -d= -f2-)

# Locale
if [ "$old_L" == "$L" ]; then
    echo "[locale] unchanged ($L), skip."
else
    echo "[locale] changed ($old_L → $L) → regenerating"
    setlocale 2>&1 | grep -v locale
fi

# TZ
if [ "$old_TZ" == "$TZ" ]; then
    echo "[tz] unchanged ($TZ), skip."
else
    echo "[tz] changed ($old_TZ → $TZ) → regenerating"
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime 2>/dev/null
fi

# 写入 lock
cat > $lock <<EOF
L=$L
TZ=$TZ
EOF

# CONF
test -f $HOME/.ICEauthority && chmod 644 $HOME/.ICEauthority #mate err
rm -f $HOME/.config/autostart/pulseaudio.desktop
# chmod +x /usr/share/applications/*.desktop ##fluxbox> pcmanfm> exec-dialog

# ct-hdmi-add01
touch $HOME/.config/clipit/disabled #ubt22, avoid first-notify
dst=/usr/lib/NetworkManager/conf.d/10-globally-managed-devices.conf; test -s $dst && mv $dst ${dst}-ex
econf=/etc/NetworkManager/conf.d; mkdir -p $econf
cat > $econf/10-globally-managed-devices.conf <<EOF
[main]
auth-polkit=false

[keyfile]
unmanaged-devices=*,except:interface-name:eth1,except:interface-name:eth2,except:type:wifi,except:type:gsm,except:type:cdma

[device-eth1]
managed=true
[device-eth2]
managed=true
EOF
apt remove -y at-spi2-core


cnt=0.1
echo "sleep $cnt" && sleep $cnt;

# link parec
rm -f /usr/bin/parec; ln -s /usr/bin/pacat /usr/bin/parec

#
# http://b0llix.net/perp/site.cgi?page=tinylog.8
cat > /etc/tinylog.conf  <<EOF
export TINYLOG_USER=root #tinylog
export TINYLOG_BASE=/var/log/tinylog #/var/log
export TINYLOG_OPTS="-k2 -s1000 -z" #keep2, size1000, gzip
EOF

cat > /usr/sbin/runtool <<EOF
#!/bin/bash
# -u xxx;
# shift
# shift
# exec \$@
#DO gosu>su-exec
shift; user1=\$1
shift
cmd="\$@" #fix bash -c "exec \$@"
exec su-exec \$user1 bash -c "exec \$cmd";
EOF
chmod +x /usr/sbin/runtool

# autostart: <perpctl A xx> dir sticky
#  设定再启动perpd才有效，启动后再设定会提示err
# https://blog.csdn.net/qq_21438461/article/details/131021640
# chmod o+t > chmod 1755 #o+t: busybox,openwrt不支持
ls -F /etc/perp/ |grep "/$" |while read one; do
  chmod 1755 /etc/perp/$one;
  test ! -z "$(echo $one |grep -E '^x.*-de|^x.*-xvnc|^x.*-xorg|^x.*-chvt')" && rclog "$one";
done
# set rc.* executable
chmod +x /etc/perp/**/rc.*

# sv
file=/usr/bin/sv; rm -f $file;
cat /usr/bin/psv.sh > $file;
chmod +x $file;

rm -f /tmp/udev-trigger.lock #rm for xvnc2.sh
export PS1='[\u@\h \W]\$ ' #@openwrt
export PERP_BASE=/etc/perp; dst=/var/log/tinylog/_perp; mkdir -p $dst
# gzip -V > /dev/null && z="-z" #deb9:有gzip,tinylog调用也出错
exec /usr/sbin/tini -- perpd > >(exec tinylog -k2 -s1000 $z $dst) 2>&1

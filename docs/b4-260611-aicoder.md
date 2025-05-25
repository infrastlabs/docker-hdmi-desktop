

### 0611周四|

- opencode
  - config.jsonc `pvds/models`
  - plugs: supperpowers,DCP; MCP.codegraph
  - serve: auth+apk; cloudcli.webUI
- microsandbox
  - 0610周三上午|glibc228版本编译:`deb10+/ubt20+`环境可用
  - 0611周四上午|普通用户可运行
  - 0611周四下午|ct-hdmi在box内运行远程ok/细化org.docs命令与配置
  - 0611周四晚|gmachine.deb11.k601内核升级
  - Composefile/Sandboxfile@v026`v03版重构:未有实现了`


**Urls**

> 16:30|urls https://docs.microsandbox.dev

- **Docs** Sandbox.{`oper/fs/metric`@sdk,`ssh/vols/secs/cust/snap/logs`@cmd} Image.{oci/disk} Net.{net,dns,tls} Observ
  - https://docs.microsandbox.dev/sandboxes/lifecycle `processArchFlow`
  - https://docs.microsandbox.dev/networking/overview `portMap, --no-net/net-rule "allow@public,allow@host"` `--dns-nameserver 1.1.1.1` `--tls-bypass "xx.com" --tls-bypass "*.gov"`
  - https://docs.microsandbox.dev/sandboxes/volumes `--mount-dir/file` `--mount-named/disk`
  - https://docs.microsandbox.dev/sandboxes/secrets `--secret "SERVICE_API_KEY@api.example.com"` #key=val?
  - https://docs.microsandbox.dev/sandboxes/logs `logs -f --tail=xx --grep xx`
  - https://docs.microsandbox.dev/sandboxes/snapshots `create/ls/rm export/import verify/inspect`
  - https://docs.microsandbox.dev/sandboxes/customize `patch.text/dir/file@sdk` `--init/--init-arg/--init-env`
- **Refs** SDK Cli Conf
  - https://docs.microsandbox.dev/configuration `~/.microsandbox/config.json` `~/.docker/config.json`
  - https://docs.microsandbox.dev/cli/sandbox-commands `run create/start/stop exec/logs ls ps rm copy inspect self.update/uninstall`
  - https://docs.microsandbox.dev/cli/ssh-commands `msb ssh authorize/serve` > `<MSB_HOME>/ssh/authorized_keys`
  - https://docs.microsandbox.dev/cli/image-commands `images pull,load/save,rmi,image.prune registry`
  - https://docs.microsandbox.dev/cli/volume-commands `create ls rm inspect`
- **Recipes**
  - https://docs.microsandbox.dev/recipes/guest/systemd-services `guest docker metrics` `sysd: --init auto/xxx.absolutepath`

```bash
# opencode
  # plugs: supperpowers,ctxCut, 

# 12:24|msb
  # 0610上午|build: deb10.glib228|ref fk-microsandbox/sam-custom.md
  # 8:40-10:30|ct-hdmi: pulse-udevadm导致卡顿/touch单击不可用fix
  # 11:00|run
    sudo usermod -aG kvm headless
    #root跑正常,headless跑不行
    # headless@hdmi-desktop:~$ img=registry.cn-shenzhen.aliyuncs.com/infrasync/v2025:library--alpine---3.13
    # headless@hdmi-desktop:~$ msb run  $img -- sh
    error: failed to start "msb-bccfade1"
      → other: sandbox process exited (signal: 6 (SIGABRT) (core dumped)) before agent relay became available
      → run `msb logs --source system msb-bccfade1` for full diagnostics
    # headless@hdmi-desktop:~$ msb logs --source system msb-bccfade1
    INFO microsandbox_runtime::vm: sandbox starting sandbox=msb-bccfade1
    INFO microsandbox_runtime::relay: agent relay listening on /_ext/home/headless/.microsandbox/run/agent/a47756f65a5d1dd3fe812337f6f2c279.sock
    INFO microsandbox_runtime::vm: entering VM sandbox=msb-bccfade1
    # 13:30|sudo chmod 0666 /dev/kvm后普通用户可跑了(容器内group.kvm与宿主机的gid对不上号)
  
  # 15:20|ct-hdmi
    1. 取镜像 msb pull infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04
    2. 运行远程novnc查看ok; 
  # 15:35|cmds
    msb ps -a
    msb ls --label app=engine
    # ssh [connect] ##tty模式
    msb ssh xxx #默认sh,进到交互环境
    msb ssh xxx -- echo 123
    msb ssh xxx -- bash #err不会进到交互环境
    # ssh authorize/serve ##ssh->tty的中转,认证控制
    cat ~/.ssh/id_rsa.pub | msb ssh authorize --stdin #to: <MSB_HOME>/ssh/authorized_keys
    msb ssh serve devbox --host 127.0.0.1 --port 2222
    msb ssh serve devbox --stdio
    # 
    # img|load from docker
    img=registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04
    #docker build -t $img .
    docker save $img | msb load
    msb run $img
    # img rename
    docker save my-image:latest | msb load --tag app:local
    msb run app:local

# cmds
/ # 
  img=registry.cn-shenzhen.aliyuncs.com/infrasync/v2025:library--alpine---3.13
  msb --info run $img -- sh
  116  img=registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04
  107  msb --info run $img -- bash
  109  msb run -e VNC_OFFSET=10 -e START_SESSION=openbox-session -e L=zh_CN -e TZ=Asia/Shanghai $img -- bash
  110  msb run -e VNC_OFFSET=10 -e START_SESSION=openbox-session -e L=zh_CN -e TZ=Asia/Shanghai -p 10022:10022 -p 10081:10081 -p 10089:10089 $img -- bash
  112  msb run -v /_ext/msb_data/:/data1 -e VNC_OFFSET=10 -e START_SESSION=openbox-session -e L=zh_CN -e TZ=Asia/Shanghai -p 10022:10022 -p 10081:10081 -p 10089:10089 $img -- bash /entry.sh
  # 直接用容器的Entrypoint; 默认init为krun:会导致僵尸进程
  113  msb run -v /_ext/msb_data/:/data1 -e VNC_OFFSET=10 -e START_SESSION=openbox-session -e L=zh_CN -e TZ=Asia/Shanghai -p 10022:10022 -p 10081:10081 -p 10089:10089 $img
  # 指定init: TODO当前指定/entry.sh可跑进去,到末行跑tini -- exec perpd后,mbs会crash<console无响应/msb.ps:crashed>
  117  msb run -v /_ext/msb_data/:/data1 -e VNC_OFFSET=10 -e START_SESSION=openbox-session -e L=zh_CN -e TZ=Asia/Shanghai -p 10022:10022 -p 10081:10081 -p 10089:10089 --init /entry.sh $img

  # image|0612早|@gmachine.k601
  # root @ deb11-11 in ~ |06:20:45  
    $ groupadd docker
    $ usermod -aG docker sam
  # sam@deb11-11:~$
    37  sudo chmod 666 /var/run/docker.sock #TODO,所属组
    38  docker ps
    39  docker save $img | msb load
  # sam@deb11-11:~$ docker save $img | msb load
    ✓ Loaded       registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04

```


### 0611晚|kernel-update

- 19.55-20.40

```bash
# xanmod|deb9不适用
  # 1. 导入 XanMod 仓库的 GPG 密钥
  wget -qO - https://dl.xanmod.org/archive.key | sudo gpg --dearmor -vo /etc/apt/keyrings/xanmod-archive-keyring.gpg
  # 2. 添加 XanMod 软件源
  echo "deb [signed-by=/etc/apt/keyrings/xanmod-archive-keyring.gpg] http://deb.xanmod.org $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/xanmod-release.list
  # 3. 更新软件包列表
  sudo apt update
  # 4. 安装 6.18 内核
  sudo apt install linux-xanmod-x64v3
  # 5. 重启系统
  sudo reboot

# freexian|
  # https://chat.deepseek.com/a/chat/s/fc344a43-fb2d-4035-8ad6-8c9263e57f97
  # 编辑源列表文件
  sudo nano /etc/apt/sources.list
  # 添加以下行（以官方源为例，国内用户可能需要查找镜像）
  deb http://deb.freexian.com/extended-lts stretch-lts main
  # deb http://deb.debian.org/debian stretch main

  # 更新软件包列表
  sudo apt update
  # 确认 6.1 内核包可用（可选）
  apt search linux-image-6.1
  # 安装 Kernel 6.1（amd64 架构）
  sudo apt install linux-image-6.1-amd64

# apt search linux-image-6.1 ##无法指定某仓做search;
root @ deb11-11 in /data1/_up_kernel |21:12:44  
$ cat apt-search-linux-lst.txt |wc
    260     724   10436
$ cat apt-search-linux-lst2.txt |wc #更新freexian后的;
   1160    3174   46970

# apt-cache policy xxx #查看可用源头URL;
# root @ deb11-11 in /data1/_up_kernel |21:11:51  
$ apt-cache policy linux-image-6.1.0-0.deb11.49-amd64
linux-image-6.1.0-0.deb11.49-amd64:
  Installed: (none)
  Candidate: 6.1.174-1~deb11u1
  Version table:
     6.1.174-1~deb11u1 500
        500 https://mirrors.aliyun.com/debian-security bullseye-security/main amd64 Packages
        500 http://deb.freexian.com/extended-lts bullseye-lts/main amd64 Packages

# 0613周六晚|ap34
echo -e "Acquire {\n\
  APT::Get::Allow-Unauthenticated \"true\";\n\
  GPG::Ignore \"true\";\n\
  AllowInsecureRepositories \"true\";\n\
  AllowDowngradeToInsecureRepositories \"true\";\n\
}" > /etc/apt/apt.conf.d/skip-gpg-check-ig
# sources.list
echo "deb http://mirrors.aliyun.com/debian-archive/debian ${V2} main contrib non-free" >> /etc/apt/sources.list;
echo "deb http://mirrors.aliyun.com/debian-archive/debian-security ${V2}/updates main contrib non-free" >> /etc/apt/sources.list; 
deb http://deb.freexian.com/extended-lts stretch-lts main

# 0614 10:25|scp_kernel@wpai_s11
root@ap34:/_ext/_kernel_update/sync_wpai_s11-deb9_kernels/k601# ls -lh
  total 58M
  drwxr-xr-x 2 root root 4.0K Jun 14 10:04 _headers
  -rw-r--r-- 1 root root  58M Jun 14 10:05 linux-image-6.1.0-0.deb9.49-amd64_6.1.174-1~deb9u1_amd64.deb
  -rw-r--r-- 1 root root 1.4K Jun 14 10:04 linux-image-6.1-amd64_6.1.174-1~deb9u1_amd64.deb
  -rw-r--r-- 1 root root  18K Jun 14 10:04 wireless-regdb_2025.07.10-1~deb9u1_all.deb
  # root@ap34:/_ext/_kernel_update/sync_wpai_s11-deb9_kernels/k601# dpkg -i wireless-regdb_2025.07.10-1~deb9u1_all.deb
  (Reading database ... 179939 files and directories currently installed.)
  Preparing to unpack wireless-regdb_2025.07.10-1~deb9u1_all.deb ...
  Unpacking wireless-regdb (2025.07.10-1~deb9u1) over (2025.07.10-1~deb9u1) ...
  Setting up wireless-regdb (2025.07.10-1~deb9u1) ...
  Processing triggers for man-db (2.7.6.1-2) ...
  # root@ap34:/_ext/_kernel_update/sync_wpai_s11-deb9_kernels/k601# dpkg -i linux-image-6.1.0-0.deb9.49-amd64_6.1.174-1~deb9u1_amd64.deb
  (Reading database ... 179939 files and directories currently installed.)
  Preparing to unpack linux-image-6.1.0-0.deb9.49-amd64_6.1.174-1~deb9u1_amd64.deb ...
  Unpacking linux-image-6.1.0-0.deb9.49-amd64 (6.1.174-1~deb9u1) ...
  Setting up linux-image-6.1.0-0.deb9.49-amd64 (6.1.174-1~deb9u1) ...
  I: /vmlinuz.old is now a symlink to boot/vmlinuz-4.18.0-0.bpo.1-amd64
  I: /initrd.img.old is now a symlink to boot/initrd.img-4.18.0-0.bpo.1-amd64
  I: /vmlinuz is now a symlink to boot/vmlinuz-6.1.0-0.deb9.49-amd64
  I: /initrd.img is now a symlink to boot/initrd.img-6.1.0-0.deb9.49-amd64
  /etc/kernel/postinst.d/dkms:
  Error!  The dkms.conf for this module includes a BUILD_EXCLUSIVE directive which
  does not match this kernel/arch.  This indicates that it should not be built.
  Error! echo
  Your kernel headers for kernel 6.1.0-0.deb9.49-amd64 cannot be found at
  /lib/modules/6.1.0-0.deb9.49-amd64/build or /lib/modules/6.1.0-0.deb9.49-amd64/source.
  /etc/kernel/postinst.d/initramfs-tools:
  update-initramfs: Generating /boot/initrd.img-6.1.0-0.deb9.49-amd64
  W: Possible missing firmware /lib/firmware/rtl_nic/rtl8125b-2.fw for module r8169
  W: Possible missing firmware /lib/firmware/rtl_nic/rtl8125a-3.fw for module r8169
  W: Possible missing firmware /lib/firmware/rtl_nic/rtl8168fp-3.fw for module r8169
  cryptsetup: WARNING: failed to detect canonical device of /dev/mmcblk1p1
  cryptsetup: WARNING: could not determine root device from /etc/fstab
  root@ap34:/_ext/_kernel_update/sync_wpai_s11-deb9_kernels/k601# 

```

- 21:40|rtw8852be-driver https://gitee.com/g-system/fk-lwfinger-rtw8852be
  - 原k510: 装headers>按README装依赖>make>make install=>重启后可识别,未装NM
  - 新k601: 装headers>(新拷贝1份)make clean>make>make install=>重启后可识别

```bash
# root @ deb11-11 in /data1/_up_kernel |21:22:37  
$ apt install --no-install-recommends linux-headers-5.10.0-32-amd64
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  binutils binutils-common binutils-x86-64-linux-gnu gcc-10 libasan6 libatomic1 libbinutils libcc1-0 libctf-nobfd0 libctf0 libgcc-10-dev
  libitm1 liblsan0 libquadmath0 libtsan0 libubsan1 linux-compiler-gcc-10-x86 linux-headers-5.10.0-32-common linux-kbuild-5.10
Suggested packages:
  binutils-doc gcc-10-multilib gcc-10-doc gcc-10-locales
Recommended packages:
  libc6-dev
The following NEW packages will be installed:
  binutils binutils-common binutils-x86-64-linux-gnu gcc-10 libasan6 libatomic1 libbinutils libcc1-0 libctf-nobfd0 libctf0 libgcc-10-dev
  libitm1 liblsan0 libquadmath0 libtsan0 libubsan1 linux-compiler-gcc-10-x86 linux-headers-5.10.0-32-amd64 linux-headers-5.10.0-32-common
  linux-kbuild-5.10
0 upgraded, 20 newly installed, 0 to remove and 105 not upgraded.
Need to get 42.5 MB of archives.
After this operation, 181 MB of additional disk space will be used.
Do you want to continue? [Y/n] y


```


- 23:00|msb@non-root

```bash
# sam
  # 可以用root，也可非root用户，如：sam (要求:sudo全免密)
  # 注：该用户使用部署平台进行组件/业务模块安装时需要，装好后可对sam改密或清理（当前：部署平台更新升级同样需要全免密权限）
  useradd -m -s /bin/bash sam
  echo "sam:Suntek123" |chpasswd 
  echo "sam ALL=(root) NOPASSWD: ALL" >> /etc/sudoers #sudo免密

# sudo usermod -aG kvm sam
  root @ deb11-11 in .../ai_tools/microsandbox-linux-x86_64-v055-2606 |22:59:07  
  $ cat /etc/group |grep kvm
  kvm:x:105:
  $ sudo usermod -aG kvm sam
  # 重要：修改组后，必须注销并重新登录（或重启），组权限更改才能生效。可以运行 groups 命令验证是否已成功加入
    sam@deb11-11:~$ groups 
    sam cdrom floppy audio dip video plugdev kvm netdev docker
    sam@deb11-11:~$ 
    logout
    root @ deb11-11 in ~ |07:26:41  
    $ su - sam
    sam@deb11-11:~$ groups 
    sam tty dialout cdrom floppy audio dip video plugdev kvm netdev docker

# run02|0612早|@gmachine.k601
  # img=registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04
    sam@deb11-11:~$ sudo usermod -aG tty sam #加后还不行,ct-hdmi下:可以的
    sam@deb11-11:~$ msb run -v /_ext/msb_data/:/data1 -e VNC_OFFSET=10 -e START_SESSION=openbox-session -e L=zh_CN -e TZ=Asia/Shanghai -p 10022:10022 -p 10081:10081 -p 10089:10089 $img -- bash
    error: terminal error: open tty input: Permission denied (os error 13)

  # groups|@gmachine.deb11.k601
  sudo usermod -aG tty sam
  sudo usermod -aG dialout sam
  sudo usermod -aG input sam

  img=registry.cn-shenzhen.aliyuncs.com/infrasync/v2025:library--alpine---3.13
  msb --info run $img -- sh
  # host.sam: 还不行
  # sam@deb11-11:~$ groups 
  sam tty dialout cdrom floppy audio dip video plugdev input kvm netdev docker
  sam@deb11-11:~$ img=registry.cn-shenzhen.aliyuncs.com/infrastlabs/docker-hdmi-desktop:app-ubuntu-22.04
  sam@deb11-11:~$ msb run  $img -- bash
  error: terminal error: open tty input: Permission denied (os error 13)
  # ct-hdmi非root:ok
  # headless@hdmi-desktop:/$ groups
  headless tty sudo audio video input pulse
  <aliyuncs.com/infrasync/v2025:library--alpine---3.13                            headless@hdmi-desktop:/$ msb --info run $img -- sh
  / # 
```

### 0612周五|vscodium+oc

- vscodium配置; ref `draft//2026/26-0606-agent-manager-ui.md`
  - ctl+p|ctl+k/ctl+s配置快捷键:条件`!terminalFocus`
  - ctl+m|ctl+k/ctl+s配置快捷键:查找`toggle max.. panel`新设定ctl+m热键;<条件:terminalFocus;免其它Panel时操作会导致卡死?> `ctl+m:有另一处绑定,可解除之`

```bash
# 11:00|vscode/vscodium.Electron环境不能输入中文
  # DBUS_SESSIONP_BUS_ADDRESS缺失@openbox-session; xfce4-session下则有;
  1. thunar/geany等程序可用:降级查找dbus_socket; vscode无此机制
  2. bamfdaemon@bamfdaemon包: plank用到:让打开的应用与xx.desktop图标可关联上;
  3. ap-spi@at-spi2-core包: 障碍辅助;可删<包+`.config/autostart/at-spi-dbus-bus.desktop`>; 当前跑了两个进程:`at-spi-dbus-launcher/at-spi-dbus2-registryd`
  # 12:20|dbus-launch openbox-session启动OK(openbox/autostart内尝试fail); 优化entry-x11base.sh

# 16:40|codegraph
# 0612|https://github.com/colbymchenry/codegraph ts`2026年1月18日+; star47.8k/fk2.9k, issue68/pr152, commits.x474/per40`
  npm i -g @colbymchenry/codegraph
  codegraph install
  codegraph uninstall
  cd your-project
    codegraph init -i


npm config set -g registry https://mirrors.cloud.tencent.com/npm/
  # agent|npm 全局安装
  npm i -g @anthropic-ai/claude-code #@anthropics/claude-code
  npm i -g opencode-ai@1.15.6 #latest
  # web|claudecodeui
  npm install -g @cloudcli-ai/cloudcli
  cloudcli #打开 http://localhost:3001，系统会自动发现所有现有会话。
  # deps ref x11base//compile/builder/ubt/Dockerfile.builder
  apt update
  apt install --no-install-recommends autoconf libtool pkg-config gcc g++ make \
      autoconf m4 intltool build-essential dpkg-dev \
      build-essential check #55M

# 17:45|用量查价
  # qk-opencode/zhipin-apply用量.主会话=> 0.35M(350K)/35M(35000K)?
  # opencode stats查总用量(ses132/msg2418,In7.6M/Out0.4M,cacheR46.3M); --project "$(pwd)"查不到.TODO; 
  - [用量统计](https://portal.qiniu.com/financial/orders/respack-mgr/all):tk-4w入/440出, 费用估计:0.04元; (资源包: 300w用了1w.tk; `短信提示欠费0.01,后又恢复..`) => 0612:`已用105w 35%` #ref draft//2026/24-0519-nodejs-claudecode.md
```


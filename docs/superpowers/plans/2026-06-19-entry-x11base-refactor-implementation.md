# entry-x11base.sh Refactoring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `src/entry-x11base.sh` for readability — extract helpers, clean dead code, fix bash anti-patterns, restructure with sections. No behavior change.

**Architecture:** Single-file refactoring: add helper functions at top → rewrite `oneVnc` perp services → reorder `rclog` → clean main execution → fix syntax patterns.

---

### Files to Modify

- `src/entry-x11base.sh` — The only file modified

---

### Task 1: Add helper functions (trim, addPerpService)

**Files:**
- Modify: `src/entry-x11base.sh:3-13` (insert helpers after .arg loading)

- [ ] **Step 1: Insert helper functions after .arg loading block**

Insert between the .arg block and the commented VNC_OFFSET block:

```bash
# Trim whitespace
function trim(){
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Generate perp service config
function addPerpService(){
    local xn=$1 svc=$2 cmd=$3
    local dest=/etc/perp/$xn-$svc
    mkdir -p $dest/
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^$cmd^g" > $dest/rc.main
}
```

- [ ] **Step 2: Update .arg parsing to use trim()**

Change:
```bash
key=$(echo "$key" | xargs)
value=$(echo "$value" | xargs)
```
To:
```bash
key=$(trim "$key")
value=$(trim "$value")
```

- [ ] **Step 3: Commit**

```bash
git add src/entry-x11base.sh
git commit -m "refactor: add trim() and addPerpService() helper functions"
```

---

### Task 2: Clean dead code blocks

**Files:**
- Modify: `src/entry-x11base.sh:15-22`

- [ ] **Step 1: Remove commented VNC_OFFSET block (lines 15-22)**

```bash
# test -z "$VNC_OFFSET" && export VNC_OFFSET=10
# # if PORT_XXX not set, quick set mode
# if [ $VNC_OFFSET -gt 10 ] && [ "$VNC_OFFSET" -lt 66 ]; then
#     test -z "$PORT_SSH" && export PORT_SSH=$(($VNC_OFFSET*1000+22))
#     test -z "$PORT_RDP" && export PORT_RDP=$(($VNC_OFFSET*1000+89))
#     test -z "$PORT_VNC" && export PORT_VNC=$(($VNC_OFFSET*1000+81))
#     echo "entry.sh: VNC_OFFSET=$VNC_OFFSET, quick set PORT_SSH=$PORT_SSH, PORT_RDP=$PORT_RDP, PORT_VNC=$PORT_VNC"
# fi
```

- [ ] **Step 2: Remove commented openbox autostart block (oneVnc, lines 73-81)**

```bash
#     dst=$HOME/.config/openbox/autostart
#     mkdir -p ${dst%/*}; touch $dst;  chmod +x $dst; ...
#     match1=$(cat $dst |grep dbus-launch)
#     test -z "$match1" && echo """
# ...
# """ >> $dst
```

- [ ] **Step 3: Remove commented parec/nm perp services (oneVnc, lines 129-133)**

```bash
# dest=/etc/perp/$xn-parec; mkdir -p $dest
# ...
# dest=/etc/perp/$xn-nm; mkdir -p $dest
```

- [ ] **Step 4: Remove commented xconf/dbus block (lines 246-267)**

```bash
##xconf.sh#########
#   # 
#   mkdir -p /run/dbus/ && ...
# ...
```

- [ ] **Step 5: Remove commented ENV/PULSE vars (lines 305-309)**

```bash
# ENV
# DISPLAY=${DISPLAY:-localhost:21}
# PULSE_SERVER=${PULSE_SERVER:-tcp:localhost:4721}
```

- [ ] **Step 6: Remove commented tini/perpd alternatives (lines 404-408)**

```bash
# exec /usr/sbin/tini -- perpd ...
# gzip -V > /dev/null && z="-z"
```

- [ ] **Step 7: Commit**

```bash
git add src/entry-x11base.sh
git commit -m "refactor: remove ~60 lines of dead/commented code"
```

---

### Task 3: Refactor oneVnc perp services with addPerpService

**Files:**
- Modify: `src/entry-x11base.sh:` (oneVnc function, the 30-line perp section)

- [ ] **Step 1: Replace the entire perp service generation block**

Replace this section (~30 lines):
```bash
    # PERP: 
    #   ref2: fk-docker-libvirtd//build/entry-prex11.sh  -->exec bash /entry.sh #执行x11base的/entry.sh
    envcmd="export DISPLAY=:$N; export HOME=$HOME"
    #  de: USER=headless,SHELL=/bin/bash,TERM=xterm,LANG=$L.UTF-8,LANGUAGE=$L:en$env_dbus
    decmd="export USER=headless; export SHELL=/bin/bash; export TERM=xterm"
    #  parec: PORT_VNC=$PORT_VNC$env_dbus
    # xvnc,chansrv
    if [ "true" == "$HEADLESS" ]; then
    dest=/etc/perp/$xn-xvnc; mkdir -p $dest/
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh xvnc $N\"^g" > $dest/rc.main
    else
    dest=/etc/perp/$xn-org; mkdir -p $dest/
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"exec /xvnc2.sh xorg $N\"^g" > $dest/rc.main
    dest=/etc/perp/$xn-x11vnc; mkdir -p $dest/
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"exec /xvnc2.sh x11vnc $N\"^g" > $dest/rc.main
    fi
    dest=/etc/perp/$xn-chansrv; mkdir -p $dest
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh chansrv $N\"^g" > $dest/rc.main
    # dbus,udev; sysd-udev: wpai_s11.ubt24=>causeMultiProgresses(导致机器卡顿, 改host网后才有?)
    dest=/etc/perp/$xn-dbus; mkdir -p $dest
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh dbus $N\"^g" > $dest/rc.main
    dest=/etc/perp/$xn-udev; mkdir -p $dest
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh udev $N\"^g" > $dest/rc.main
    # pulse,parec
    dest=/etc/perp/$xn-pulse; mkdir -p $dest
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh pulse $N\"^g" > $dest/rc.main
    # dest=/etc/perp/$xn-parec; mkdir -p $dest
    # cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc.sh parec $N\"^g" > $dest/rc.main
    # nm
    # dest=/etc/perp/$xn-nm; mkdir -p $dest
    # cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh nm $N\"^g" > $dest/rc.main

    # opencode,cloudcli
    dest=/etc/perp/$xn-opencode; mkdir -p $dest
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh opencode $N\"^g" > $dest/rc.main
    dest=/etc/perp/$xn-cloudcli; mkdir -p $dest
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh cloudcli $N\"^g" > $dest/rc.main
```

With (~12 lines):
```bash
    # PERP service generation
    envcmd="export DISPLAY=:$N; export HOME=$HOME"
    decmd="export USER=headless; export SHELL=/bin/bash; export TERM=xterm"

    if [ "true" == "$HEADLESS" ]; then
        addPerpService "$xn" "xvnc" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh xvnc $N\""
    else
        addPerpService "$xn" "org" "exec su-exec headless bash -c \"exec /xvnc2.sh xorg $N\""
        addPerpService "$xn" "x11vnc" "exec su-exec headless bash -c \"exec /xvnc2.sh x11vnc $N\""
    fi
    addPerpService "$xn" "chansrv" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh chansrv $N\""
    addPerpService "$xn" "dbus" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh dbus $N\""
    addPerpService "$xn" "udev" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh udev $N\""
    addPerpService "$xn" "pulse" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh pulse $N\""
    addPerpService "$xn" "opencode" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh opencode $N\""
    addPerpService "$xn" "cloudcli" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh cloudcli $N\""
```

- [ ] **Step 2: Commit**

```bash
git add src/entry-x11base.sh
git commit -m "refactor: use addPerpService() in oneVnc, remove dead service entries"
```

---

### Task 4: Fix bash anti-patterns (UUOC, expr → $(()), hostname)

**Files:**
- Modify: `src/entry-x11base.sh` (scattered locations)

- [ ] **Step 1: Fix UUOC patterns**

```bash
# Before:
match1=$(cat /etc/hosts |egrep "^127.0.0.1 $HOSTNAME")
local line=$(cat /etc/xrdp/xrdp.ini |grep "^# \[PRE_ADD_HERE\]" -n |cut -d':' -f1)
local line2=$(cat /usr/local/webhookd/static/index.html |grep "ADD_HERE" -n |cut -d':' -f1)
cat /etc/environment |while read one; do echo "export $one" | $sudo tee -a /.env > /dev/null 2>&1; done
ls -F /etc/perp/ |grep "/$" |while read one; do

# After:
match1=$(grep "^127.0.0.1 $HOSTNAME" /etc/hosts)
local line=$(grep -n "^# \[PRE_ADD_HERE\]" /etc/xrdp/xrdp.ini |cut -d':' -f1)
local line2=$(grep -n "ADD_HERE" /usr/local/webhookd/static/index.html |cut -d':' -f1)
while read one; do echo "export $one" | $sudo tee -a /.env > /dev/null 2>&1; done < /etc/environment
grep "/$" /etc/perp/ |while read one; do
```

- [ ] **Step 2: Fix expr → $(( )) arithmetic**

```bash
# Before:
local port1=$(expr 5900 + $N)
port0=$(expr 0 + $dispNum) #vnc: 5900+10; VNC_OFFSET>dispNum
line=$(expr $line - 1)
line2=$(expr $line2 - 1)
SES_PORT=$(expr $PORT_RDP + 1000)

# After:
local port1=$((5900 + N))
port0=$((0 + dispNum))
line=$((line - 1))
line2=$((line2 - 1))
SES_PORT=$((PORT_RDP + 1000))
```

- [ ] **Step 3: Remove commented out sudo variable in oneVnc (line 57)**

```bash
# Before:
    echo "SKEL=/etc/skel2" |$sudo tee -a /etc/default/useradd
# After: (already uses $sudo as set in line 44, remove comment)
    echo "SKEL=/etc/skel2" |sudo tee -a /etc/default/useradd
```

Actually, keep the `$sudo` pattern since it's used throughout for optional sudo availability.

- [ ] **Step 4: Commit**

```bash
git add src/entry-x11base.sh
git commit -m "refactor: fix UUOC and expr anti-patterns"
```

---

### Task 5: Reorder rclog and add section headers

**Files:**
- Modify: `src/entry-x11base.sh`

- [ ] **Step 1: Move rclog() before main execution**

Move `rclog()` function (currently near line 373) to the helper functions block after `addPerpService()`.

Expected position:
```bash
# (after addPerpService)
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
```

- [ ] **Step 2: Add section header comments**

Insert at the top of each logical section:
```bash
# ============================================================
# 1. .arg Configuration Loading
# ============================================================

# ============================================================
# 2. Helper Functions
# ============================================================

# ============================================================
# 3. oneVnc - Per-display service setup
# ============================================================

# ============================================================
# 4. setXserver - Global server configuration
# ============================================================

# ============================================================
# 5. Main Execution
# ============================================================
```

- [ ] **Step 3: Commit**

```bash
git add src/entry-x11base.sh
git commit -m "refactor: reorder rclog() and add section headers"
```

---

### Task 6: Final cleanup - indentation and verify

**Files:**
- Modify: `src/entry-x11base.sh`

- [ ] **Step 1: Standardize indentation to 4 spaces**

Scan for and fix:
- Tab characters → 4 spaces
- Consistent indentation inside function blocks
- Aligned line continuations

- [ ] **Step 2: Verify no syntax errors**

```bash
bash -n src/entry-x11base.sh
```

Expected: No output (syntax OK)

- [ ] **Step 3: Final review of the file**

```bash
wc -l src/entry-x11base.sh
```

Expected: ~330-350 lines (down from 409)

- [ ] **Step 4: Commit**

```bash
git add src/entry-x11base.sh
git commit -m "style: standardize indentation and final cleanup"
```

---

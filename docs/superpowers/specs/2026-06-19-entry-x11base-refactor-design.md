# entry-x11base.sh Refactoring Design

**Date**: 2026-06-19
**Scope**: Format beautification + moderate restructuring (no behavior change)

## 1. Current Problems

### Structural
- 409 lines with no clear section separation
- Functions defined after they're used (`rclog` at line 373, used at line 389)
- Repeated pattern: perp service generation duplicated 7+ times
- Inline execution code mixed with function definitions
- Dead/commented code blocks (~60 lines) scattered throughout

### Code Quality
- `expr` command (obsolete) used instead of `$(( ))`
- UUOC patterns: `cat file | grep`, `cat file | while read`
- `$(echo "$key" | xargs)` for trimming (heavy and fragile)
- Inconsistent `test` vs `[ ]` usage
- Some commands assume success without error handling

### Formatting
- Inconsistent indentation (tabs vs spaces)
- Trailing whitespace
- No section header comments

## 2. Target Structure

```
# === 1. .arg Configuration Loading ===         (keep as-is)
# === 2. Default Values (Ports, Passwords) ===  (clean up redundancy)
# === 3. Helper Functions ===                   (NEW: trim, addPerpService)
# === 4. oneVnc() ===                           (extract perp repetition)
# === 5. setXserver() ===                       (mostly keep)
# === 6. rclog() ===                            (move here from line 373)
# === 7. Main Execution ===                     (reorganized by phase)
#   Phase A: Environment/Language setup
#   Phase B: setXserver + locale
#   Phase C: post-config (network, tinylog, tools)
#   Phase D: perpd launch
```

## 3. Specific Changes

### 3.1 Add Helper Functions (NEW block)

**`trim()`** - Replace `$(echo "$key" | xargs)`:
```bash
function trim(){
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}
```

**`addPerpService()`** - Extract perp service generation (replaces 7+ repeated blocks):
```bash
function addPerpService(){
    local xn=$1 svc=$2 cmd=$3
    local dest=/etc/perp/$xn-$svc
    mkdir -p $dest/
    cat /etc/perp/tpl-rc.main |sed "s^_CMD_^$cmd^g" > $dest/rc.main
}
```

Call sites become:
```bash
# Before (7 lines):
dest=/etc/perp/$xn-dbus; mkdir -p $dest
cat /etc/perp/tpl-rc.main |sed "s^_CMD_^exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh dbus $N\"^g" > $dest/rc.main

# After (1 line):
addPerpService "$xn" "dbus" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh dbus $N\""
```

### 3.2 oneVnc() - Perp block reduction

Replace lines 109-139 (30 lines → ~12 lines):
```bash
if [ "true" == "$HEADLESS" ]; then
    addPerpService "$xn" "xvnc"    "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh xvnc $N\""
else
    addPerpService "$xn" "org"     "exec su-exec headless bash -c \"exec /xvnc2.sh xorg $N\""
    addPerpService "$xn" "x11vnc"  "exec su-exec headless bash -c \"exec /xvnc2.sh x11vnc $N\""
fi
addPerpService "$xn" "chansrv"  "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh chansrv $N\""
addPerpService "$xn" "dbus"     "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh dbus $N\""
addPerpService "$xn" "udev"     "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh udev $N\""
addPerpService "$xn" "pulse"    "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh pulse $N\""
addPerpService "$xn" "opencode" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh opencode $N\""
addPerpService "$xn" "cloudcli" "exec su-exec headless bash -c \"$envcmd; exec /xvnc2.sh cloudcli $N\""
```

### 3.3 .arg parsing - Use trim()

```bash
# Before:
key=$(echo "$key" | xargs)
value=$(echo "$value" | xargs)

# After:
key=$(trim "$key")
value=$(trim "$value")
```

### 3.4 UUOC fixes

```bash
# Before:
match1=$(cat /etc/hosts |egrep "^127.0.0.1 $HOSTNAME")
local line=$(cat /etc/xrdp/xrdp.ini |grep "^# \[PRE_ADD_HERE\]" -n |cut -d':' -f1)
cat /etc/environment |while read one; do ...

# After:
match1=$(grep "^127.0.0.1 $HOSTNAME" /etc/hosts)
local line=$(grep -n "^# \[PRE_ADD_HERE\]" /etc/xrdp/xrdp.ini |cut -d':' -f1)
while read one; do ... done < /etc/environment
```

### 3.5 expr → $(( ))

```bash
# Before:
local port1=$(expr 5900 + $N)
port0=$(expr 0 + $dispNum)
line=$(expr $line - 1)
SES_PORT=$(expr $PORT_RDP + 1000)

# After:
local port1=$((5900 + N))
port0=$((0 + dispNum))
line=$((line - 1))
SES_PORT=$((PORT_RDP + 1000))
```

### 3.6 Remove dead code blocks

- Lines 15-22: VNC_OFFSET old logic (commented out)
- Lines 73-81: openbox autostart (commented out)
- Lines 129-133: parec/nm perp services (commented out)
- Lines 246-267: xconf/dbus old logic (commented out)
- Lines 305-309: ENV/PULSE test vars (commented out)
- Lines 404-408: tini alternatives (commented out)

### 3.7 Reorder: rclog() before use

Move `rclog()` function definition from line 373 to the helper functions block (before main execution).

### 3.8 Indentation standardization

- 4 spaces for indentation throughout
- Remove trailing whitespace

## 4. Summary of Changes

| Item | Lines Before | Lines After | Delta |
|------|-------------|-------------|-------|
| .arg loading | 11 | 13 | +2 (trim change) |
| Defaults + ports | 30 | 25 | -5 |
| Helpers (new) | 0 | 25 | +25 |
| oneVnc() | 137 | 95 | -42 |
| setXserver() | 58 | 55 | -3 |
| Main execution | 173 | 125 | -48 |
| **Total** | **409** | **~338** | **-71** |

## 5. Files Changed

1. `src/entry-x11base.sh` - The only file modified

## 6. Risk Assessment

- **No behavior change**: All refactoring is structural/formatting only
- **Key risk**: `sed` substitution in perp service commands uses `^` delimiter which could conflict with paths containing `^` (currently no conflict)
- **Backward compatibility**: The `.arg` parsing already handles both `gosu` and `su-exec` paths; no change to that logic

# .arg Runtime Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate runtime environment variables from docker-compose.yml to .arg config file loaded at container startup

**Architecture:** .arg file mapped via Docker volume → entry-x11base.sh parses and exports variables → applications use configured values

**Tech Stack:** Bash, Docker, Docker Compose

---

## File Structure

### Files to Create
- `.arg` - Runtime configuration file (key=value format with # comments)

### Files to Modify
- `docker-compose.yml:64-73` - Remove environment vars, add volume mapping
- `src/entry-x11base.sh:1-11` - Insert .arg parsing logic

---

### Task 1: Create .arg configuration file

**Files:**
- Create: `.arg`

- [ ] **Step 1: Write .arg file with default values**

```bash
# Desktop Configuration
# Modify this file without restarting container
# DISPLAY default is :1 (use :3 or other values for testing)
DISPLAY=:1
START_SESSION=openbox-session
HOME=/_ext/home/headless
L=zh_CN
TZ=Asia/Shanghai
```

- [ ] **Step 2: Commit**

```bash
git add .arg
git commit -m "feat: add .arg runtime configuration file"
```

---

### Task 2: Modify docker-compose.yml - Add volume mapping

**Files:**
- Modify: `docker-compose.yml:56-63`

- [ ] **Step 1: Read docker-compose.yml volumes section**

```bash
cat docker-compose.yml | sed -n '56,63p'
```

Expected output:
```yaml
    volumes: 
      - ./src/bin/:/usr/local/bin/
      - ./src/entrypoint.sh:/entrypoint.sh
      - ./src/entrypoint2.sh:/entrypoint2.sh
      - ./src/entry-x11base.sh:/entry-x11base.sh
      - ./src/xvnc2.sh:/xvnc2.sh
      - /_ext:/_ext
      # - /opt:/opt
```

- [ ] **Step 2: Add .arg volume mapping**

Edit line 62 (before `/_ext:/_ext`):
```yaml
      - ./.arg:/.arg
```

Full volumes section should be:
```yaml
    volumes: 
      - ./src/bin/:/usr/local/bin/
      - ./src/entrypoint.sh:/entrypoint.sh
      - ./src/entrypoint2.sh:/entrypoint2.sh
      - ./src/entry-x11base.sh:/entry-x11base.sh
      - ./src/xvnc2.sh:/xvnc2.sh
      - /_ext:/_ext
      - ./.arg:/.arg
```

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "feat: map .arg file to container"
```

---

### Task 3: Modify docker-compose.yml - Remove migrated environment variables

**Files:**
- Modify: `docker-compose.yml:64-73`

- [ ] **Step 1: Read docker-compose.yml environment section**

```bash
cat docker-compose.yml | sed -n '64,73p'
```

Expected output:
```yaml
    environment:
      # - "SSHPORT=22" #/src/entrypoint.sh
      # - "BUSID=pci0:04:0:0:"
      # 
      - HOME=/_ext/home/headless
      - DISPLAY=${ENV_DISPLAY:-:1}
      # - VNC_OFFSET=51
      - START_SESSION=${ENV_DESK:-openbox-session}
      - L=zh_CN
      - TZ=Asia/Shanghai
```

- [ ] **Step 2: Remove DISPLAY, START_SESSION, L, TZ lines**

Remove lines 69, 71, 72, 73. Keep HOME as fallback.

Updated environment section:
```yaml
    environment:
      # - "SSHPORT=22" #/src/entrypoint.sh
      # - "BUSID=pci0:04:0:0:"
      #
      - HOME=/_ext/home/headless
      # - VNC_OFFSET=51
```

- [ ] **Step 3: Commit**

```bash
git add docker-compose.yml
git commit -m "refactor: remove migrated vars from docker-compose.yml environment"
```

---

### Task 4: Add .arg parsing logic to entry-x11base.sh

**Files:**
- Modify: `src/entry-x11base.sh:1-11`

- [ ] **Step 1: Read entry-x11base.sh first 11 lines**

```bash
head -n 11 src/entry-x11base.sh
```

Expected output:
```bash
#!/bin/bash

# test -z "$VNC_OFFSET" && export VNC_OFFSET=10
# # if PORT_XXX not set, quick set mode
# if [ $VNC_OFFSET -gt 10 ] && [ "$VNC_OFFSET" -lt 66 ]; then
#     test -z "$PORT_SSH" && export PORT_SSH=$(($VNC_OFFSET*1000+22))
#     test -z "$PORT_RDP" && export PORT_RDP=$(($VNC_OFFSET*1000+89))
#     test -z "$PORT_VNC" && export PORT_VNC=$(($VNC_OFFSET*1000+81))
#     echo "entry.sh: VNC_OFFSET=$VNC_OFFSET, quick set PORT_SSH=$PORT_SSH, PORT_RDP=$PORT_RDP, PORT_VNC=$PORT_VNC"
# fi
```

- [ ] **Step 2: Insert .arg parsing logic after shebang**

Insert after line 2 (after `#!/binbash`):

```bash
# Load .arg config file
if [ -f /.arg ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [ -z "$key" ] && continue
        value="${value%%#*}"
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        export "$key=$value"
    done < /.arg
fi
```

Full first 14 lines should be:
```bash
#!/bin/bash

# Load .arg config file
if [ -f /.arg ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [ -z "$key" ] && continue
        value="${value%%#*}"
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        export "$key=$value"
    done < /.arg
fi

# test -z "$VNC_OFFSET" && export VNC_OFFSET=10
# # if PORT_XXX not set, quick set mode
# if [ $VNC_OFFSET -gt 10 ] && [ "$VNC_OFFSET" -lt 66 ]; then
```

- [ ] **Step 3: Commit**

```bash
git add src/entry-x11base.sh
git commit -m "feat: add .arg parsing logic to entry script"
```

---

### Task 5: Test - Verify .arg file is loaded correctly

**Files:**
- Test: Manual verification

- [ ] **Step 1: Copy project to temporary directory for testing**

```bash
TEST_DIR=/tmp/opencode/test-arg-config
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cp -r /_ext/working/_prs/docker-hdmi-desktop/* "$TEST_DIR/"
cd "$TEST_DIR"
echo "Testing in: $TEST_DIR"
```

- [ ] **Step 2: Start container with .arg file**

```bash
docker-compose up -d
```

Expected: Container starts without recreation

- [ ] **Step 3: Verify .arg file is mapped inside container**

```bash
docker-compose exec desktop cat /.arg
```

Expected: Shows .arg file contents

- [ ] **Step 4: Check exported environment variables**

```bash
docker-compose exec desktop bash -c 'echo "DISPLAY=$DISPLAY"'
docker-compose exec desktop bash -c 'echo "START_SESSION=$START_SESSION"'
docker-compose exec desktop bash -c 'echo "HOME=$HOME"'
docker-compose exec desktop bash -c 'echo "L=$L"'
docker-compose exec desktop bash -c 'echo "TZ=$TZ"'
```

Expected:
```
DISPLAY=:1
START_SESSION=openbox-session
HOME=/_ext/home/headless
L=zh_CN
TZ=Asia/Shanghai
```

- [ ] **Step 5: Verify desktop starts correctly**

```bash
docker-compose logs desktop | tail -20
```

Expected: No errors, desktop session starts successfully

- [ ] **Step 6: Cleanup test directory**

```bash
docker-compose down
cd /_ext/working/_prs/docker-hdmi-desktop
rm -rf "$TEST_DIR"
echo "Test cleanup complete"
```

---

### Task 6: Test - Modify .arg and verify reload without container recreation

**Files:**
- Test: Manual verification

- [ ] **Step 1: Copy project to temporary directory for testing**

```bash
TEST_DIR=/tmp/opencode/test-arg-modify
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cp -r /_ext/working/_prs/docker-hdmi-desktop/* "$TEST_DIR/"
cd "$TEST_DIR"
echo "Testing in: $TEST_DIR"
```

- [ ] **Step 2: Modify .arg file - Change DISPLAY to :3**

```bash
sed -i 's/DISPLAY=:1/DISPLAY=:3/' .arg
cat .arg
```

Expected: DISPLAY=:3

- [ ] **Step 3: Restart container (not recreate)**

```bash
docker-compose restart desktop
```

Expected: Container restarts, not recreated

- [ ] **Step 4: Verify new DISPLAY value**

```bash
docker-compose exec desktop bash -c 'echo "DISPLAY=$DISPLAY"'
```

Expected: DISPLAY=:3

- [ ] **Step 5: Restore original value**

```bash
sed -i 's/DISPLAY=:3/DISPLAY=:1/' .arg
docker-compose restart desktop
docker-compose exec desktop bash -c 'echo "DISPLAY=$DISPLAY"'
```

Expected: DISPLAY=:1

- [ ] **Step 6: Cleanup and commit**

```bash
docker-compose down
cd /_ext/working/_prs/docker-hdmi-desktop
rm -rf "$TEST_DIR"
git add .arg
git commit -m "test: verify .arg reload without container recreation"
```

---

### Task 7: Test - Verify backward compatibility without .arg file

**Files:**
- Test: Manual verification

- [ ] **Step 1: Copy project to temporary directory for testing**

```bash
TEST_DIR=/tmp/opencode/test-arg-backward
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cp -r /_ext/working/_prs/docker-hdmi-desktop/* "$TEST_DIR/"
cd "$TEST_DIR"
echo "Testing in: $TEST_DIR"
```

- [ ] **Step 2: Start container with .arg file present**

```bash
docker-compose up -d
```

- [ ] **Step 3: Temporarily rename .arg file**

```bash
mv .arg .arg.backup
```

- [ ] **Step 4: Restart container**

```bash
docker-compose restart desktop
```

Expected: Container starts successfully

- [ ] **Step 5: Verify default values are used**

```bash
docker-compose exec desktop bash -c 'echo "DISPLAY=$DISPLAY"'
docker-compose exec desktop bash -c 'echo "START_SESSION=$START_SESSION"'
```

Expected: Uses defaults from entry script (DISPLAY=:1, START_SESSION=startfluxbox or entry script default)

- [ ] **Step 6: Restore .arg file**

```bash
mv .arg.backup .arg
docker-compose restart desktop
```

Expected: Container uses .arg values again

- [ ] **Step 7: Cleanup**

```bash
docker-compose down
cd /_ext/working/_prs/docker-hdmi-desktop
rm -rf "$TEST_DIR"
echo "Test cleanup complete"
```

---

### Task 8: Test - Verify comments and empty lines are handled

**Files:**
- Test: Manual verification

- [ ] **Step 1: Copy project to temporary directory for testing**

```bash
TEST_DIR=/tmp/opencode/test-arg-comments
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"
cp -r /_ext/working/_prs/docker-hdmi-desktop/* "$TEST_DIR/"
cd "$TEST_DIR"
echo "Testing in: $TEST_DIR"
```

- [ ] **Step 2: Add comments and empty lines to .arg**

```bash
cat > .arg << 'EOF'
# Desktop Configuration
# Test file with comments

DISPLAY=:3  # Display number (using :3 for testing)

# Session type
START_SESSION=openbox-session
HOME=/_ext/home/headless

L=zh_CN
TZ=Asia/Shanghai
EOF
cat .arg
```

- [ ] **Step 3: Start container**

```bash
docker-compose up -d
```

- [ ] **Step 4: Verify values are loaded correctly**

```bash
docker-compose exec desktop bash -c 'echo "DISPLAY=$DISPLAY"'
docker-compose exec desktop bash -c 'echo "START_SESSION=$START_SESSION"'
```

Expected: Both values loaded correctly, comments ignored, DISPLAY=:3

- [ ] **Step 5: Cleanup and restore**

```bash
docker-compose down
cd /_ext/working/_prs/docker-hdmi-desktop
rm -rf "$TEST_DIR"
git add .arg
git commit -m "test: verify .arg comment handling"
```

---

### Task 9: Document .arg file format in README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Read README.md**

```bash
cat README.md
```

- [ ] **Step 2: Add .arg configuration section**

After "### Environment variable (optional)" section (around line 33), add:

```markdown
### Runtime configuration (.arg file)

The container supports runtime configuration via a `.arg` file without requiring container reconstruction.

Create a `.arg` file in the project root with the following format:

```bash
# Desktop Configuration
DISPLAY=:1
START_SESSION=openbox-session
HOME=/_ext/home/headless
L=zh_CN
TZ=Asia/Shanghai
```

**Available variables:**
- `DISPLAY` - X11 display number (default: :1)
- `START_SESSION` - Desktop session command (default: openbox-session)
- `HOME` - User home directory
- `L` - Language/locale (e.g., zh_CN, en_US)
- `TZ` - Timezone (e.g., Asia/Shanghai)

**Usage:**
1. Edit `.arg` file with desired values
2. Restart container: `docker-compose restart desktop`
3. Configuration is loaded automatically

**Note:** The `.arg` file is optional. If not present, default values from the entry script are used.
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add .arg configuration documentation"
```

---

### Task 10: Final verification

**Files:**
- Test: Final sanity check

- [ ] **Step 1: Verify all commits**

```bash
git log --oneline -10
```

Expected: All feature commits present

- [ ] **Step 2: Run container with clean state**

```bash
docker-compose down
docker-compose up -d
```

- [ ] **Step 3: Verify container is running**

```bash
docker-compose ps
```

Expected: Status is "Up"

- [ ] **Step 4: Check container logs for errors**

```bash
docker-compose logs desktop | grep -i error || echo "No errors found"
```

Expected: No errors

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete .arg runtime configuration implementation"
```

---
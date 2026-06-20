# .arg Runtime Configuration File - Design Spec

**Date**: 2025-06-07
**Author**: opencode
**Status**: Approved

## 1. Overview

Move runtime environment variables from `docker-compose.yml` to a `.arg` configuration file that is loaded by the entry script at container startup. This allows configuration changes without triggering container reconstruction.

## 2. Motivation

Currently, modifying environment variables in `docker-compose.yml` causes Docker to recreate the container on `docker-compose up`, which is undesirable for runtime configuration changes like display settings, session type, and timezone.

## 3. Architecture

**Data Flow**:
```
.arg file (host) → Docker volume → /.arg (container) → entry-x11base.sh → export env vars → application
```

**Key Components**:
1. **.arg file** - Plain text config file with key=value format, supports # comments
2. **docker-compose.yml** - Maps .arg to container, removes migrated environment variables
3. **entry-x11base.sh** - Parses .arg at startup and exports variables
4. **Default fallback** - Entry script maintains default values if .arg is missing

## 4. .arg File Format

**Location**: `./.arg` (project root)

**Format**:
```bash
# Desktop Configuration
# Modify this file without restarting container
DISPLAY=:1
START_SESSION=openbox-session
HOME=/_ext/home/headless
L=zh_CN
TZ=Asia/Shanghai
```

**Rules**:
- Simple `KEY=VALUE` format
- Supports `#` comments (everything after # is ignored)
- Empty lines are ignored
- Leading/trailing whitespace trimmed from keys and values
- Variables are automatically exported by entry script

## 5. Migrated Variables

The following environment variables are moved from `docker-compose.yml` to `.arg`:

| Variable | Purpose | Default Value |
|----------|---------|---------------|
| DISPLAY | X11 display number | :1 |
| START_SESSION | Desktop session command | openbox-session |
| HOME | User home directory | /_ext/home/headless |
| L | Language/locale | zh_CN |
| TZ | Timezone | Asia/Shanghai |

**Not Migrated**:
- `ENV_TAG` - Remains in `.env` for image selection only
- Commented variables (SSHPORT, BUSID, VNC_OFFSET) - Not in active use

## 6. Implementation Changes

### 6.1 docker-compose.yml

**Remove from environment section**:
```yaml
environment:
  - HOME=/_ext/home/headless           # REMOVE
  - DISPLAY=${ENV_DISPLAY:-:1}         # REMOVE
  - START_SESSION=${ENV_DESK:-openbox-session}  # REMOVE
  - L=zh_CN                            # REMOVE
  - TZ=Asia/Shanghai                   # REMOVE
```

**Add to volumes section**:
```yaml
volumes:
  - ./.arg:/.arg  # ADD: Map .arg file
```

**Environment section after migration**:
```yaml
environment:
  - HOME=/_ext/home/headless  # Keep HOME as fallback
```

### 6.2 entry-x11base.sh

**Insert at line 1-11 (before existing logic)**:
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

**Behavior**:
- Silently skips if /.arg doesn't exist (backward compatible)
- Uses entry script defaults as fallback
- Parses entire file, exports all valid KEY=VALUE pairs
- Supports inline comments after values

### 6.3 .env file

**No changes** - ENV_TAG remains for image selection:
```bash
ENV_TAG=app-ubuntu-22.04
```

## 7. Backward Compatibility

- **Existing deployments** work without .arg file (uses defaults from entry script)
- **No immediate action** required - .arg is optional
- **Gradual migration** - Users can create .arg when needed

## 8. Error Handling

- **Missing .arg file** - Silently skipped, continue with defaults
- **Invalid format** - Malformed lines are skipped, valid lines processed
- **Empty file** - No effect, uses defaults
- **Permission errors** - Script continues if unable to read

## 9. Testing Checklist

- [ ] Create .arg file with all variables, verify values are exported
- [ ] Create .arg with comments, verify comments are ignored
- [ ] Run without .arg file, verify defaults work
- [ ] Modify .arg, restart container (not recreate), verify new values
- [ ] Verify docker-compose up doesn't recreate container after .arg change
- [ ] Test with empty .arg file
- [ ] Test with invalid syntax in .arg file

## 10. Migration Path for Existing Users

1. No action required - existing setup continues to work
2. To migrate: Create .arg file with desired values
3. Remove migrated vars from docker-compose.yml environment section
4. Add .arg volume mapping to docker-compose.yml
5. Restart container: `docker-compose restart desktop`
6. Verify configuration: Check env vars in container

## 11. Files Changed

1. `docker-compose.yml` - Remove environment vars, add volume mapping
2. `entry-x11base.sh` - Add .arg parsing logic
3. `.arg` - Create new config file (optional)

## 12. Dependencies

- bash shell (for parsing logic)
- xargs command (for whitespace trimming)
- No additional packages required

## 13. Future Enhancements (Out of Scope)

- Support for variable expansion in .arg (e.g., `${DISPLAY:-:0}`)
- Validation of .arg values before export
- Configuration reload without restart
- Multiple .arg files with priority
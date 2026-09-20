#!/bin/bash
set -euo pipefail

TARGET_CODE=88   # KEY_F12，用 evtest 按一下确认
TARGET_TTY=1           # 目标 tty 编号

# --- 自动查找键盘设备 ---
mapfile -t KEYBOARDS < <(awk '
  /^N: Name=/ { name = $0; sub(/^N: Name="/, "", name); sub(/"$/, "", name) }
  /^H: Handlers=/ {
    is_kbd = 0; event = ""
    for (i = 1; i <= NF; i++) {
      if ($i == "kbd") is_kbd = 1
      if ($i ~ /^event[0-9]+$/) event = $i
    }
    if (is_kbd && event) print "/dev/input/" event "\t" name
  }
' /proc/bus/input/devices)

if [ ${#KEYBOARDS[@]} -eq 0 ]; then
    echo "未找到键盘设备" >&2
    exit 1
fi

echo "找到 ${#KEYBOARDS[@]} 个键盘候选:"
printf '  %s\n' "${KEYBOARDS[@]}"

# 选择策略：优先名字里含 keyboard 的，否则用第一个
KEYBOARD_DEV=""
for entry in "${KEYBOARDS[@]}"; do
    dev="${entry%%$'\t'*}"
    name="${entry#*$'\t'}"
    if grep -qi keyboard <<<"$name"; then
        KEYBOARD_DEV="$dev"
        echo "选用: $dev ($name)"
        break
    fi
done
if [ -z "$KEYBOARD_DEV" ]; then
    KEYBOARD_DEV="${KEYBOARDS[0]%%$'\t'*}"
    echo "选用第一个: $KEYBOARD_DEV"
fi

# --- 监听并触发 ---
echo "监听 $KEYBOARD_DEV，按 F12 做触发..."
# 事件驱动: coproc 直读 evtest, 零轮询零 fork。
# (勿用 evtest|grep 管道: grep -m1 关闭读端后 evtest 或 SIGPIPE(141)
#  或阻塞挂起, 见 docs/b6-260917-f12-chvt-fix.md)
coproc EV { exec sudo evtest "$KEYBOARD_DEV" 2>/dev/null; }
while IFS= read -r line <&"${EV[0]}"; do
    case "$line" in
        *"type 1 (EV_KEY), code $TARGET_CODE ("*", value 1"*)
            echo "触发！"
            break ;;
    esac
done
eval "exec ${EV[0]}<&-" 2>/dev/null || true   # 关闭读端
pkill -TERM -P "$EV_PID" 2>/dev/null || true  # sudo 的子进程 evtest
kill -TERM "$EV_PID" 2>/dev/null || true      # sudo
wait "$EV_PID" 2>/dev/null || true

# https://chat.deepseek.com/a/chat/s/55609a42-91d4-435e-9866-5c9717090f2b
# 修法 A：用 stdbuf 强制 evtest 行缓冲（最推荐）|BAD:无效果,不执行 直接exit
# stdbuf -oL -eL evtest "$KEYBOARD_DEV" \
#   | grep -m1 --line-buffered -E "type 1 \(EV_KEY\), code $TARGET_CODE \([A-Z0-9_]+\), value 1"

# 修法 B：用 script 伪装成终端 |BAD:无效果+卡tty
# script -qfc "evtest $KEYBOARD_DEV" /dev/null \
#   | grep -m1 --line-buffered -E "type 1 \(EV_KEY\), code $TARGET_CODE \([A-Z0-9_]+\), value 1"

# 修法 C：换成 Python evdev（最稳）
#   如果你不想和缓冲较劲

# echo "触发！正在停止 display-manager..."
# sudo systemctl stop display-manager
echo "切换到 tty${TARGET_TTY} ..."
chvt "$TARGET_TTY"
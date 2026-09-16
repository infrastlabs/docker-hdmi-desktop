#!/bin/bash
# 文件名: f12_to_tty1.sh
# 用途:   监听所有键盘，按 F12 切换到 tty1
# 用法:   sudo ./f12_to_tty1.sh

set -uo pipefail

TARGET_CODE=88         # KEY_F12=88
TARGET_NAME="KEY_F12"
TARGET_TTY=1           # 目标 tty 编号
POLL_INTERVAL=0.2

if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root，请用 sudo 运行。" >&2
    exit 1
fi

# ---------- 自动识别所有键盘 ----------
mapfile -t KEYBOARDS < <(awk '
  /^N: Name=/ { name = $0; sub(/^N: Name="/, "", name); sub(/"$/, "", name) }
  /^H: Handlers=/ {
    is_kbd = 0; event = ""
    for (i = 1; i <= NF; i++) {
      if ($i == "kbd")          is_kbd = 1
      if ($i ~ /^event[0-9]+$/) event  = $i
    }
    if (is_kbd && event) print "/dev/input/" event "\t" name
  }
' /proc/bus/input/devices)

if [ ${#KEYBOARDS[@]} -eq 0 ]; then
    echo "未找到键盘设备" >&2
    exit 1
fi

echo "检测到 ${#KEYBOARDS[@]} 个键盘:"
for entry in "${KEYBOARDS[@]}"; do
    printf '  %s  |  %s\n' "${entry%%$'\t'*}" "${entry#*$'\t'}"
done

# ---------- 临时状态 & 清理 ----------
WORKDIR=$(mktemp -d)
TRIGGER="$WORKDIR/trigger"
PIDS=()

cleanup() {
    trap - EXIT INT TERM
    for pid in "${PIDS[@]:-}"; do
        [ -n "${pid:-}" ] || continue
        pkill -TERM -P "$pid" 2>/dev/null
        kill  -TERM "$pid"   2>/dev/null
    done
    sleep 0.1
    for pid in "${PIDS[@]:-}"; do
        [ -n "${pid:-}" ] || continue
        pkill -KILL -P "$pid" 2>/dev/null
        kill  -KILL "$pid"   2>/dev/null
    done
    rm -rf "$WORKDIR"
}
trap cleanup EXIT INT TERM

# ---------- 并发监听所有键盘 ----------
for entry in "${KEYBOARDS[@]}"; do
    dev="${entry%%$'\t'*}"
    name="${entry#*$'\t'}"
    (
        # BUG: evtest|grep 管道不可用——
        #   grep -m1 匹配后读端关闭: evtest 或 SIGPIPE(141, pipefail 下 $? 非0,
        #   TRIGGER 不写入) 或阻塞在 read 不写管道(pipeline 永久挂起)。
        # 改为: evtest 写独立日志 + 轮询匹配 + 匹配后显式 kill。
        out="$WORKDIR/ev-${dev//\//_}"
        pattern="type 1 \(EV_KEY\), code ${TARGET_CODE} \([A-Z0-9_]+\), value 1"
        evtest "$dev" > "$out" 2>/dev/null &
        ev_pid=$!
        while ! grep -qm1 -E "$pattern" "$out" 2>/dev/null; do
            kill -0 "$ev_pid" 2>/dev/null || break   # evtest 提前退出
            sleep 0.05
        done
        if grep -qm1 -E "$pattern" "$out" 2>/dev/null; then
            printf '%s  |  %s\n' "$dev" "$name" > "$TRIGGER"
        fi
        kill -TERM "$ev_pid" 2>/dev/null
    ) &
    PIDS+=($!)
done

echo
echo "监听中... 按 ${TARGET_NAME} 切换到 tty${TARGET_TTY}"

# ---------- 等待任一键盘触发 ----------
while [ ! -s "$TRIGGER" ]; do
    alive=0
    for pid in "${PIDS[@]}"; do
        kill -0 "$pid" 2>/dev/null && { alive=1; break; }
    done
    if [ $alive -eq 0 ]; then
        echo "所有监听器已退出，未检测到触发键。" >&2
        exit 1
    fi
    sleep "$POLL_INTERVAL"
done

echo "触发键来自: $(<"$TRIGGER")"

# 结束其它监听器
for pid in "${PIDS[@]}"; do
    pkill -TERM -P "$pid" 2>/dev/null
    kill  -TERM "$pid"   2>/dev/null
done

# ---------- 切换 tty ----------
echo "切换到 tty${TARGET_TTY} ..."
chvt "$TARGET_TTY"

echo "完成。"
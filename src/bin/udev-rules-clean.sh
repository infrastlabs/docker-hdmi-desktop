#!/bin/bash
# udev-rules-clean.sh
# 规则白名单清理：把容器内用不到的规则文件移动(mv)到备份目录, 而非直接删除
# ref docs/b9-260917-udev-container.md 十一节4.2 推荐清理(24个)
#   容器只需 input 键鼠 + sound 声卡 + 基础节点; 网络/存储/其他设备规则全部移走
# 用法: sudo bash /usr/local/bin/udev-rules-clean.sh [--restore]
#   --restore: 从备份目录移回全部规则文件(恢复默认)

set -u
SRC=/lib/udev/rules.d
BAK=/lib/udev/rules.d-ex
MUST_KEEP=17 # 4.1 必须保留: 50-udev-default/firmware/99-systemd + input链路 + sound链路

# 推荐清理清单(4.2, 24个): 网络7 + 存储6 + 其他11
CLEAN_LIST=(
  # 网络(NM未启用, 容器无网卡管理需求)
  73-special-net-names.rules 75-net-description.rules 80-net-setup-link.rules
  81-net-dhcp.rules 84-nm-drivers.rules 85-nm-unmanaged.rules 90-nm-thunderbolt.rules
  # 存储/块设备(devtmpfs仍建节点, 仅不建 /dev/disk/by-uuid 等符号链接)
  60-block.rules 60-persistent-storage.rules 60-persistent-storage-tape.rules
  61-persistent-storage-android.rules 64-btrfs.rules 96-e2scrub.rules
  # 其他设备(光驱/串口/摄像头/传感器/内存/闪存/老接口/upower)
  60-autosuspend.rules 60-cdrom_id.rules 60-fido-id.rules 60-persistent-v4l.rules
  60-sensor.rules 60-serial.rules 70-memory.rules 75-probe_mtd.rules
  80-drivers.rules 95-upower-hid.rules 95-upower-wup.rules

  # +samAdd1
  50-firmware.rules 99-systemd.rules
  70-joystick.rules 65-libwacom.rules
  70-power-switch.rules 71-power-switch-proliant.rules
  # opt-del
  40-vm-hotadd.rules 60-drm.rules 78-graphics-card.rules 71-seat.rules 73-seat-late.rules
  70-uaccess.rules 70-pcspkr-beep.rules 80-debian-compat.rules 90-console-setup.rules
)

err() { echo "[udev-clean] $*" >&2; exit 1; }

restore() {
  [ -d "$BAK" ] || err "备份目录 $BAK 不存在, 无可恢复"
  local n=0
  for f in "$BAK"/*.rules; do
    [ -e "$f" ] || continue
    mv -f "$f" "$SRC/" && n=$((n+1))
  done
  echo "[udev-clean] restore: 移回 $n 个规则文件到 $SRC"
  udevadm control --reload-rules 2>/dev/null || true
  exit 0
}

[ "${1:-}" = "--restore" ] && restore

[ -d "$SRC" ] || err "规则目录 $SRC 不存在"
mkdir -p "$BAK"

moved=0
for name in "${CLEAN_LIST[@]}"; do
  if [ -f "$SRC/$name" ]; then
    mv -f "$SRC/$name" "$BAK/" && moved=$((moved+1)) && echo "  moved: $name"
  fi
done

echo "[udev-clean] 完成: 移走 $moved/$(( ${#CLEAN_LIST[@]} )) 个规则文件 -> $BAK (保留 $MUST_KEEP 个必需)"
echo "[udev-clean] 重载规则: udevadm control --reload-rules"
udevadm control --reload-rules 2>/dev/null || true
echo "[udev-clean] 如需恢复: sudo bash $0 --restore"

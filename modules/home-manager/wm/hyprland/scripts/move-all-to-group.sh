#!/bin/bash
# Mueve TODAS las ventanas del workspace activo del monitor focused al VD N de ese monitor.

N=${1:-1}
source "$(dirname "$0")/monitors-detect.sh"

LOG=/tmp/move-all.log
exec 2>>"$LOG"
echo "=== $(date '+%H:%M:%S') N=$N ===" >&2
set -x

MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')

case "$MONITOR" in
  "$LEFT_SAMSUNG")  OFFSET=0  ;;
  "$RIGHT_SAMSUNG") OFFSET=9  ;;
  "$EDP")           OFFSET=18 ;;
  *)                OFFSET=0  ;;
esac

TARGET=$((N + OFFSET))

ACTIVE_WS=$(hyprctl monitors -j | jq -r ".[] | select(.name == \"$MONITOR\") | .activeWorkspace.id")

[ -z "$ACTIVE_WS" ] && exit 0
[ "$ACTIVE_WS" = "$TARGET" ] && exit 0

ADDRS=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $ACTIVE_WS) | .address")

echo "MONITOR=$MONITOR ACTIVE_WS=$ACTIVE_WS TARGET=$TARGET" >&2
echo "addrs to move: $ADDRS" >&2

for ADDR in $ADDRS; do
    # Lua dispatcher (Hyprland 0.55+): `follow = false` is the old `...silent` suffix and
    # `window` is the per-window selector the hyprlang "WS,address:0x.." arg used to carry.
    hyprctl dispatch "hl.dsp.window.move({ workspace = $TARGET, follow = false, window = \"address:$ADDR\" })"
done

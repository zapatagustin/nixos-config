#!/bin/bash
# Moves the active window to virtual desktop N in the current monitor's slot

N=${1:-1}
source "$(dirname "$0")/monitors-detect.sh"
# hc()/hc_notify(): classifies hyprctl output text (exit code isn't a usable failure
# signal here) and notifies on failure — see hyprctl-classify.sh.
source "$(dirname "$0")/hyprctl-classify.sh"

MONITOR=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

case "$MONITOR" in
  "$LEFT_SAMSUNG")  OFFSET=0  ;;
  "$RIGHT_SAMSUNG") OFFSET=9  ;;
  "$EDP")           OFFSET=18 ;;
  *)                OFFSET=0  ;;
esac

WS=$((N + OFFSET))
# Lua dispatchers (Hyprland 0.55+). `follow = false` is the old `...silent` suffix.
hc dispatch "hl.dsp.workspace.move({ workspace = $WS, monitor = \"$MONITOR\" })"
hc dispatch "hl.dsp.window.move({ workspace = $WS, follow = false })"

hc_notify "move-to-group"

#!/bin/bash
# Switches the focused monitor's workspace to slot N (1-9) based on the monitor's role:
# LEFT_SAMSUNG → N | RIGHT_SAMSUNG → N+9 | EDP → N+18

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
# Hyprland 0.55+ with a Lua config parses `hyprctl dispatch` arguments as Lua, so the
# hyprlang dispatcher names no longer work. Translation map in wm/hyprland/default.nix.
hc dispatch "hl.dsp.workspace.move({ workspace = $WS, monitor = \"$MONITOR\" })"
hc dispatch "hl.dsp.focus({ workspace = $WS })"

hc_notify "switch-monitor"

#!/bin/bash
# Switches every monitor to virtual desktop N (1-9)
# LEFT_SAMSUNG: ws N | RIGHT_SAMSUNG: ws N+9 | EDP: ws N+18

N=${1:-1}
source "$(dirname "$0")/monitors-detect.sh"
# hc()/hc_notify(): classifies hyprctl output text (exit code isn't a usable failure
# signal here) and notifies on failure — see hyprctl-classify.sh.
source "$(dirname "$0")/hyprctl-classify.sh"

CURRENT=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

# Lua dispatchers (Hyprland 0.55+): focusmonitor/workspace both map onto hl.dsp.focus.
focus_ws() {
    hc dispatch "hl.dsp.focus({ monitor = \"$1\" })"
    hc dispatch "hl.dsp.focus({ workspace = $2 })"
}

[ -n "$LEFT_SAMSUNG" ]  && focus_ws "$LEFT_SAMSUNG"  "$N"
[ -n "$RIGHT_SAMSUNG" ] && focus_ws "$RIGHT_SAMSUNG" "$((N+9))"
focus_ws "$EDP" "$((N+18))"

hc dispatch "hl.dsp.focus({ monitor = \"${CURRENT:-$LEFT_SAMSUNG}\" })"

hc_notify "switch-group"

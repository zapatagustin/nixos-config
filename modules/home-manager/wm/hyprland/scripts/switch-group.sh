#!/bin/bash
# Cambia todos los monitores al virtual desktop N (1-9)
# LEFT_SAMSUNG: ws N | RIGHT_SAMSUNG: ws N+9 | EDP: ws N+18

N=${1:-1}
source "$(dirname "$0")/monitors-detect.sh"

CURRENT=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

# Lua dispatchers (Hyprland 0.55+): focusmonitor/workspace both map onto hl.dsp.focus.
focus_ws() {
    hyprctl dispatch "hl.dsp.focus({ monitor = \"$1\" })"
    hyprctl dispatch "hl.dsp.focus({ workspace = $2 })"
}

[ -n "$LEFT_SAMSUNG" ]  && focus_ws "$LEFT_SAMSUNG"  "$N"
[ -n "$RIGHT_SAMSUNG" ] && focus_ws "$RIGHT_SAMSUNG" "$((N+9))"
focus_ws "$EDP" "$((N+18))"

hyprctl dispatch "hl.dsp.focus({ monitor = \"${CURRENT:-$LEFT_SAMSUNG}\" })"

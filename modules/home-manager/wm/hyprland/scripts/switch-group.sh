#!/bin/bash
# Cambia todos los monitores al virtual desktop N (1-9)
# LEFT_SAMSUNG: ws N | RIGHT_SAMSUNG: ws N+9 | EDP: ws N+18

N=${1:-1}
source "$(dirname "$0")/monitors-detect.sh"

CURRENT=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

if [ -n "$LEFT_SAMSUNG" ]; then
    hyprctl dispatch focusmonitor "$LEFT_SAMSUNG"
    hyprctl dispatch workspace "$N"
fi
if [ -n "$RIGHT_SAMSUNG" ]; then
    hyprctl dispatch focusmonitor "$RIGHT_SAMSUNG"
    hyprctl dispatch workspace "$((N+9))"
fi
hyprctl dispatch focusmonitor "$EDP"
hyprctl dispatch workspace "$((N+18))"

hyprctl dispatch focusmonitor "${CURRENT:-$LEFT_SAMSUNG}"

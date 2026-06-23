#!/bin/bash
# Mueve la ventana activa al virtual desktop N en el slot del monitor actual

N=${1:-1}
source "$(dirname "$0")/monitors-detect.sh"

MONITOR=$(hyprctl monitors | awk '/^Monitor/{name=$2} /focused: yes/{print name}')

case "$MONITOR" in
  "$LEFT_SAMSUNG")  OFFSET=0  ;;
  "$RIGHT_SAMSUNG") OFFSET=9  ;;
  "$EDP")           OFFSET=18 ;;
  *)                OFFSET=0  ;;
esac

WS=$((N + OFFSET))
hyprctl dispatch moveworkspacetomonitor "$WS" "$MONITOR" 2>/dev/null
hyprctl dispatch movetoworkspacesilent "$WS"

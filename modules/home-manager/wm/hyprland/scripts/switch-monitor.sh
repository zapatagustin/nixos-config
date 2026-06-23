#!/bin/bash
# Cambia el workspace del monitor focused al slot N (1-9) según el rol del monitor:
# LEFT_SAMSUNG → N | RIGHT_SAMSUNG → N+9 | EDP → N+18

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
hyprctl dispatch workspace "$WS"

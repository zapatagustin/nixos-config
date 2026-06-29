#!/bin/bash
# Configura monitores, workspaces y wallpapers en runtime según qué puertos
# tengan los Samsung conectados. Idempotente — se puede correr múltiples veces.
# Llamado al startup y por monitor-watcher.sh ante monitoradded/removed.

set -u
source "$(dirname "$0")/monitors-detect.sh"

LOG=/tmp/setup-monitors.log
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') LEFT=$LEFT_SAMSUNG RIGHT=$RIGHT_SAMSUNG EDP=$EDP ==="

# WALLPAPER_DIR set by nix (store path of the wallpapers flake input).
WALL_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
WALL_LEFT="$WALL_DIR/gruv-kanji.png"
WALL_RIGHT="$WALL_DIR/dragon.png"
WALL_EDP="$WALL_DIR/great-wave-of-kanagawa-gruvbox.png"

# Posiciones: Samsungs side-by-side arriba (1920px c/u, scale 1), eDP-1 abajo centrado
if [ -n "$LEFT_SAMSUNG" ]; then
    hyprctl keyword monitor "$LEFT_SAMSUNG,1920x1080@74.97,0x0,1"
fi
if [ -n "$RIGHT_SAMSUNG" ]; then
    hyprctl keyword monitor "$RIGHT_SAMSUNG,1920x1080@74.97,1920x0,1"
fi
# eDP-1 1366x768 native, scale 1 (no fractional), centered below the 3840-wide Samsung row
hyprctl keyword monitor "$EDP,preferred,1237x1080,1"

# Workspace rules dinámicas: 1-9 → LEFT, 10-18 → RIGHT, 19-27 → eDP-1
apply_ws_rules() {
    local mon=$1 start=$2 end=$3
    [ -z "$mon" ] && return
    for ws in $(seq "$start" "$end"); do
        hyprctl keyword workspace "$ws, monitor:$mon, persistent:true, default:true"
    done
}
apply_ws_rules "$LEFT_SAMSUNG" 1 9
apply_ws_rules "$RIGHT_SAMSUNG" 10 18
apply_ws_rules "$EDP" 19 27

# Mover workspaces ya existentes al monitor correcto (por si quedaron huérfanos)
move_ws_range() {
    local mon=$1 start=$2 end=$3
    [ -z "$mon" ] && return
    for ws in $(seq "$start" "$end"); do
        hyprctl dispatch moveworkspacetomonitor "$ws" "$mon" 2>/dev/null
    done
}
move_ws_range "$LEFT_SAMSUNG" 1 9
move_ws_range "$RIGHT_SAMSUNG" 10 18
move_ws_range "$EDP" 19 27

# Wallpapers (hyprpaper 0.8.x: solo `wallpaper "monitor,path"` y `listactive` están en IPC;
# `preload` y `unload` fueron removidos — `wallpaper` auto-carga el path)
if pgrep -x hyprpaper >/dev/null; then
    [ -n "$LEFT_SAMSUNG" ]  && hyprctl hyprpaper wallpaper "$LEFT_SAMSUNG,$WALL_LEFT"
    [ -n "$RIGHT_SAMSUNG" ] && hyprctl hyprpaper wallpaper "$RIGHT_SAMSUNG,$WALL_RIGHT"
    hyprctl hyprpaper wallpaper "$EDP,$WALL_EDP"
fi

#!/bin/bash
# Configures monitors, workspaces and wallpapers at runtime based on which ports
# the Samsungs are plugged into. Idempotent — safe to run multiple times.
# Called at startup and by monitor-watcher.sh on monitoradded/removed.

set -u
source "$(dirname "$0")/monitors-detect.sh"

LOG="${XDG_RUNTIME_DIR:-/tmp}/setup-monitors.log"
exec >>"$LOG" 2>&1
echo "=== $(date '+%F %T') LEFT=$LEFT_SAMSUNG RIGHT=$RIGHT_SAMSUNG EDP=$EDP ==="

# hyprctl's exit code is not a usable failure signal: a Lua syntax error exits 7, but a
# rejected command (the `keyword` calls this script used to make) and a dispatcher that
# fails at runtime both exit 0. The output text is the signal:
#   "ok" / empty (hyprpaper) -> success
#   "warning: ..."           -> benign miss, e.g. moving a workspace that doesn't exist yet
#   anything else            -> real failure
# Everything here is redirected to $LOG, so a failure is otherwise invisible: 19 rejected
# calls in a row went unnoticed until the workspace keybinds were tried 35 minutes later.
# hc() counts them and the script notifies at the end.
fails=0
hc() {
    local out
    out=$(hyprctl "$@" 2>&1)
    case "$out" in
    "" | ok | warning:*) return 0 ;;
    esac
    echo "FAIL: hyprctl $* -> $out"
    fails=$((fails + 1))
}

# WALLPAPER_DIR set by nix (store path of the wallpapers flake input).
WALL_DIR="${WALLPAPER_DIR:-$HOME/Pictures/wallpapers}"
WALL_LEFT="$WALL_DIR/View_of_Vent_in_the_Ventertal.jpg"
WALL_RIGHT="$WALL_DIR/morning-field.png"
WALL_EDP="$WALL_DIR/keyboard.jpg"

# Hyprland 0.55+ with a Lua config: `hyprctl keyword` is gone ("keyword can't work with
# non-legacy parsers. Use eval."). `hyprctl eval` runs a config-time Lua call instead and
# applies live. Translation map in wm/hyprland/default.nix.
set_monitor() { hc eval "hl.monitor({ output = \"$1\", mode = \"$2\", position = \"$3\", scale = $4 })"; }

# Positions: Samsungs side-by-side on top (1920px each, scale 1), eDP-1 centered below
[ -n "$LEFT_SAMSUNG" ]  && set_monitor "$LEFT_SAMSUNG"  "1920x1080@74.97" "0x0"    1
[ -n "$RIGHT_SAMSUNG" ] && set_monitor "$RIGHT_SAMSUNG" "1920x1080@74.97" "1920x0" 1
# eDP-1 at the per-host fractional scale (EDP_SCALE, from nix), centered below the
# 3840-wide Samsung row. Logical width = 2256/scale; x = (3840 - width)/2.
EDP_SCALE="${EDP_SCALE:-1}"
edp_w=$(awk "BEGIN{printf \"%d\", 2256 / $EDP_SCALE}")
edp_x=$(awk "BEGIN{printf \"%d\", (3840 - $edp_w) / 2}")
set_monitor "$EDP" "preferred" "${edp_x}x1080" "$EDP_SCALE"

# Dynamic workspace rules: 1-9 → LEFT, 10-18 → RIGHT, 19-27 → eDP-1
apply_ws_rules() {
    local mon=$1 start=$2 end=$3
    [ -z "$mon" ] && return
    for ws in $(seq "$start" "$end"); do
        hc eval "hl.workspace_rule({ workspace = \"$ws\", monitor = \"$mon\", persistent = true, default = true })"
    done
}
# Only the external slots are dynamic (they depend on which port each Samsung landed on).
# 19-27 -> eDP-1 is invariant and lives in the Lua config, applied at parse time.
apply_ws_rules "$LEFT_SAMSUNG" 1 9
apply_ws_rules "$RIGHT_SAMSUNG" 10 18

# Move already-existing workspaces to the right monitor (in case any were left orphaned).
# 19-27 stays here even though its rule is now static: switch-monitor.sh deliberately
# moves workspaces between monitors, so a 19-27 can end up on a Samsung and needs moving
# back. The static rule fixes the owner; this loop repairs the current state.
move_ws_range() {
    local mon=$1 start=$2 end=$3
    [ -z "$mon" ] && return
    for ws in $(seq "$start" "$end"); do
        # A workspace that doesn't exist yet answers "warning: Workspace not found"; hc()
        # classifies that as benign, so this no longer needs to discard stderr wholesale.
        hc dispatch "hl.dsp.workspace.move({ workspace = $ws, monitor = \"$mon\" })"
    done
}
move_ws_range "$LEFT_SAMSUNG" 1 9
move_ws_range "$RIGHT_SAMSUNG" 10 18
move_ws_range "$EDP" 19 27

# Wallpapers (hyprpaper 0.8.x: only `wallpaper "monitor,path"` and `listactive` are on IPC;
# `preload` and `unload` were removed — `wallpaper` auto-loads the path)
# hyprpaper's process comes up before its IPC socket is bound, so `pgrep -x hyprpaper` is not
# a readiness check: at boot this script reached the wallpaper block ~1s ahead of the socket
# and every call answered "can't send: failed to connect to hyprpaper". Wait for the socket to
# answer instead — same loop as monitor-watcher.sh's ensure_hyprpaper and the hyprpaper
# ExecStartPost in default.nix. eDP survived that race only because ExecStartPost retries it;
# the external wallpapers have no such backstop, so docked boots lost them silently.
hyprpaper_ready=0
for _ in $(seq 1 20); do
    if hyprctl hyprpaper listactive >/dev/null 2>&1; then
        hyprpaper_ready=1
        break
    fi
    sleep 0.3
done

if [ "$hyprpaper_ready" -eq 1 ]; then
    [ -n "$LEFT_SAMSUNG" ]  && hc hyprpaper wallpaper "$LEFT_SAMSUNG,$WALL_LEFT"
    [ -n "$RIGHT_SAMSUNG" ] && hc hyprpaper wallpaper "$RIGHT_SAMSUNG,$WALL_RIGHT"
    hc hyprpaper wallpaper "$EDP,$WALL_EDP"
else
    echo "FAIL: hyprpaper IPC socket never came up — wallpapers skipped"
    fails=$((fails + 1))
fi

# Surface failures: this script's whole output goes to $LOG, so without a notification a
# broken run is indistinguishable from a working one until a keybind is pressed.
if [ "$fails" -gt 0 ]; then
    echo "=== $fails FAILURES ==="
    hyprctl notify -1 8000 "rgb(fb4934)" "  setup-monitors: $fails fallas — ver $LOG"
fi

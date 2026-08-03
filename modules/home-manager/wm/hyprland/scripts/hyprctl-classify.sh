#!/bin/bash
# Shared hyprctl-call classifier + failure notifier, sourced by every script that
# dispatches into hl.dsp.*/hl.eval over hyprctl.
#
# hyprctl's exit code is not a usable failure signal under the Lua config parser: a Lua
# syntax error exits 7, but a rejected command and a dispatcher that fails at runtime both
# exit 0. The output text is the signal:
#   "ok" / empty (hyprpaper)  -> success
#   "warning: ..."            -> benign miss, e.g. moving a workspace that doesn't exist yet
#   anything else             -> real failure
# Without this, a failure is invisible: setup-monitors.sh's own incident had 19 rejected
# calls in a row go unnoticed until the workspace keybinds were tried 35 minutes later.
#
# Consumer contract: source this, call `hc` instead of `hyprctl` directly for any
# dispatch/eval that can silently fail, then call `hc_notify "<name>" ["<log>"]` at the
# end of the run to surface accumulated failures via a visible notification (these
# scripts run from keybinds with no terminal attached, so a log line alone isn't seen).

fails=0

hc() {
    local out
    out=$(hyprctl "$@" 2>&1)
    case "$out" in
    "" | ok | warning:*) return 0 ;;
    esac
    echo "FAIL: hyprctl $* -> $out"
    fails=$((fails + 1))
    # Explicit: `fails=$((...))` succeeds, so without this hc would return 0 on the failure
    # path and `hc dispatch ... || fallback` would never fire. No caller relies on the
    # status today, but the name invites it. Safe because no consumer runs under set -e.
    return 1
}

# Notifies the user if any hc() call failed this run. $1: name shown in the notification.
# $2 (optional): log file path to point the user at, if the caller keeps one.
hc_notify() {
    local name="$1" log="${2:-}"
    [ "$fails" -gt 0 ] || return 0
    echo "=== $fails FAILURES ==="
    if [ -n "$log" ]; then
        hyprctl notify -1 8000 "rgb(fb4934)" "  $name: $fails fallas — ver $log"
    else
        hyprctl notify -1 8000 "rgb(fb4934)" "  $name: $fails fallas"
    fi
}

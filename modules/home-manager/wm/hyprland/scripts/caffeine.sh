#!/usr/bin/env bash
# Keep the machine awake on demand: toggle a logind inhibitor lock so nothing
# dims, locks or suspends by itself until it is switched back off.
#
# WHY AN INHIBITOR AND NOT AN EDITED hypridle CONFIG. hypridle reads its
# `general`/`listener` blocks once at startup and has no runtime reconfiguration
# IPC, so a toggle would otherwise mean rewriting the config and restarting the
# unit. It does, however, poll logind's BlockInhibited property and skips every
# listener while an `idle` block lock is held (`general:ignore_systemd_inhibit`,
# default false, verified present in hypridle 0.1.8). One inhibitor therefore
# stops the whole chain — dim, lock, dpms off, suspend — with no daemon restart
# and no config to keep in sync.
#
# The lock itself is held by caffeine.service (declared in ../default.nix): a
# `systemd-inhibit ... sleep infinity` whose lifetime IS the lock's lifetime.
# systemd, not this script, owns the process, so the lock cannot be orphaned by a
# crashed shell and cannot survive the session (the unit is PartOf
# graphical-session.target). That is also why state is asked of systemd on every
# call instead of being tracked in a file that could disagree with reality.
set -u

unit=caffeine.service

# Ephemeral push channel the quickshell bar tails, same split as qs-theme: the
# icon flips on this line instead of polling systemctl. Must not persist.
runtime_dir="${XDG_RUNTIME_DIR:?refusing to fall back to world-writable /tmp}"
signal_file="$runtime_dir/qs-caffeine"

# Callers reach here from a bar button, where there is no terminal and
# Quickshell.execDetached discards stderr — same notify-on-failure convention as
# set-theme.sh and screenshot.sh.
fail() {
  echo "caffeine: $*" >&2
  notify-send -a caffeine -u critical "Caffeine failed" "$*" 2>/dev/null || true
  exit 1
}

is_on() { systemctl --user is-active --quiet "$unit"; }

case "${1:-toggle}" in
  on) systemctl --user start "$unit" || fail "could not start $unit" ;;
  off) systemctl --user stop "$unit" || fail "could not stop $unit" ;;
  toggle)
    if is_on; then
      systemctl --user stop "$unit" || fail "could not stop $unit"
    else
      systemctl --user start "$unit" || fail "could not start $unit"
    fi
    ;;
  # Read-only, and the only path the bar uses at startup: the inhibitor outlives a
  # quickshell restart, so the icon must ask rather than assume off.
  status)
    if is_on; then echo on; else echo off; fi
    exit 0
    ;;
  *)
    echo "usage: caffeine {toggle|on|off|status}" >&2
    exit 2
    ;;
esac

# Report what systemd ended up with, not what was requested — `on` while already
# on is a no-op and must still publish the true state.
if is_on; then now=on; else now=off; fi

echo "$now" >>"$signal_file" || fail "cannot write $signal_file"

if [ "$now" = on ]; then
  notify-send -a caffeine -t 2000 "Caffeine on" "Idle dim, lock and suspend inhibited" 2>/dev/null || true
else
  notify-send -a caffeine -t 2000 "Caffeine off" "Idle timers active again" 2>/dev/null || true
fi

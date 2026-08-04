#!/usr/bin/env bash
# Switch the whole system between the gruvbox dark and light palettes.
#
# HOW THIS WORKS. stylix picks one palette at build time: `base16Scheme` is a
# single value per evaluation and stylix has no dual-scheme or runtime-switch
# support. (polarity is not the axis — with base16Scheme set explicitly, polarity
# only feeds stylix's wallpaper palette generator and no enabled target reads it.)
# So the light palette is a home-manager SPECIALISATION: a second full evaluation
# of the HM config, declared in modules/home-manager/stylix.nix. Activating it
# relinks every stylix-generated file at once — kitty, neovim, bat, yazi, zellij,
# zathura, zed, gtk-3.0/gtk-4.0 — so there are no per-target rules to maintain.
#
# WHY THE PARENT GENERATION COMES FROM SYSTEMD. Activating a specialisation
# repoints home-manager's own gcroots/current-home at the specialisation, and a
# specialisation deliberately holds no nested specialisation (HM sets
# `specialisation = lib.mkOverride 0 {}` to prevent recursion). So once light is
# active, current-home leads nowhere that can get back to dark. The system unit's
# ExecStart is the stable anchor: it always names the PARENT (dark) generation and
# is only ever rewritten by nixos-rebuild.
#
# Consequence: a `nixos-rebuild switch` re-runs that unit and puts you back on
# dark, which is why the mode file alone cannot be trusted as current state — see
# active_mode below. The theme-sync unit runs `auto` at login to re-sync.
#
# The boundary hours below are mirrored by theme-sync.timer's OnCalendar entries
# in ../default.nix — change both together or the transition fires at the wrong
# wall-clock time.
set -u

LIGHT_FROM=9   # inclusive
LIGHT_UNTIL=18 # exclusive

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
state_dir="$state_home/hypr"
mode_file="$state_dir/theme-mode"
# Ephemeral push channel the quickshell bar tails. Unlike the mode file this must
# NOT persist — the same split Paths.qml already makes for its other qs-* files.
runtime_dir="${XDG_RUNTIME_DIR:?refusing to fall back to world-writable /tmp}"
signal_file="$runtime_dir/qs-theme"
log="$runtime_dir/set-theme.log"
lock="$runtime_dir/set-theme.lock"

# Every failure path has to reach a user who clicked a bar button, where there is
# no terminal and Quickshell.execDetached discards stderr. Same notify-on-failure
# convention as audio-device-watcher.sh and screenshot.sh.
fail() {
  echo "set-theme: $*" >&2
  notify-send -a set-theme -u critical "Theme switch failed" "$*" 2>/dev/null || true
  exit 1
}

usage() {
  echo "usage: set-theme {dark|light|toggle|auto}" >&2
  exit 2
}

want=${1:-}
case "$want" in
  dark | light | toggle | auto) ;;
  *) usage ;;
esac

# Serialise against a concurrent run: two home-manager activations interleaving
# over the same target files can leave a half-applied palette (gtk light, kitty
# still dark) with neither process seeing an error. Same hazard brightness.sh
# solves with flock.
#
# MUST be -n (skip), never -w (wait). This script's own activation runs HM's
# reloadSystemd step, which starts theme-sync.service, which runs this script
# again — so every switch nests one call inside itself. A waiting lock made that
# nested call block on the outer one until it timed out, so each toggle cost the
# full timeout, the unit ended in `failed`, and HM reported the user session
# degraded. Skipping makes the nested call an instant no-op instead.
#
# Consequence, accepted: a scheduled transition that lands exactly on a manual
# switch is dropped rather than queued. That is the right trade — the manual
# switch just set what the user asked for, and theme-sync runs again at the next
# boundary and at every login.
exec 9>"$lock" || fail "cannot create $lock"
if ! flock -n 9; then
  echo "set-theme: another run holds the lock, nothing to do" >&2
  exit 0
fi

unit="home-manager-$(id -un).service"
# ExecStart holds two store paths (hm-setup-env, then the generation). Only the
# generation ends in -home-manager-generation and the pattern cannot span the
# separating space, so this matches exactly one token. The unit is root-owned and
# only nixos-rebuild rewrites it, so the value is trusted input.
parent=$(systemctl show -p ExecStart --value "$unit" 2>/dev/null |
  grep -o '/nix/store/[^ ]*-home-manager-generation' | head -n1)

[ -n "$parent" ] ||
  fail "could not read the home-manager generation from $unit — is home-manager wired as a NixOS module here?"

light_gen="$parent/specialisation/light"

# ACTUAL state, not the recorded one. current-home points at whichever generation
# was activated last, so comparing it against the light specialisation is the only
# honest answer — the mode file goes stale whenever a nixos-rebuild reverts to the
# parent behind our back.
active_mode() {
  local cur light
  cur=$(readlink -f "$state_home/home-manager/gcroots/current-home" 2>/dev/null || true)
  light=$(readlink -f "$light_gen" 2>/dev/null || true)
  if [ -n "$cur" ] && [ -n "$light" ] && [ "$cur" = "$light" ]; then
    echo light
  else
    echo dark
  fi
}

mode_for_now() {
  local h
  h=$(date +%-H)
  if [ "$h" -ge "$LIGHT_FROM" ] && [ "$h" -lt "$LIGHT_UNTIL" ]; then
    echo light
  else
    echo dark
  fi
}

active=$(active_mode)

case "$want" in
  dark | light) mode="$want" ;;
  auto) mode="$(mode_for_now)" ;;
  toggle)
    if [ "$active" = dark ]; then mode=light; else mode=dark; fi
    ;;
esac

# Record the mode and push it to the bar. Runs on every invocation, including the
# no-op path, so a stale mode file left by a rebuild gets corrected even when no
# activation is needed. Returns non-zero on failure — callers MUST check: an
# unwritable state dir used to exit 0 here, which left theme-sync reporting
# success forever while the bar kept reading stale state at every login.
publish() {
  mkdir -p "$state_dir" || return 1
  printf '%s\n' "$1" >"$mode_file" || return 1
  printf '%s\n' "$1" >>"$signal_file" || return 1
}

# Already in the target state: skip the activation. It takes seconds and this path
# runs at every login and on every timer fire, so the guard is what keeps `auto`
# from being a recurring stall.
if [ "$mode" = "$active" ]; then
  publish "$mode" || fail "could not record the theme mode under $state_dir"
  exit 0
fi

if [ "$mode" = light ]; then
  activate="$light_gen/activate"
else
  activate="$parent/activate"
fi

if [ ! -x "$activate" ]; then
  if [ "$mode" = light ]; then
    fail "no light generation yet — rebuild after adding specialisation.light to modules/home-manager/stylix.nix"
  fi
  fail "$activate is missing or not executable"
fi

# Activation is chatty and takes a few seconds. Keep a log for debugging but don't
# spam the caller.
"$activate" >"$log" 2>&1 || fail "activation of '$mode' failed — see $log"

# Only after activation succeeded, so a failed switch never leaves the bar and the
# filesystem disagreeing about what is on screen.
publish "$mode" || fail "switched to '$mode' but could not record it under $state_dir"

# Already-running apps do not re-read the files activation just relinked. kitty
# reloads its whole config on SIGUSR1 (documented in kitty's own conf docs), which
# is why this needs no remote-control socket. Terminal-resident TUIs (neovim,
# zellij, yazi, bat) have no such hook and keep the old palette until restarted —
# inherent to the approach, not a gap in this script.
pkill -USR1 -x kitty 2>/dev/null || true

# Only meaningful once hyprland.lua derives its colours from stylix; harmless
# before that. hyprctl's exit code is unusable under the Lua config parser, so
# classify the output text instead — same reason as every other script here.
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null; then
  out=$(hyprctl reload 2>&1 || true)
  case "$out" in
    "" | ok | warning:*) ;;
    *) echo "set-theme: hyprctl reload said: $out" >&2 ;;
  esac
fi

exit 0

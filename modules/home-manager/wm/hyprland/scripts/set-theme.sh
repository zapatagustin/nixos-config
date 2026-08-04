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
set -u

usage() {
  echo "usage: set-theme {dark|light|toggle|auto}" >&2
  exit 2
}

LIGHT_FROM=9  # inclusive
LIGHT_UNTIL=18 # exclusive

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
state_dir="$state_home/hypr"
mode_file="$state_dir/theme-mode"
# Ephemeral push channel the quickshell bar tails. Unlike the mode file this must
# NOT persist — the same split Paths.qml already makes for its other qs-* files.
runtime_dir="${XDG_RUNTIME_DIR:?refusing to fall back to world-writable /tmp}"
signal_file="$runtime_dir/qs-theme"

want=${1:-}
case "$want" in
  dark | light | toggle | auto) ;;
  *) usage ;;
esac

unit="home-manager-$(id -un).service"
# ExecStart holds two store paths (hm-setup-env, then the generation). Only the
# generation ends in -home-manager-generation and the pattern cannot span the
# separating space, so this matches exactly one token.
parent=$(systemctl show -p ExecStart --value "$unit" 2>/dev/null |
  grep -o '/nix/store/[^ ]*-home-manager-generation' | head -n1)

if [ -z "$parent" ]; then
  echo "set-theme: could not read the home-manager generation from $unit" >&2
  echo "set-theme: is home-manager wired as a NixOS module on this host?" >&2
  exit 1
fi

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

# Record the mode and push it to the bar. Done for every invocation, including the
# no-op path below, so a stale mode file left by a rebuild gets corrected even when
# no activation is needed.
publish() {
  mkdir -p "$state_dir"
  printf '%s\n' "$1" >"$mode_file"
  printf '%s\n' "$1" >>"$signal_file"
}

# Already in the target state: skip the activation. It takes seconds and this path
# runs at every login and on every timer fire, so the guard is what keeps `auto`
# from being a recurring stall.
if [ "$mode" = "$active" ]; then
  publish "$mode"
  exit 0
fi

if [ "$mode" = light ]; then
  activate="$light_gen/activate"
else
  activate="$parent/activate"
fi

if [ ! -x "$activate" ]; then
  echo "set-theme: $activate is missing or not executable" >&2
  if [ "$mode" = light ]; then
    echo "set-theme: rebuild after adding specialisation.light to modules/home-manager/stylix.nix" >&2
  fi
  exit 1
fi

# Activation is chatty and takes a few seconds. Keep a log for debugging but don't
# spam the caller — a bar click has no terminal attached.
log="$runtime_dir/set-theme.log"
if ! "$activate" >"$log" 2>&1; then
  echo "set-theme: activation of '$mode' failed, see $log" >&2
  exit 1
fi

# Only after activation succeeded, so a failed switch never leaves the bar and the
# filesystem disagreeing about what is on screen.
publish "$mode"

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

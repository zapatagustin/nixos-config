#!/usr/bin/env bash
# Switch the whole system between the gruvbox dark and light palettes.
#
# HOW THIS WORKS. stylix picks one palette at build time: `base16Scheme` is a
# single value per evaluation and stylix has no dual-scheme or runtime-switch
# support. polarity is switched alongside it: no stylix TARGET reads polarity here,
# but home.nix does, deriving the XDG portal's color-scheme and the icon variant
# from it — that is what makes apps following "the system theme" follow this switch.
# So the light palette is a home-manager SPECIALISATION: a second full evaluation
# of the HM config, declared in modules/home-manager/stylix.nix. Activating it
# relinks every stylix-generated file at once — kitty, neovim, bat, zellij,
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
# dark behind your back. That is what `restore` is for: the theme-sync unit runs it
# at login, and it re-applies whatever palette was last CHOSEN.
#
# Which makes the two state sources deliberately different, and neither redundant:
#   the mode file  is INTENT   — the last palette explicitly asked for. Survives
#                                reboots and rebuilds. What `restore` reads.
#   current-home   is REALITY  — the generation actually activated. What `toggle`
#                                reads, so it always flips away from what is on
#                                screen even when a rebuild desynced the two.
#
# There is no time-of-day switching. It existed, keyed to 09:00/18:00 via a
# theme-sync.timer, and was removed: the palette now changes only when asked.
set -u

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
state_dir="$state_home/hypr"
mode_file="$state_dir/theme-mode"
# Ephemeral push channel the quickshell bar tails. Unlike the mode file this must
# NOT persist — the same split Paths.qml already makes for its other qs-* files.
runtime_dir="${XDG_RUNTIME_DIR:?refusing to fall back to world-writable /tmp}"
# stylix regenerates this on every switch and linkGeneration has just relinked it,
# so it always describes the palette that is live. Both the Hyprland border push and
# the neovim re-theme read it rather than carrying their own copy of the hexes.
palette_file="${XDG_CONFIG_HOME:-$HOME/.config}/stylix/palette.json"
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
  echo "usage: set-theme {dark|light|toggle|restore}" >&2
  exit 2
}

want=${1:-}
case "$want" in
  dark | light | toggle | restore) ;;
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

# RECORDED intent, as opposed to active_mode's reality. Only these two words are
# accepted: a truncated or hand-edited file must not decide the palette, and dark is
# the parent generation, i.e. where a plain rebuild already leaves the system.
saved_mode() {
  local saved
  saved=$(cat "$mode_file" 2>/dev/null || true)
  case "$saved" in
    light) echo light ;;
    *) echo dark ;;
  esac
}

active=$(active_mode)

case "$want" in
  dark | light) mode="$want" ;;
  # Deliberately the FILE and not active_mode: right after a rebuild those two
  # disagree, and the file is the one holding what was actually asked for.
  restore) mode="$(saved_mode)" ;;
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

# Push the palette into the running Hyprland WITHOUT reloading its config.
#
# THIS IS THE WHOLE REASON A SWITCH IS CHEAP. Hyprland's only theme-dependent
# setting is three colours under `general.col`. Deriving them from stylix in
# hyprland.lua looked obviously right and was the expensive mistake: it left that
# file differing between the two generations, so home-manager's onChange hook for
# it ran `hyprctl reload config-only` on every switch.
#
# What that reload costs, measured on the hardware rather than reasoned about:
# both external monitors' DDC brightness went 41% -> 100%, reproducibly, with
# monitor-watcher.service stopped so setup-monitors.sh could not be the cause.
# They do not persist a DDC write and fall back to their OSD default when the link
# is re-initialised, and nothing ever puts the value back. The internal panel is
# unaffected because it is sysfs backlight, not DDC. `config-only` does not help --
# it limits Hyprland's own monitor pass, not the re-init.
#
# So hyprland.lua now carries static hexes and this pushes the live palette over
# `hyprctl eval`: no reload, no `configreloaded`, no monitor-watcher wakeup, no
# flicker, brightness untouched. theme-invariants-<host> fails if hyprland.lua ever
# starts differing between the palettes again.
#
# The hexes come from stylix's own palette.json, which linkGeneration just
# relinked, so they always match the generation that is live and there is no second
# copy to keep in sync here.
#
# hyprctl's exit code is unusable under the Lua config parser, so classify the
# output text instead — same reason as every other script here.
push_hyprland_palette() {
  local b01 b09 b0A out
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null || return 0

  read -r b01 b09 b0A < <(jq -r '[.base01, .base09, .base0A] | @tsv' "$palette_file" 2>/dev/null)
  # A missing file, a missing key (jq prints "null") or a renamed scheme format all
  # land here. Cosmetic-only, so it warns rather than failing the switch: every
  # other target already has the new palette, and the borders correct themselves on
  # the next rebuild.
  if [[ ${b01-}${b09-}${b0A-} =~ ^[0-9a-fA-F]{18}$ ]]; then
    out=$(hyprctl eval "hl.config({ general = { col = { active_border = { colors = { \"rgba(${b0A}ff)\", \"rgba(${b09}ff)\" }, angle = 45 }, inactive_border = \"rgba(${b01}ff)\" } } })" 2>&1 || true)
    case "$out" in
      "" | ok | warning:*) ;;
      *) echo "set-theme: hyprctl eval said: $out" >&2 ;;
    esac
  else
    echo "set-theme: no usable base01/base09/base0A in $palette_file — hyprland borders keep the old palette until the next reload" >&2
  fi
}

# Re-theme neovim WITHOUT re-sourcing its config.
#
# `:source $MYVIMRC` is the obvious move and is wrong here: editors/neovim/lua/
# lsp.lua and editors/neovim/default.nix create autocmds (LspAttach, FileType) with
# no augroup, so a second sourcing registers a SECOND copy of each and every switch
# compounds it. Re-running the palette call alone has no such accumulation --
# mini.base16 just redefines highlight groups.
#
# The call rebuilt here is byte-for-byte the one stylix bakes into the generated
# init.lua, read from the same palette.json, so there is no second copy of the hexes.
#
# --remote-expr, NOT --remote-send: remote-send feeds KEYSTROKES, which would type
# into the buffer of anyone sitting in insert mode. Every instance auto-listens on
# $XDG_RUNTIME_DIR/nvim.<pid>.0 with no flags, so nothing has to be configured.
reload_neovim() {
  local lua f sock
  command -v nvim >/dev/null && command -v jq >/dev/null || return 0

  lua=$(jq -r '[to_entries[] | select(.key|test("^base[0-9A-F]{2}$")) | "\(.key) = \"#\(.value)\""]
               | "require(\"mini.base16\").setup({ palette = { " + join(", ") + " } })"' \
    "$palette_file" 2>/dev/null) || return 0
  # A missing file or a renamed key format yields an empty list or "#null" hexes.
  # Cosmetic, so bail quietly rather than feeding nvim a broken palette.
  case "$lua" in '' | *'#null'*) return 0 ;; esac

  f=$(mktemp) || return 0
  printf '%s\n' "$lua" >"$f"
  for sock in "$runtime_dir"/nvim.*; do
    [ -S "$sock" ] || continue
    # A socket left behind by a crashed instance blocks rather than erroring, so
    # this needs the timeout. --remote-expr is synchronous, hence the rm below is
    # safe: every instance has read the file by the time the loop ends.
    timeout 2 nvim --server "$sock" --remote-expr "execute('luafile $f')" >/dev/null 2>&1 || true
  done
  rm -f "$f"
}

# zathura exposes its `:source` command on the session bus as SourceConfig, which
# re-runs the `set recolor-*` lines in the zathurarc activation just relinked. The
# bus name carries the pid (org.pwmt.zathura.PID-<pid>) and only exists while an
# instance is running, so no instances means the loop simply does not execute.
reload_zathura() {
  local name
  command -v busctl >/dev/null || return 0
  busctl --user list --no-legend 2>/dev/null | awk '{ print $1 }' |
    grep '^org\.pwmt\.zathura\.PID-' |
    while read -r name; do
      timeout 2 busctl --user call "$name" /org/pwmt/zathura org.pwmt.zathura SourceConfig >/dev/null 2>&1 || true
    done
}

# Already in the target state: skip the activation. It takes seconds and this path
# runs at every login and on every timer fire, so the guard is what keeps `auto`
# from being a recurring stall.
if [ "$mode" = "$active" ]; then
  publish "$mode" || fail "could not record the theme mode under $state_dir"
  # Not redundant on this path. hyprland.lua carries the DARK hexes as its
  # parse-time baseline (they have to be static -- see the long comment on
  # general.col in ../default.nix), so a session that starts while light is the
  # active generation draws dark borders until something corrects them. This is
  # that something: theme-sync runs `auto` at every login, lands here, and pushes
  # the live palette. Same reasoning as publish() above -- the no-op path still
  # owes the system a correction.
  push_hyprland_palette
  exit 0
fi

# ALWAYS a specialisation, never the parent — including for dark. The parent runs
# the full untrimmed activation (reloadSystemd + ecomonoAgents, ~11.5s of the
# 12.5s), so activating it to "go back to dark" made that direction 12x slower
# than going to light. specialisation/dark carries the same palette as the parent
# but the trimmed activation. See modules/home-manager/stylix.nix.
activate="$parent/specialisation/$mode/activate"

if [ ! -x "$activate" ]; then
  fail "no '$mode' generation yet — rebuild after adding specialisation.$mode to modules/home-manager/stylix.nix"
fi

# Activation is chatty and takes a few seconds. Keep a log for debugging but don't
# spam the caller.
"$activate" >"$log" 2>&1 || fail "activation of '$mode' failed — see $log"

# Only after activation succeeded, so a failed switch never leaves the bar and the
# filesystem disagreeing about what is on screen.
publish "$mode" || fail "switched to '$mode' but could not record it under $state_dir"

# Already-running apps do not re-read the files activation just relinked. Every
# entry below was checked against the installed binary rather than assumed, and all
# of it is cosmetic: nothing here can fail the switch, and any app that misses its
# reload is correct again the moment it restarts.
#
#   kitty    reloads its whole config on SIGUSR1 (kitty's own conf docs), which is
#            why no remote-control socket is configured.
#   foot     no reload hook exists: foot reads foot.ini only at startup and has no
#            SIGUSR1 equivalent. Open windows keep the old palette until reopened;
#            new windows are correct immediately. Consequence for zellij below: the
#            background re-pick only fires inside kitty windows, a live zellij in a
#            foot window stays on the old palette until that window restarts.
#   neovim   see reload_neovim.
#   zathura  see reload_zathura.
#   zed      needs nothing. ~/.config/zed/settings.json is a real file, merged in by
#            zedSettingsActivation rather than symlinked, and zed watches it — it
#            re-themes itself a second or so after the switch, no command involved.
#   bat      needs nothing. Never long-running, and the batCache activation step
#            recompiles the theme under the same name, so the next invocation is
#            already correct.
#   btop     no reload hook, and it does not need one: it reads its theme at
#            startup and is a foreground TUI you close rather than leave running
#            across a palette switch.
#   zellij   needs nothing HERE, and that is a measured result, not an omission.
#            zellij re-detects the terminal's background colour and re-picks between
#            its theme_dark and theme_light, so the kitty SIGUSR1 above is already
#            the trigger: measured at 1s after the switch, with no zellij call in
#            this script at all, a live session went base0E d3869b -> 8f3f71 and its
#            background to fbf1c7.
#            What that DEPENDS on is shells/zellij/{config.kdl,zellij.nix} declaring
#            theme_dark/theme_light and generating both palettes -- with a single
#            `theme` there is nothing to re-pick and the session stays stale. So the
#            fix for zellij is entirely in those two files.
#            A `zellij action set-{dark,light}-theme` loop was written here and then
#            removed as dead weight. It would only ever matter for a session attached
#            from a terminal that is not kitty, which does not happen on this setup.
pkill -USR1 -x kitty 2>/dev/null || true
reload_neovim
reload_zathura

push_hyprland_palette

exit 0

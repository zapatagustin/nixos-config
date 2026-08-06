#!/usr/bin/env bash
# Brightness key handler. Adjusts the internal backlight instantly, then chases
# any external DDC/CI monitors to the same percent.
#
# THE PERCENT IS PERCEPTUAL, and every `brightnessctl` call here passes -e$EXPONENT
# so that reads and writes share one scale. That sounds pedantic and was the bug:
# the script used to SET with an exponential curve and READ with the plain linear
# one, so the number handed to DDC was a different quantity than the one the keys
# were moving. Measured on the surface, the same raw value read on both scales --
# taken when the gamma was still 4, which is what made the gap so wide:
#
#   brightnessctl -m       -> 5%    <- what the externals used to get
#   brightnessctl -e4 -m   -> 47%   <- where the control actually was
#
# So the externals sat at DDC 5 while the control was near half travel, and the
# panel itself was at 4.9% of maximum raw and barely readable. Both halves of that
# are gone: one scale for both devices, and a MEASURED gamma.
#
# A monitor's DDC 0-100 already ships calibrated to look perceptually linear, so the
# value to send it is just the control's percent. Only the panel needs a curve, and
# how steep is a property of that panel -- on the surface, matching by eye against
# the externals put it at 1.087, i.e. barely any correction at all. See
# myDesktop.brightnessExponent for why the theoretical 2.2 was wrong here.
#
# Equalising real luminance is NOT what this does and cannot be done without a
# photometer -- the panels have different maximum nits and different floors.
#
# EXPONENT is prepended by wm/hyprland/default.nix from myDesktop.brightnessExponent.
# quickshell/bar/Brightness.qml carries the same number as a literal, pinned to this
# one by flake.nix's brightness-exponent check.
#
# Everything DDC-related happens inside one flock'd background worker: bus
# detection AND the writes. The bind is `bindle`, so holding the key fires this
# script dozens of times — work left outside the lock would run concurrently and
# thrash the i2c bus. The worker re-reads the internal % until it stops changing,
# so the externals converge one DDC round after the last keypress.
set -u

step=5
mode=${1:-up}
case "$mode" in
  up)   brightnessctl -e"$EXPONENT" -n2 set "${step}%+" >/dev/null ;;
  down) brightnessctl -e"$EXPONENT" -n2 set "${step}%-" >/dev/null ;;
  # sync: change nothing, just re-assert the current percent on the externals.
  #
  # They need it because a DDC write is not durable on them: the monitors revert to
  # their OSD default (100%) whenever the link is re-initialised, and nothing used
  # to put the value back. Measured triggers, all of them ordinary: `dpms off/on`
  # (hypridle fires it after 6 minutes idle), a lock/unlock, suspend/resume, a dock
  # change, and any `hyprctl reload`. The internal panel is unaffected because it is
  # sysfs backlight, not DDC -- which is exactly why the two used to drift apart.
  sync) ;;
  *)
    echo "usage: brightness {up|down|sync}" >&2
    exit 2
    ;;
esac
runtime_dir="${XDG_RUNTIME_DIR:?refusing to fall back to world-writable /tmp}"

# OSD refresh (bar tails this file). Only for the key presses: a sync is a repair
# nobody asked for, and popping the OSD on every idle-resume would announce it.
case "$mode" in
  up | down) echo . >> "$runtime_dir/qs-brightness" ;;
esac

# External monitors: DDC/CI via ddcutil. No-op when ddcutil is absent (undocked
# host / thinkpad) or no external DDC display is present.
command -v ddcutil >/dev/null || exit 0

buses="$runtime_dir/ddc-buses"

(
  # -n: if a worker is already chasing the value, this keypress adds nothing —
  # the running worker re-reads and converges. Only ever one DDC writer.
  flock -n 9 || exit 0

  # Bus list is slow to detect (~3s), so cache it. monitor-watcher.sh removes the
  # cache on monitor hotplug, so it rebuilds on the next keypress after a dock
  # change. detect also lists buses it marks "Invalid display" (eDP-1 has one),
  # so probe each with a getvcp and keep only the ones that actually answer DDC —
  # otherwise every write round burns ~0.4s on retries against a dead bus.
  #
  # An undocked host has zero valid buses, which used to leave $buses empty —
  # indistinguishable from "not yet probed", so every keypress re-ran the ~3s
  # detect. A NONE sentinel line records "probed, zero buses" so the cache is
  # honored either way; only removing the file (monitor-watcher.sh) invalidates it.
  if [ ! -s "$buses" ]; then
    {
      ddcutil detect --brief 2>/dev/null \
        | grep -oP 'I2C bus:\s+/dev/i2c-\K[0-9]+' \
        | while read -r bus; do
            ddcutil --bus "$bus" --sleep-multiplier=.5 getvcp 10 >/dev/null 2>&1 \
              && echo "$bus"
          done
    } > "$buses"
    [ -s "$buses" ] || echo NONE > "$buses"
  fi
  grep -qx NONE "$buses" && exit 0

  last=""
  while :; do
    cur=$(brightnessctl -e"$EXPONENT" -m | cut -d, -f4 | tr -d '%')
    [ "$cur" = "$last" ] && break
    last=$cur
    # One ddcutil per bus, all at once: every external lands in the same DDC
    # round instead of one after the other. --noverify skips the slow read-back;
    # --sleep-multiplier trims DDC delays.
    while read -r bus; do
      ddcutil --bus "$bus" --noverify --sleep-multiplier=.5 setvcp 10 "$cur" >/dev/null 2>&1 &
    done < "$buses"
    wait
  done

  # A keypress writes once and is done: the monitor is awake and the internal percent
  # has settled. A sync is neither. It races hypridle's own on-resume chain -- the
  # dim-then-restore listener in ../default.nix puts the panel back with
  # `brightnessctl -r`, and hypridle promises no order between listeners -- so the
  # loop above can write a percent that is still the dimmed one and leave the
  # externals at 20% under a 41% laptop. Keep watching the internal value for a
  # moment and chase it if the restore lands late.
  #
  # Deliberately NOT a DDC read-back to confirm the monitors took the value. That was
  # the first cut of this and it cost 1.24s of the 3.38s: i2c is serialised in
  # hardware, so reading two buses "in parallel" takes 1.24s against 1.54s
  # sequentially -- 0.31s for a subshell, word splitting and a shellcheck exception.
  # It also only ever answered yes: a write lands reliably once the link is up,
  # measured across dpms, unlock and dock cycles. What actually goes wrong is the
  # internal percent moving, and brightnessctl reads that in 0.00s.
  [ "$mode" = sync ] || exit 0
  for _ in 1 2 3 4; do
    sleep 0.25
    cur=$(brightnessctl -e"$EXPONENT" -m | cut -d, -f4 | tr -d '%')
    [ "$cur" = "$last" ] && continue
    last=$cur
    while read -r bus; do
      ddcutil --bus "$bus" --noverify --sleep-multiplier=.5 setvcp 10 "$cur" >/dev/null 2>&1 &
    done < "$buses"
    wait
  done
) 9>"$runtime_dir/ddc-bright.lock" &

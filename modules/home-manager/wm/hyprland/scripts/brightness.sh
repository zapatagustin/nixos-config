#!/usr/bin/env bash
# Brightness key handler. Adjusts the internal backlight instantly, then chases
# any external DDC/CI monitors to the same percent.
#
# Everything DDC-related happens inside one flock'd background worker: bus
# detection AND the writes. The bind is `bindle`, so holding the key fires this
# script dozens of times — work left outside the lock would run concurrently and
# thrash the i2c bus. The worker re-reads the internal % until it stops changing,
# so the externals converge one DDC round after the last keypress.
set -u

step=5
case "${1:-up}" in
  up)   brightnessctl -e4 -n2 set "${step}%+" >/dev/null ;;
  down) brightnessctl -e4 -n2 set "${step}%-" >/dev/null ;;
esac
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"

echo . >> "$runtime_dir/qs-brightness" # OSD refresh (bar tails this file)

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
    cur=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
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
) 9>"$runtime_dir/ddc-bright.lock" &

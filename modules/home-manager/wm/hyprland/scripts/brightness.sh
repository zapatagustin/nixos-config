#!/usr/bin/env bash
# Brightness key handler. Adjusts the internal backlight instantly, then chases
# any external DDC/CI monitors to the same percent.
#
# A single flock'd background worker re-reads the internal % until it stops
# changing, so holding the key never queues slow DDC writes — the externals just
# converge to the final value one DDC round after the last keypress.
set -u

step=5
case "${1:-up}" in
  up)   brightnessctl -e4 -n2 set "${step}%+" >/dev/null ;;
  down) brightnessctl -e4 -n2 set "${step}%-" >/dev/null ;;
esac
echo . >> /tmp/qs-brightness # OSD refresh (bar tails this file)

# External monitors: DDC/CI via ddcutil. No-op when ddcutil is absent (undocked
# host / thinkpad) or no external DDC display is present.
command -v ddcutil >/dev/null || exit 0

# Bus list is slow to detect (~2s), so cache it. monitor-watcher.sh removes the
# cache on monitor hotplug, so it rebuilds on the next keypress after a dock change.
buses=/tmp/ddc-buses
if [ ! -s "$buses" ]; then
  ddcutil detect --brief 2>/dev/null \
    | grep -oP 'I2C bus:\s+/dev/i2c-\K[0-9]+' > "$buses" || true
fi
[ -s "$buses" ] || exit 0

(
  # -n: if a worker is already chasing the value, this keypress adds nothing —
  # the running worker re-reads and converges. Only ever one DDC writer.
  flock -n 9 || exit 0
  last=""
  while :; do
    cur=$(brightnessctl -m | cut -d, -f4 | tr -d '%')
    [ "$cur" = "$last" ] && break
    last=$cur
    while read -r bus; do
      # --noverify skips the slow read-back; --sleep-multiplier trims DDC delays.
      ddcutil --bus "$bus" --noverify --sleep-multiplier=.5 setvcp 10 "$cur" >/dev/null 2>&1
    done < "$buses"
  done
) 9>/tmp/ddc-bright.lock &

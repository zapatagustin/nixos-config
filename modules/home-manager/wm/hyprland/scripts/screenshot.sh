#!/usr/bin/env bash
# Screenshots con grim + slurp. Copia al clipboard y guarda en ~/Pictures/Screenshots.
# Uso: screenshot.sh [region|window|output|screen]
set -euo pipefail

mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$mode" in
  region)  geom=$(slurp) ;;                                              # selección con el mouse
  window)  geom=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') ;;
  output)  geom=$(slurp -o) ;;                                           # monitor bajo el cursor
  screen)  geom="" ;;                                                    # todo
  *) echo "uso: $0 [region|window|output|screen]" >&2; exit 1 ;;
esac

if [ -n "$geom" ]; then
  grim -g "$geom" "$file"
else
  grim "$file"
fi

wl-copy < "$file"
notify-send "Screenshot" "Guardado en $file" -i "$file" 2>/dev/null || true

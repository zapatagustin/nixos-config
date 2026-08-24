#!/usr/bin/env bash
# Screenshots con grim + slurp. Copia al clipboard y guarda en ~/Pictures/Screenshots.
# Uso: screenshot.sh [region|window|output|screen|edit]
#
# region: congela la pantalla (hyprpicker -r -z) mientras slurp selecciona, así
# el contenido no se mueve a mitad de captura. slurp recibe los rects de las
# ventanas visibles: un CLICK (selección < 20x20) se ajusta a la ventana bajo
# el cursor, un drag selecciona libre. La notificación trae botón "Editar" que
# abre satty sobre el archivo guardado.
set -euo pipefail

mode="${1:-region}"
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

# edit: región → satty para anotar (satty copia/guarda desde su UI)
if [ "$mode" = "edit" ]; then
  grim -g "$(slurp)" - | satty --filename - --copy-command wl-copy --output-filename "$file"
  exit 0
fi

# visible_rects + snap_to_rect, compartidas con screenrecord.sh
source "$(dirname "$0")/capture-rects.sh"

freeze_pid=""
cleanup() { [ -n "$freeze_pid" ] && kill "$freeze_pid" 2>/dev/null || true; }
trap cleanup EXIT

case "$mode" in
  region)
    # hyprpicker -r -z pinta la pantalla congelada como layer; slurp dibuja
    # encima. Sin esto, el contenido (video, notificaciones) se mueve entre
    # la selección y el grim.
    hyprpicker -r -z &
    freeze_pid=$!
    sleep 0.1 # hyprpicker necesita un frame para montar su layer
    geom=$(visible_rects | slurp) || exit 0 # Esc = cancelar, sin captura
    geom=$(snap_to_rect "$geom")
    ;;
  window) geom=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') ;;
  output) geom=$(slurp -o) ;;                                           # monitor bajo el cursor
  screen) geom="" ;;                                                    # todo
  *) echo "uso: $0 [region|window|output|screen|edit]" >&2; exit 1 ;;
esac

if [ -n "$geom" ]; then
  grim -g "$geom" "$file"
else
  grim "$file"
fi
cleanup
freeze_pid=""

wl-copy < "$file"
# -A bloquea hasta accion/timeout e imprime la elegida; si el daemon no
# soporta actions, sale vacio y el || true evita matar el script (set -e).
action=$(notify-send -A edit=Editar "Screenshot" "Guardado en $file" -i "$file" 2>/dev/null) || true
if [ "${action:-}" = "edit" ]; then
  satty --filename "$file" --copy-command wl-copy --output-filename "$file"
fi

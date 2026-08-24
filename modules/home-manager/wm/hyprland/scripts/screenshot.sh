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

# Rects de ventanas visibles (workspaces activos de cada monitor) + monitores,
# en coordenadas lógicas. Los monitores reportan tamaño físico: se divide por
# scale y se intercambia w/h si el transform es impar (rotado 90/270).
visible_rects() {
  local mons clients
  mons=$(hyprctl monitors -j)
  clients=$(hyprctl clients -j)
  jq -nr --argjson m "$mons" --argjson c "$clients" '
    ($m | map(.activeWorkspace.id)) as $active
    | ($c | map(select(.mapped and (.workspace.id as $w | $active | index($w)))
        | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"))
      + ($m | map(
          (if .transform % 2 == 1 then [.height, .width] else [.width, .height] end) as $wh
          # round, no floor: hyprctl redondea .scale (1.5666667), y dividir por
          # el scale redondeado da 1439.9999 para un ancho logico real de 1440
          | "\(.x),\(.y) \(($wh[0] / .scale | round))x\(($wh[1] / .scale | round))"))
    | .[]'
}

# Selección chica = fue un click, no un drag: ajustar al primer rect que
# contiene el punto (ventanas primero, monitores después — visible_rects ya
# emite en ese orden).
snap_to_rect() {
  local sel="$1" x y w h
  x=${sel%%,*}; y=${sel#*,}; y=${y%% *}
  w=${sel##* }; h=${w#*x}; w=${w%x*}
  if [ "$((w * h))" -ge 400 ]; then
    echo "$sel"
    return 0
  fi
  visible_rects | while IFS= read -r rect; do
    local rx ry rw rh
    rx=${rect%%,*}; ry=${rect#*,}; ry=${ry%% *}
    rw=${rect##* }; rh=${rw#*x}; rw=${rw%x*}
    if [ "$x" -ge "$rx" ] && [ "$x" -lt "$((rx + rw))" ] &&
      [ "$y" -ge "$ry" ] && [ "$y" -lt "$((ry + rh))" ]; then
      echo "$rect"
      return 0
    fi
  done | head -1 | grep . || echo "$sel"
}

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

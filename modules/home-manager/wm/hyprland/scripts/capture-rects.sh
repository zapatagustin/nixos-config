#!/usr/bin/env bash
# Lib sourceada por screenshot.sh y screenrecord.sh: rects de ventanas/monitores
# para slurp, snap de click a rect, y clasificación de la selección en
# monitor/región para gpu-screen-recorder. No ejecuta nada por sí sola.

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

# Clasifica una selección "X,Y WxH" para gpu-screen-recorder: si coincide
# exacto con un monitor emite "monitor:NAME" (captura nativa, sin math de
# escala), si no "region:WxH+X+Y" (gsr trabaja en coordenadas lógicas, las
# mismas que devuelve slurp — pasan sin tocar).
classify_capture_target() {
  local sel="$1" x y w h monitor
  x=${sel%%,*}; y=${sel#*,}; y=${y%% *}
  w=${sel##* }; h=${w#*x}; w=${w%x*}
  monitor=$(hyprctl monitors -j | jq -r \
    --argjson x "$x" --argjson y "$y" --argjson w "$w" --argjson h "$h" '
    .[] | (if .transform % 2 == 1 then [.height, .width] else [.width, .height] end) as $wh
    | select(.x == $x and .y == $y
        and ($wh[0] / .scale | round) == $w and ($wh[1] / .scale | round) == $h)
    | .name' | head -1)
  if [ -n "$monitor" ]; then
    echo "monitor:$monitor"
  else
    echo "region:${w}x${h}+${x}+${y}"
  fi
}

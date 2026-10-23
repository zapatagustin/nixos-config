#!/bin/bash
# Enfoca la primera ventana cuyo class matchea el regex (case-insensitive);
# si no existe, lanza el comando. Match por class, no por título: los títulos
# cambian con el contenido (un tab del browser que nombra la app daría falso
# positivo).
#
# Sin set -e a propósito: hc() retorna 1 en fallas para acumularlas y
# notificarlas via hc_notify — ver hyprctl-classify.sh.
source "$(dirname "$0")/hyprctl-classify.sh"

pattern=${1:?usage: launch-or-focus.sh <regex> <command...>}
shift

addr=$(hyprctl clients -j | jq -r --arg re "$pattern" \
    '[.[] | select(.class | test($re; "i"))][0].address // empty')

if [ -n "$addr" ]; then
    hc dispatch "hl.dsp.focus({ window = \"address:$addr\" })"
    hc_notify "launch-or-focus"
    exit 0
fi
exec uwsm app -- "$@"

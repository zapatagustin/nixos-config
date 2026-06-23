#!/bin/bash
# Detecta monitores conectados y exporta:
#   LEFT_SAMSUNG, RIGHT_SAMSUNG  — puertos de los dos Samsung LF27T35 (ordenados por nombre)
#   EDP                          — puerto del built-in (eDP-1)
# Ambos Samsung comparten EDID (mismo modelo+serial) → no se pueden distinguir;
# se asignan deterministicamente por orden lexicogr\u00e1fico del nombre de puerto.

mapfile -t _samsungs < <(hyprctl -j monitors | jq -r '.[] | select(.description | contains("LF27T35")) | .name' | sort)
LEFT_SAMSUNG="${_samsungs[0]:-}"
RIGHT_SAMSUNG="${_samsungs[1]:-}"
EDP=$(hyprctl -j monitors | jq -r '.[] | select(.name | startswith("eDP")) | .name' | head -n1)
EDP="${EDP:-eDP-1}"

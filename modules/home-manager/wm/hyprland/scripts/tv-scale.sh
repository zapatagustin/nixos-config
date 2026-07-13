#!/bin/bash
# Alterna la TV 4K (HDMI-A-1) entre modo juego y modo escritorio:
#   juego:      scale 1 (4K nativo) + cm,hdr  → los juegos ven salida HDR
#   escritorio: scale 2 (UI grande) + cm,wide → SDR wide gamut (HDR deja gris el desktop)
# Sin argumento: toggle según el modo de color ACTUAL (hdr ⇄ wide).
# Con argumento: `tv-scale.sh juego` | `tv-scale.sh escritorio` (o 1 | 2).
#
# Los clientes (gamescope, winewayland/dxgi) preguntan al compositor si la
# salida es HDR al arrancar — si está en cm,wide reporta 80 nits SDR y el juego
# nunca ofrece HDR. Por eso el modo juego fuerza cm,hdr ANTES de lanzar.

set -u

MON=HDMI-A-1
MODE=3840x2160@60
POS=0x0

# Modo de color actual (hyprctl -j no expone cm; se parsea el output de texto)
current_cm=$(hyprctl monitors all | grep -A 30 "Monitor $MON" | grep -m1 colorManagementPreset | awk '{print $2}')

if [ -z "$current_cm" ]; then
    echo "La TV ($MON) no está conectada."
    exit 1
fi

# Decidir el modo destino
case "${1:-}" in
    1|juego|game) target=juego ;;
    2|escritorio|desktop) target=escritorio ;;
    "")
        # Toggle por modo de color: hdr → escritorio, cualquier otro → juego
        if [ "$current_cm" = "hdr" ]; then
            target=escritorio
        else
            target=juego
        fi
        ;;
    *) echo "Uso: $(basename "$0") [juego|escritorio]"; exit 1 ;;
esac

if [ "$target" = juego ]; then
    hyprctl keyword monitor "$MON,$MODE,$POS,1,bitdepth,10,cm,hdr"
    hyprctl notify -1 3000 "rgb(fabd2f)" "  TV: modo juego (4K nativo + HDR)"
else
    # La transición PQ→SDR deja el link HDMI mal negociado (blancos quemados,
    # mismatch de rango). Ciclar por srgb 8-bit fuerza renegociación completa.
    if [ "$current_cm" = "hdr" ]; then
        hyprctl keyword monitor "$MON,$MODE,$POS,2,bitdepth,8,cm,srgb"
        sleep 2
    fi
    hyprctl keyword monitor "$MON,$MODE,$POS,2,bitdepth,10,cm,wide"
    hyprctl notify -1 3000 "rgb(83a598)" "  TV: modo escritorio (scale 2, SDR)"
fi

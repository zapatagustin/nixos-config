#!/bin/bash
# Toggles the 4K TV (HDMI-A-1) between game mode and desktop mode:
#   juego (game):      scale 1 (native 4K) + cm,hdr  → games see HDR output
#   escritorio (desktop): scale 2 (big UI) + cm,wide → SDR wide gamut (HDR grays out the desktop)
# No argument: toggle based on the CURRENT color mode (hdr ⇄ wide).
# With an argument: `tv-scale.sh juego` | `tv-scale.sh escritorio` (or 1 | 2).
#
# Clients (gamescope, winewayland/dxgi) ask the compositor whether the output
# is HDR at startup — if it's on cm,wide it reports 80 nits SDR and the game
# never offers HDR. That's why game mode forces cm,hdr BEFORE launching.

set -u

MON=HDMI-A-1
MODE=3840x2160@60
POS=0x0

# Current color mode (hyprctl -j doesn't expose cm; parse the text output instead)
current_cm=$(hyprctl monitors all | grep -A 30 "Monitor $MON" | grep -m1 colorManagementPreset | awk '{print $2}')

if [ -z "$current_cm" ]; then
    echo "La TV ($MON) no está conectada."
    exit 1
fi

# Decide the target mode
case "${1:-}" in
    1|juego|game) target=juego ;;
    2|escritorio|desktop) target=escritorio ;;
    "")
        # Toggle by color mode: hdr → escritorio (desktop), anything else → juego (game)
        if [ "$current_cm" = "hdr" ]; then
            target=escritorio
        else
            target=juego
        fi
        ;;
    *) echo "Uso: $(basename "$0") [juego|escritorio]"; exit 1 ;;
esac

# Hyprland 0.55+ with a Lua config: `hyprctl keyword` is gone, `hyprctl eval` runs the
# config-time Lua call and applies live. Translation map in wm/hyprland/default.nix.
set_tv() { hyprctl eval "hl.monitor({ output = \"$MON\", mode = \"$MODE\", position = \"$POS\", scale = $1, bitdepth = $2, cm = \"$3\" })"; }

if [ "$target" = juego ]; then
    set_tv 1 10 hdr
    hyprctl notify -1 3000 "rgb(fabd2f)" "  TV: modo juego (4K nativo + HDR)"
else
    # The PQ→SDR transition leaves the HDMI link mis-negotiated (blown-out whites,
    # range mismatch). Cycling through srgb 8-bit forces a full renegotiation.
    if [ "$current_cm" = "hdr" ]; then
        set_tv 2 8 srgb
        sleep 2
    fi
    set_tv 2 10 wide
    hyprctl notify -1 3000 "rgb(83a598)" "  TV: modo escritorio (scale 2, SDR)"
fi

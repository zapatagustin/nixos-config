#!/bin/bash
# Detects connected monitors and exports:
#   LEFT_SAMSUNG, RIGHT_SAMSUNG  — ports of the two Samsung LF27T35s (sorted by name)
#   EDP                          — port of the built-in display (eDP-1)
# Both Samsungs share the same EDID (same model+serial) → they can't be told apart;
# they're assigned deterministically by lexicographic order of the port name.

mapfile -t _samsungs < <(hyprctl -j monitors | jq -r '.[] | select(.description | contains("LF27T35")) | .name' | sort)
LEFT_SAMSUNG="${_samsungs[0]:-}"
RIGHT_SAMSUNG="${_samsungs[1]:-}"
EDP=$(hyprctl -j monitors | jq -r '.[] | select(.name | startswith("eDP")) | .name' | head -n1)
EDP="${EDP:-eDP-1}"

#!/bin/bash
# Lista los binds de Hyprland para el cheat-sheet (Cheatsheet.qml).
# Formato: "COMBO\tdescripcion" por linea, igual que get-apps.sh.
#
# `hyprctl binds -j` es la unica fuente: con config Lua cada bind reporta
# dispatcher "__lua" y un `arg` numerico opaco, asi que el `description` que
# default.nix pone en la tabla de opts es lo UNICO legible. Los binds sin
# description (has_description=false) son plumbing y se descartan aca, no en QML.
#
# El modmask es la mascara de modificadores de xkb, no un enum de Hyprland:
# SHIFT=1 CAPS=2 CTRL=4 ALT=8 NUM=16 MOD3=32 SUPER=64 ALTGR=128. jq 1.7 no tiene
# operadores bitwise, de ahi el (m/bit|floor)%2 para probar cada bit.
#
# Orden: modmask y despues key, hecho en jq para que QML solo renderice.

hyprctl binds -j | jq -r '
  def mods($m):
    [ {b:64,n:"SUPER"}, {b:4,n:"CTRL"}, {b:8,n:"ALT"}, {b:1,n:"SHIFT"},
      {b:2,n:"CAPS"}, {b:128,n:"ALTGR"} ]
    | map(select((($m / .b) | floor) % 2 == 1) | .n);

  map(select(.has_description))
  | sort_by(.modmask, .key)
  | .[]
  | (mods(.modmask) + [.key] | join(" + ")) + "\t" + .description
'

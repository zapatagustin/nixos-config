# Ordered-dither render of a public-domain engraving, in the theme palette.
#
# Plate: Gustave Dore, "Abandon all hope ye who enter here" (Inferno, Canto III,
# Plate 8), from "The Divine Comedy" (1861). Public domain (author d. 1883,
# first published 1861). Source:
# https://commons.wikimedia.org/wiki/File:Gustave_Dor%C3%A9_-_Dante_Alighieri_-_Inferno_-_Plate_8_(Canto_III_-_Abandon_all_hope_ye_who_enter_here).jpg
#
# Output is a 2-colour palette PNG at exactly width x height: the image is
# dithered at (width/scale x height/scale), then nearest-neighbour upscaled so
# every dither dot is a crisp scale x scale block at native resolution.
# `bg`/`fg` are bare or #-prefixed hex colours (black maps to bg, white to fg).
#
# Used by the hyprlock background; slice 3 reuses it for the eDP wallpaper.
{ lib, runCommand, imagemagick, fetchurl }:
{ name ? "dore-dither"
, plate ? fetchurl {
    # explicit name: the URL's percent-decoded basename holds non-ASCII bytes
    name = "dore-inferno-plate-8.jpg";
    url = "https://upload.wikimedia.org/wikipedia/commons/3/3e/Gustave_Dor%C3%A9_-_Dante_Alighieri_-_Inferno_-_Plate_8_%28Canto_III_-_Abandon_all_hope_ye_who_enter_here%29.jpg";
    hash = "sha256-AXPvozxOttjdnoRdilHugya8Cpdg6vnIEdQUorp4Z44=";
  }
, width
, height
, bg
, fg
, scale ? 2
, levels ? 2
}:
assert lib.assertMsg (scale >= 1) "dore-dither: scale must be >= 1";
assert lib.assertMsg (lib.mod width scale == 0 && lib.mod height scale == 0)
  "dore-dither: width/height (${toString width}x${toString height}) must be divisible by scale (${toString scale})";
let
  hex = lib.removePrefix "#";
  w = toString (width / scale);
  h = toString (height / scale);
in
runCommand "${name}.png" { nativeBuildInputs = [ imagemagick ]; } ''
  magick ${plate} \
    -colorspace Gray -resize ${w}x${h}^ -gravity center -extent ${w}x${h} \
    -auto-level \
    -ordered-dither o8x8,${toString levels} \
    +level-colors '#${hex bg},#${hex fg}' \
    -filter point -resize ${toString (scale * 100)}% \
    -type Palette PNG8:$out
''

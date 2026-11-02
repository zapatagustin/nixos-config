# The omp startup banner: the eDP wallpaper's engraving (theme/dore-dither.nix,
# already two palette colours) cropped to its winged figure and sized for a
# terminal, as a 2-colour PNG the ecomono extension draws with omp's inline
# image support (kitty / sixel; foot answers the sixel probe). The crop is the
# one the extension's block-glyph fallback was cut from, so both show the same
# figure. 640 px wide: about 72 terminal cells at the VGA font's 8 px advance.
{ runCommand, imagemagick, wallpaper }:
runCommand "omp-banner.png" { nativeBuildInputs = [ imagemagick ]; } ''
  magick ${wallpaper} -gravity center -crop 62%x40%+0+12% +repage \
    -resize 640x -colors 2 PNG8:$out
''

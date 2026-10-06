# PxPlus IBM VGA8 by VileR (https://int10h.org), outline (vector) version,
# v1.0-2015-11, licensed CC BY-SA 4.0. The TTF is vendored in ./fonts so the
# build does not depend on a third-party mirror; it was originally obtained from
# pocketfood/Fontpkg-PxPlus_IBM_VGA8 at rev a761329065755af0582a4607046e575b5839567f.
{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  pname = "pxplus-ibm-vga8";
  version = "1.0-2015-11";

  src = ./fonts;

  installPhase = ''
    runHook preInstall

    install -Dm644 PxPlus_IBM_VGA8.ttf "$out/share/fonts/truetype/PxPlus_IBM_VGA8.ttf"

    install -Dm644 /dev/stdin "$out/share/doc/pxplus-ibm-vga8/ATTRIBUTION" <<'EOF2'
    PxPlus IBM VGA8
    Author: VileR (https://int10h.org)
    Version: v1.0-2015-11 (outline/vector version, (c) 2015 VileR)
    License: Creative Commons Attribution-ShareAlike 4.0 International
    https://creativecommons.org/licenses/by-sa/4.0/
    Originally obtained from the pocketfood/Fontpkg-PxPlus_IBM_VGA8 mirror,
    rev a761329065755af0582a4607046e575b5839567f.
    EOF2

    runHook postInstall
  '';

  meta = {
    description = "PxPlus IBM VGA8 bitmap-inspired TrueType font";
    homepage = "https://int10h.org/oldschool-pc-fonts/";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.all;
  };
}

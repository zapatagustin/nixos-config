{ lib, stdenvNoCC, fetchFromGitHub }:
stdenvNoCC.mkDerivation {
  pname = "pxplus-ibm-vga8";
  version = "0-unstable-2023-10-24";

  src = fetchFromGitHub {
    owner = "pocketfood";
    repo = "Fontpkg-PxPlus_IBM_VGA8";
    rev = "a761329065755af0582a4607046e575b5839567f";
    hash = "sha256-o7n5BmudNtKsaZtWbWVkQt5oo7vy0cVl4+0Adp+Blx0=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm644 PxPlus_IBM_VGA8.ttf "$out/share/fonts/truetype/PxPlus_IBM_VGA8.ttf"

    install -Dm644 /dev/stdin "$out/share/doc/pxplus-ibm-vga8/LICENSE" <<'EOF'
    PxPlus IBM VGA8
    =================

    Font: PxPlus IBM VGA8
    Original font: IBM VGA 8x16
    Conversion / BDF source: VileR (https://int10h.org)
    GitHub mirror: pocketfood / Fontpkg-PxPlus_IBM_VGA8

    The original IBM VGA 8x16 glyph bitmaps are distributed by the
    upstream int10h.org project under the Creative Commons Attribution-
    ShareAlike 4.0 International license.

    You may use, share and adapt this font for any purpose, provided you
    give appropriate credit and distribute derivatives under the same
    license.

    Full license text: https://creativecommons.org/licenses/by-sa/4.0/
    EOF

    runHook postInstall
  '';

  meta = {
    description = "PxPlus IBM VGA8 bitmap-inspired TrueType font";
    homepage = "https://github.com/pocketfood/Fontpkg-PxPlus_IBM_VGA8";
    license = lib.licenses.cc-by-sa-40;
    platforms = lib.platforms.all;
  };
}

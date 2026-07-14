# Brave Origin — Brave's minimalist variant (no Rewards/Wallet/VPN/Leo AI).
# Free on Linux, but NOT in nixpkgs (new in 2026), so we build it ourselves.
#
# Rather than duplicate brave's large dependency/rpath setup, we re-point the
# nixpkgs `brave` derivation at the upstream brave-origin .deb. That deb uses an
# `opt/brave.com/brave-origin/` layout; preInstall renames it to the `brave`
# layout so brave's own installPhase (incl. its rpath/patchelf) runs unchanged,
# then postInstall re-labels the output as `brave-origin`.
#
# Bump: pick the newest brave-origin_<ver>_amd64.deb from
#   https://github.com/brave/brave-browser/releases
# then refresh the hash with:  nix store prefetch-file <url>
{ brave, fetchurl }:

let
  version = "1.92.131";
in
brave.overrideAttrs (old: {
  pname = "brave-origin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/brave/brave-browser/releases/download/v${version}/brave-origin_${version}_amd64.deb";
    hash = "sha256-faSx7ZSWGRCpSHUkPeP3vETjaE0ci0NM4j/cKEuDakU=";
  };

  # Rename the Origin layout to the one brave's installPhase expects, so the
  # upstream install/patchelf logic works verbatim.
  preInstall = ''
    mv opt/brave.com/brave-origin opt/brave.com/brave
    mv opt/brave.com/brave/brave-origin opt/brave.com/brave/brave-browser

    for d in brave-origin com.brave.Origin; do
      substituteInPlace usr/share/applications/$d.desktop \
        --replace-warn /usr/bin/brave-origin-stable /usr/bin/brave-browser-stable
    done
    mv usr/share/applications/brave-origin.desktop      usr/share/applications/brave-browser.desktop
    mv usr/share/applications/com.brave.Origin.desktop  usr/share/applications/com.brave.Browser.desktop

    substituteInPlace usr/share/gnome-control-center/default-apps/brave-origin.xml \
      --replace-warn brave-origin/brave-origin brave/brave-browser
    mv usr/share/gnome-control-center/default-apps/brave-origin.xml \
       usr/share/gnome-control-center/default-apps/brave-browser.xml
  '';

  # Re-label the built output as brave-origin (command + launcher entries).
  postInstall = ''
    mv $out/bin/brave $out/bin/brave-origin
    substituteInPlace \
      $out/share/applications/brave-browser.desktop \
      $out/share/applications/com.brave.Browser.desktop \
      --replace-warn "$out/bin/brave" "$out/bin/brave-origin" \
      --replace-warn "Name=Brave Browser" "Name=Brave Origin"
  '';

  meta = old.meta // {
    description = "Minimalist variant of the Brave browser (no Rewards/Wallet/VPN/Leo)";
    homepage = "https://brave.com/origin/";
    mainProgram = "brave-origin";
  };
})

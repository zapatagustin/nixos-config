{ config, lib, pkgs, ... }:
let
  cfg = config.services.gaming;
in
{
  options.services.gaming.enable = lib.mkEnableOption "Steam + GameMode + Wine, launchers and mod tooling";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      package = pkgs.steam.override {
        extraPkgs = pkgs: with pkgs; [
          keyutils
          libkrb5
          libpng
          libpulseaudio
          libvorbis
          stdenv.cc.cc.lib
          libxcursor
          libxi
          libxinerama
          libxscrnsaver
        ];
      };
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      protontricks.enable = true;
    };

    programs.gamemode.enable = true;
    programs.gamescope.enable = true;

    environment.systemPackages = with pkgs; [
      wineWow64Packages.waylandFull
      winetricks
      # lutris: disabled, its FHS env links gtk2 (marked broken in nixpkgs,
      # would compile from source). Re-enable once chaotic's nixpkgs pin
      # carries "lutris: drop gtk2" (2026-10-25).
      heroic
      pcsx2
      mangohud
      # modding
      steamtinkerlaunch
      vkbasalt
      limo
      # nexusmods-app: disabled, discontinued upstream and marked insecure in nixpkgs
      r2modman
    ];
  };
}

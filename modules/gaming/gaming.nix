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
      lutris
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

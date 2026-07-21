{ config, lib, pkgs, ... }:
let
  cfg = config.services.gaming;
in
{
  options.services.gaming.enable = lib.mkEnableOption "Steam + GameMode + Wine";

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
    };

    programs.gamemode.enable = true;

    environment.systemPackages = with pkgs; [
      wineWowPackages.waylandFull
    ];
  };
}

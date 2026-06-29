{ pkgs, ... }: {
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
    wineWow64Packages.waylandFull
  ];
}

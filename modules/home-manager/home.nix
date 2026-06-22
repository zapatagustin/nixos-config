{ pkgs, inputs, ... }:
{
  imports = [
    ./shells/shells.nix
    ./terminals/terminals.nix
  ];

  home.username = "thinkpad";
  home.homeDirectory = "/home/thinkpad";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    brave
    inputs.zen-browser.packages.${pkgs.system}.default
    nnn
    zathura
    calibre
    stremio
  ];
}

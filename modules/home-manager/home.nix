{ pkgs, ... }:
let
  nix-alien-pkgs = import (
    builtins.fetchTarball "https://github.com/thiagokokada/nix-alien/tarball/master"
  ) { };
in
{
  imports = [
    ./editors/neovim/vim.nix
    #./editors/vscode/vscode.nix
    ./editors/zed/zed.nix
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./desktops/hypr/hypr_home.nix
    #./desktops/gnome/gnome_home.nix
  ];

  home.username = "thinkpad";
  home.homeDirectory = "/home/thinkpad";

  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfree = true;

  home.packages = with nix-alien-pkgs; [
    nix-alien
    pkgs.floorp
    pkgs.nnn
    pkgs.kdePackages.ark
    pkgs.xfce.thunar
  ];
}

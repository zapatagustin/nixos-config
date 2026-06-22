{ pkgs, inputs, username, ... }:
{
  imports = [
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./editors/neovim
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
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

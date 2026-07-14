{ pkgs, inputs, username, ... }:
{
  imports = [
    ./options.nix
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./editors/neovim
    ./wm/hyprland
    ./opencode
    ./claude-code
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    brave
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    nnn
    zathura
    calibre
    # stremio removed from nixpkgs (qt5 webengine dep); use flatpak
    # stremio
  ];
}

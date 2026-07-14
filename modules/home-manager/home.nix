{ pkgs, inputs, username, ... }:
{
  imports = [
    ./options.nix
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./editors/neovim
    ./editors/emacs
    ./wm/hyprland
    ./ai
    ./opencode
    ./claude-code
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfree = true;

  # bitwarden-desktop pulls in electron-39.8.10, marked insecure (EOL)
  nixpkgs.config.permittedInsecurePackages = [
    "electron-39.8.10"
  ];

  home.packages = with pkgs; [
    (callPackage ../../pkgs/brave-origin.nix { }) # Brave Origin (not in nixpkgs); see pkgs/brave-origin.nix
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    nnn
    zathura
    calibre
    claude-code
    bitwarden-desktop
    # stremio removed from nixpkgs (qt5 webengine dep); use flatpak
    # stremio
  ];
}

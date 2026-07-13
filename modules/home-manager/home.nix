{ pkgs, inputs, username, ... }:
{
  imports = [
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./editors/neovim
    ./editors/emacs
    ./wm/hyprland
    ./ai
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
    zathura
    claude-code
    bitwarden-desktop
  ];
}

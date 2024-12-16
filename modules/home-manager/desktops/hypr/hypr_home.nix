{config, pkgs, ... }:
{
  home.packages = with pkgs; [
    pkgs.networkmanagerapplet
    pkgs.pamixer
    pkgs.brightnessctl
  ];

  wayland.windowManager.hyprland = {
    enable = true;
  };

  home.sessionVariables.NIXOS_OZONE_WL = "1";
  home.sessionVariables.MOZ_ENABLE_WAYLAND = "1";

  imports = [
    ./config.nix
    ./binds.nix
    ./hyprlock.nix
    ./hypridle.nix
    ./rofi.nix
    ./waybar/waybar.nix
  ];
}

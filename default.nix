{ pkgs, ... }:
{
  imports = [
    ./modules/modules.nix
    ./hosts/host.nix
  ];

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable flatpak
  services.flatpak.enable = true;

  # lastest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # optimize space
  nix.settings.auto-optimise-store = true;

  # Enable portals
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  xdg.portal.config.common.default = "hyprland";

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      udev-gothic
    ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [  "UDEV Gothic" ];
        sansSerif = [ "UDEV Gothic" ];
        monospace = [ "UDEV Gothic" ];
      };
    };
  };
}

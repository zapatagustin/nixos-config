{ pkgs, ... }:
{
  imports = [
    ./modules/modules.nix
    ./hosts/host.nix
  ];

  services.printing.enable = true;
  services.flatpak.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  services.openssh = {
    enable = true;
    openFirewall = true;
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [ udev-gothic ];

    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "UDEV Gothic" ];
        sansSerif = [ "UDEV Gothic" ];
        monospace = [ "UDEV Gothic" ];
      };
    };
  };
}

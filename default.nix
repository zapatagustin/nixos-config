{ pkgs, ... }:
{
  imports = [
    ./modules/modules.nix
    ./hosts/host.nix
  ];

  services.printing.enable = true;
  # Add the Flathub remote once: flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  services.flatpak.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;  # TEMP: switch to false after installing SSH key
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [ udev-gothic ];  # terminus installed via stylix.fonts.monospace
    fontconfig.enable = true;
    # defaultFonts managed by stylix (modules/theme/stylix.nix)
  };
}

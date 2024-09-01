{ lib, pkgs, config, ... }:
let
  plasma-packages = with pkgs.kdePackages; [
    bluez-qt
    discover
    dolphin
    elisa
    gwenview
    kate
    kcalc
    kde-gtk-config
    kdeconnect-kde
    kdeplasma-addons
    kfind
    kinfocenter
    kmenuedit
    kpipewire
    kscreen
    plasma-browser-integration
    plasma-desktop
    plasma-nm
    plasma-pa
    plasma-systemmonitor
    plasma-thunderbolt
    plasma-vault
    plasma-welcome
    plasma-workspace
    polkit-kde-agent
    spectacle
    systemsettings
  ];
  fontList = with pkgs; [
    (nerdfonts.override { fonts = [ "udev-gothic" "NerdFontsSymbolsOnly" ]; })
  ];
in {
  config = lib.mkIf (config.thinkpad.desktopManager == "kde") {
    # ---- System Configuration ----
    services.desktopManager.plasma6.enable = true;

    environment = {
      pathsToLink = [ "/share/backgrounds" ];
      systemPackages = plasma-packages;
    };

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs.libsForQt5; [
        xdg-desktop-portal-kde
      ];
    };

    # ---- Home Configuration ----
    home-manager.users.${config.thinkpad.homeManagerUser} = { pkgs, ...}: {
      home.packages = fontList;

      # It copies "./config/menus/gnome-applications.menu" source file to the nix store, and then symlinks it to the location.
      xdg.configFile."menus/applications-merged/applications-kmenuedit.menu".source = ./config/menus/applications-merged/applications-kmenuedit.menu;

      services.kdeconnect.enable = true;
    };
  };
}

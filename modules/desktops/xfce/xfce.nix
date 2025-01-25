{ ... }:
{
    services.xserver.desktopManager.xfce.enable = true;
    services.xserver.desktopManager.xfce.enableWaylandSession = true;
    services.xserver.desktopManager.xfce.enableScreensaver = true;
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    programs.light.brightnessKeys.enable = true;
    security.pam.services.gdm.enableGnomeKeyring = true;
    services.gnome.gnome-keyring.enable = true;
}

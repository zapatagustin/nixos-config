{ pkgs, ... }:
{
    dconf = {
    enable = true;
    settings."org/gnome/shell" = {
        disable-user-extensions = false;
        enabled-extensions = with pkgs.gnomeExtensions; [
        user-themes
        dash-to-dock
        caffeine
        appindicator
        ];
    };
    };
}

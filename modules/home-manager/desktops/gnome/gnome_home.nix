{ pkgs, ... }:
{
    dconf = {
    enable = true;
    settings = {
      "org/gnome/shell" = {
        disable-user-extensions = false; # enables user extensions
        enabled-extensions = [
          # Put UUIDs of extensions that you want to enable here.
          # If the extension you want to enable is packaged in nixpkgs,
          # you can easily get its UUID by accessing its extensionUuid
          # field (look at the following example).
          #pkgs.gnomeExtensions.gsconnect.extensionUuid
          pkgs.gnomeExtensions.user-themes
          pkgs.gnomeExtensions.dash-to-dock
          pkgs.gnomeExtensions.caffeine
          pkgs.gnomeExtensions.appindicator
        ];
      };
    };
  };
}

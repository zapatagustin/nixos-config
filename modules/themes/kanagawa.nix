{ pkgs, ... }:
{
  stylix = {
     enable = true;
     image = ./assets/gruv-samurai-cyberpunk2077.png;
     polarity = "dark";
     base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa.yaml";

      cursor = {
        package = pkgs.capitaine-cursors-themed;
        name = "Capitaine Cursors (Gruvbox) - White";
        size = 24;
      };

     fonts = {
      serif = {
           package = pkgs.udev-gothic;
           name = "UDEV Gothic";
      };
      sansSerif = {
           package = pkgs.udev-gothic;
           name = "UDEV Gothic";
      };
      monospace = {
           package = pkgs.udev-gothic;
           name = "UDEV Gothic";
      };
     };
   };

  environment.systemPackages = [
    pkgs.colloid-icon-theme
  ];
}

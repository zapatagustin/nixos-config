{ pkgs, config, ... }:
{
  stylix = {
     enable = true;
     image = pkgs.fetchurl {
      url = "https://wallpapercave.com/w/wp11058347";
     };
     
     polarity = "dark";
 
     base16Scheme = "${pkgs.base16-schemes}/share/themes/kanagawa.yaml";

     fonts = {
        monospace = {
         package = pkgs.udev-gothic;
         name = "UDEV Gothic";
        };

     serif = config.stylix.fonts.monospace;
     sansSerif = config.stylix.fonts.monospace;
     emoji = config.stylix.fonts.monospace;
     };
   };
}
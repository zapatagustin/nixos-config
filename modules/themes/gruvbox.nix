{ pkgs, config, ... }:

{
  stylix = {
     enable = true;
     stylix.image = pkgs.fetchurl {
      url = "https://wallpapercave.com/w/wp11058347";
     };
     
     polarity = "dark";
 
     base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

     fonts = {
        monospace = {
	        package = udev-gothic;
          name = "UDEV gothic";
        };

     serif = config.stylix.fonts.monospace;
     sansSerif = config.stylix.fonts.monospace;
     emoji = config.stylix.fonts.monospace;
     };
   };
}
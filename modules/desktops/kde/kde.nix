{ lib, pkgs, ... }:
{
  #fonts.fontconfig.enable = true;
  #fonts.fontconfig = with pkgs; [
  #  (nerdfonts.override { fonts = [ "udev-gothic" "NerdFontsSymbolsOnly" ]; })
  #];

    # ---- System Configuration ----
    services.desktopManager.plasma6.enable = true;
 
    services.displayManager.sddm.enable = true;    
    services.displayManager.sddm.wayland.enable = true;
}

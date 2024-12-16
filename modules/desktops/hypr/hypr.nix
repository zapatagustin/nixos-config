{ config, pkgs, ... }:
{  
  environment.systemPackages = with pkgs; [

  ];

  programs.hyprland = {
    enable = true;
  };

  security.pam.services.hyprlock = {};

  #services.gnome.gnome-keyring.enable = true;
  
  #services.xserver.enable = true;
  #services.xserver.displayManager.lightdm.enable = true;
}

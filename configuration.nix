{ pkgs, ... }:
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./default.nix
  ];

  users.users.thinkpad = {
    isNormalUser = true;
    description = "thinkpad";
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" ];
    shell = pkgs.zsh;
  };

  home-manager.users.thinkpad = {
    home.stateVersion = "26.05";
  };
}

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
}

{ pkgs, hostname, username, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./default.nix
  ];

  networking.hostName = hostname;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" "video" "tss" ];
    shell = pkgs.zsh;
  };
}

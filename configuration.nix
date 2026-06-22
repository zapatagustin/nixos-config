{ pkgs, hostname, username, ... }:
{
  imports = [
    /etc/nixos/hardware-configuration.nix
    ./default.nix
  ];

  networking.hostName = hostname;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" "tss" ];
    shell = pkgs.zsh;
  };
}

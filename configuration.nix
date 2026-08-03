{ pkgs, hostname, username, ... }:
{
  imports = [
    (./hosts + "/${hostname}/hardware-configuration.nix")
    ./default.nix
  ];

  networking.hostName = hostname;

  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "docker" "audio" "video" "tss" ];
    shell = pkgs.zsh;
    # This file is imported by both hosts, so both keys below are authorized on both
    # surface and thinkpad (PasswordAuthentication is off). Add new keys to this list.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAU78tzMsUICpmlbWOX9/ZZ/GL1otRjaLPFastXxWhPX agustin.zapata@atlas.red"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmL82v4Az5e/hFecVw5+hUp5rWeCMeb18KUqrVKsqGq zapatagustin4@gmail.com"
    ];
  };
}

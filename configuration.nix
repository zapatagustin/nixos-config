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
    # No "docker" here: containers/containers.nix runs podman (with dockerCompat),
    # so users.groups.docker is never declared. NixOS silently drops an extraGroups
    # entry for an undeclared group — no assertion, no build error — so the old
    # entry was a long-lived no-op. Rootless podman needs no group membership.
    extraGroups = [ "networkmanager" "wheel" "audio" "video" "tss" ];
    shell = pkgs.zsh;
    # This file is imported by both hosts, so both keys below are authorized on both
    # surface and thinkpad (PasswordAuthentication is off). Add new keys to this list.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAU78tzMsUICpmlbWOX9/ZZ/GL1otRjaLPFastXxWhPX agustin.zapata@atlas.red"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmL82v4Az5e/hFecVw5+hUp5rWeCMeb18KUqrVKsqGq zapatagustin4@gmail.com"
    ];
  };
}

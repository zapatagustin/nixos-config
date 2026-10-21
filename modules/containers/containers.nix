{ lib, pkgs, ... }: {
  imports = [
    ./pihole.nix
    ./immich.nix
    ./jellyfin.nix
    ./searxng.nix
  ];

  # Podman's netavark DNATs published ports in its own nftables chains, ahead of
  # the NixOS input firewall, so a port published on 0.0.0.0 is reachable from
  # every network regardless of networking.firewall. Publish on explicit
  # addresses instead (e.g. localhost + the tailnet IP, per host).
  options.myContainers.publishAddresses = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ "127.0.0.1" ];
    description = "Host addresses that the container modules publish their ports on.";
  };

  config = {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true; # alias docker -> podman
      defaultNetwork.settings.dns_enabled = true;
      autoPrune.enable = true;
    };

    environment.systemPackages = with pkgs; [
      podman-compose
      distrobox
      dnsutils # dig/nslookup for DNS diagnostics (Pi-hole etc.)
    ];
  };
}

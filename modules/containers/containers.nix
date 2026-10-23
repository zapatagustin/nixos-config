{ config, lib, pkgs, ... }: {
  imports = [
    ./pihole.nix
    ./immich.nix
    ./jellyfin.nix
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

    # Ports published on the tailnet address only bind once tailscaled is up and
    # logged in; until then the start fails. Retry every 10s with no start limit
    # instead of tripping systemd's default (5 starts in 10s) and staying failed.
    systemd.services = lib.mapAttrs'
      (name: _: lib.nameValuePair "podman-${name}" {
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        serviceConfig.RestartSec = "10s";
        unitConfig.StartLimitIntervalSec = 0;
      })
      config.virtualisation.oci-containers.containers;
  };
}

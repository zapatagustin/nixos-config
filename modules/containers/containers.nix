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

    # aardvark-dns answers container-name lookups on each network's gateway
    # (10.88.0.1:53, 10.89.0.1:53, ...). That query is host-INPUT traffic from the
    # podman bridge, and netavark's accept lives in its own `inet netavark` table —
    # it cannot save the packet from nixos-fw's drop, so without this rule every
    # multi-container network (immich) fails name resolution (EAI_AGAIN) while
    # single-container ones appear fine. nftables wildcard needs the quotes.
    networking.firewall.extraInputRules = ''
      iifname "podman*" meta l4proto { tcp, udp } th dport 53 accept comment "aardvark-dns"
    '';

    environment.systemPackages = with pkgs; [
      podman-compose
      distrobox
      dnsutils # dig/nslookup for DNS diagnostics (Pi-hole etc.)
    ];

    # Ports published on the tailnet address only bind once tailscaled is up and
    # logged in; until then the start fails. Retry every 10s with no start limit
    # instead of tripping systemd's default (5 starts in 10s) and staying failed.
    #
    # tailscaled being up is not enough: after a re-auth the node can get a new
    # address, and podman would then fail on every retry with a bind error. The gate
    # waits for each non-loopback publish address and names the cause when it never
    # shows up (no-op when only loopback is published).
    systemd.services =
      let
        waitForAddresses = pkgs.writeShellScript "wait-publish-addresses" ''
          for addr in "$@"; do
            for _ in $(seq 1 60); do
              ${pkgs.iproute2}/bin/ip -4 -o addr show | ${pkgs.gnugrep}/bin/grep -qF "inet $addr/" && continue 2
              sleep 1
            done
            echo "address $addr is not configured on any interface (tailscale re-auth changed it? update hosts/desktop/default.nix tailnetAddress)" >&2
            exit 1
          done
        '';
        addresses = lib.filter (a: a != "127.0.0.1") config.myContainers.publishAddresses;
      in
      lib.mapAttrs'
        (name: _: lib.nameValuePair "podman-${name}" {
          after = [ "tailscaled.service" ];
          wants = [ "tailscaled.service" ];
          serviceConfig = {
            RestartSec = "10s";
            ExecStartPre = lib.mkIf (addresses != [ ])
              [ "${waitForAddresses} ${lib.escapeShellArgs addresses}" ];
          };
          unitConfig.StartLimitIntervalSec = 0;
        })
        config.virtualisation.oci-containers.containers;
  };
}

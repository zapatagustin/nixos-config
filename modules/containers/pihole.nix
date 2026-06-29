{ config, lib, ... }:
let
  webPort = 8080; # host port for the Pi-hole admin UI (container's :80)
  podman = "${config.virtualisation.podman.package}/bin/podman";

  # Firebog "ticked" lists (recommended set, low false-positive rate):
  # ads, tracking, malware and phishing. https://firebog.net
  firebogLists = [
    "https://raw.githubusercontent.com/PolishFiltersTeam/KADhosts/master/KADhosts.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Spam/hosts"
    "https://v.firebog.net/hosts/static/w3kbl.txt"
    "https://adaway.org/hosts.txt"
    "https://v.firebog.net/hosts/AdguardDNS.txt"
    "https://v.firebog.net/hosts/Admiral.txt"
    "https://raw.githubusercontent.com/anudeepND/blacklist/master/adservers.txt"
    "https://v.firebog.net/hosts/Easylist.txt"
    "https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/UncheckyAds/hosts"
    "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
    "https://v.firebog.net/hosts/Easyprivacy.txt"
    "https://v.firebog.net/hosts/Prigent-Ads.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.2o7Net/hosts"
    "https://raw.githubusercontent.com/crazy-max/WindowsSpyBlocker/master/data/hosts/spy.txt"
    "https://hostfiles.frogeye.fr/firstparty-trackers-hosts.txt"
    "https://raw.githubusercontent.com/DandelionSprout/adfilt/master/Alternate%20versions%20Anti-Malware%20List/AntiMalwareHosts.txt"
    "https://v.firebog.net/hosts/Prigent-Crypto.txt"
    "https://raw.githubusercontent.com/FadeMind/hosts.extras/master/add.Risk/hosts"
    "https://phishing.army/download/phishing_army_blocklist_extended.txt"
    "https://gitlab.com/quidsup/notrack-blocklists/raw/master/notrack-malware.txt"
    "https://raw.githubusercontent.com/Spam404/lists/master/main-blacklist.txt"
    "https://raw.githubusercontent.com/AssoEchap/stalkerware-indicators/master/generated/hosts"
    "https://urlhaus.abuse.ch/downloads/hostfile/"
    "https://lists.cyberhost.uk/malware.txt"
  ];
in
{
  # ── Free up port 53 for Pi-hole ──────────────────────────────────
  # systemd-resolved's stub listener owns 127.0.0.53:53, which collides
  # with Pi-hole binding 0.0.0.0:53. Disable the stub and repoint
  # resolv.conf at the uplink file so the *host* keeps resolving via its
  # normal DHCP/Tailscale DNS (nss-resolve still answers over D-Bus).
  # The override is needed in two spots — see nixos/.../boot/resolved.nix.
  services.resolved.settings.Resolve.DNSStubListener = false;
  environment.etc."resolv.conf".source =
    lib.mkForce "/run/systemd/resolve/resolv.conf";
  systemd.tmpfiles.settings.systemd-resolved-stub."/etc/resolv.conf".L.argument =
    lib.mkForce "/run/systemd/resolve/resolv.conf";

  # ── Pi-hole v6 container ─────────────────────────────────────────
  virtualisation.oci-containers = {
    backend = "podman";
    containers.pihole = {
      image = "docker.io/pihole/pihole:latest";
      autoStart = true;

      volumes = [
        "/var/lib/pihole/etc-pihole:/etc/pihole"
      ];

      environment = {
        TZ = config.time.timeZone;
        FTLCONF_dns_upstreams = "1.1.1.1;1.0.0.1"; # Cloudflare
        FTLCONF_dns_listeningMode = "all";
        FTLCONF_dns_dnssec = "true";
        FTLCONF_webserver_port = "${toString webPort}o"; # admin UI port (host net); 'o' = optional bind
      };

      # Admin password lives outside git. Set
      #   FTLCONF_webserver_api_password=<your-password>
      # in this file. Leaving it empty makes Pi-hole generate a random
      # one (printed in `podman logs pihole`).
      environmentFiles = [ "/var/lib/pihole/pihole.env" ];

      # Host networking: bind 53/${toString webPort} directly on the host (port 53
      # is free now that resolved's stub is off). Avoids podman's bridge +
      # aardvark-dns, which fights over <gateway>:53 when 53 is published.
      # Reachability stays tailnet-only via the firewall (tailscale0 trusted).
      extraOptions = [
        "--network=host"
        # The container resolves via a real upstream, NOT itself: on first
        # boot Pi-hole's gravity download needs working DNS before FTL is
        # listening on :53 (chicken-and-egg). Client queries still go through
        # FTLCONF_dns_upstreams — this only affects the container's own lookups.
        "--dns=1.1.1.1"
      ];
    };
  };

  # Persistent state + a placeholder secret file so the unit never fails
  # to start because the env file is missing (tmpfiles 'f' won't truncate
  # an existing one).
  systemd.tmpfiles.rules = [
    "d /var/lib/pihole 0750 root root - -"
    "d /var/lib/pihole/etc-pihole 0750 root root - -"
    "f /var/lib/pihole/pihole.env 0600 root root - -"
  ];

  # Pi-hole is reachable only over the tailnet (tailscale0 is trusted).
  # Uncomment to also expose it to the local LAN:
  # networking.firewall.allowedTCPPorts = [ 53 webPort ];
  # networking.firewall.allowedUDPPorts = [ 53 ];

  # ── Declarative adlists (Firebog) ────────────────────────────────
  # Seeds the lists above into gravity.db idempotently and only re-runs
  # gravity (the heavy download) when a new list was actually inserted.
  # Pi-hole refreshes existing lists on its own weekly cron. Note: a list
  # removed via the web UI gets re-added next time this unit runs.
  systemd.services.pihole-adlists = {
    description = "Seed Pi-hole adlists (Firebog) and refresh gravity on change";
    after = [ "podman-pihole.service" ];
    requires = [ "podman-pihole.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      # Wait for the gravity DB to exist inside the container.
      for _ in $(seq 1 30); do
        ${podman} exec pihole test -f /etc/pihole/gravity.db && break
        sleep 2
      done

      added=0
      for url in ${lib.escapeShellArgs firebogLists}; do
        n=$(${podman} exec pihole pihole-FTL sqlite3 /etc/pihole/gravity.db \
          "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$url', 1, 'firebog [managed by nix]'); SELECT changes();")
        [ "$n" = "0" ] || added=1
      done

      if [ "$added" = "1" ]; then
        echo "New adlists inserted — running gravity (this downloads the lists)..."
        ${podman} exec pihole pihole -g
      else
        echo "All adlists already present — skipping gravity."
      fi
    '';
  };
}

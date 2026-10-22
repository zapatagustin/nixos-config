# Headless riscv64 NAS on a SpacemiT K1 board (Orange Pi RV2). It takes over
# the services the CachyOS desktop runs today so the desktop can stay off, and
# it becomes the tailnet's DNS resolver. Nothing from hosts/host.nix or
# default.nix applies here (CachyOS kernel, Hyprland, printing, fonts), and
# home-manager is left out on purpose: no riscv64 cache exists, every package
# in this closure is compiled under emulation on the desktop, so the closure is
# kept to what the box actually serves.
#
# First iteration: base system, SSH, tailscale, Pi-hole + dnscrypt-proxy (the
# DNS single point of failure this host exists to remove). navidrome,
# syncthing and immich follow once this closure builds and boots.
{ inputs, hostname, username, ... }:
{
  imports = [ ./k1.nix ];

  networking.hostName = hostname;

  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Same keys configuration.nix authorizes on the laptops.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAU78tzMsUICpmlbWOX9/ZZ/GL1otRjaLPFastXxWhPX agustin.zapata@atlas.red"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmL82v4Az5e/hFecVw5+hUp5rWeCMeb18KUqrVKsqGq zapatagustin4@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPtBQwh9CmPwKfjKBLOihZoeuu92sCqpe1iU9an3TUEX desktop@cachyos"
    ];
  };
  # Key-only headless box: no password exists for sudo to ask for.
  security.sudo.wheelNeedsPassword = false;

  # Same hardening as default.nix: reachable only over the tailnet.
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  services.tailscale = {
    enable = true;
    openFirewall = true;
    # This host IS the tailnet's global nameserver (admin console, DNS tab).
    # Accepting tailnet DNS here would point its own resolver at itself.
    extraSetFlags = [ "--accept-dns=false" ];
  };

  # Mirrors the desktop pod: Pi-hole on 53, DoH upstream on localhost 5053.
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      listen_addresses = [ "127.0.0.1:5053" ];
      server_names = [ "cloudflare" ];
    };
  };
  services.pihole-ftl = {
    enable = true;
    settings = {
      dns = {
        upstreams = [ "127.0.0.1#5053" ];
        dnssec = true;
        # Bind every interface; the firewall limits reach to the tailnet.
        listeningMode = "ALL";
      };
      # Required for `lists` below to be loaded through the API on startup.
      webserver.api.cli_pw = true;
    };
    # The 26 lists enabled on the desktop's gravity.db on 2026-10-14.
    lists = map (url: { inherit url; }) [
      "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
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
  };
  services.pihole-web = {
    enable = true;
    ports = [{ port = 80; }];
  };

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      allowed-users = [ "@wheel" ];
      # nixos-rebuild --target-host copies unsigned store paths as this user.
      trusted-users = [ "@wheel" ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  # `nix build .#nas-vm` then `./result/bin/run-nas-vm`: the same system under
  # qemu-system-riscv64 (TCG) on the laptop, booted with -kernel and virtio, so
  # the service stack is exercised before any board exists. The runner must be
  # an x86_64 program, hence host.pkgs.
  virtualisation.vmVariant.virtualisation = {
    host.pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    graphics = false;
    memorySize = 2048;
    cores = 4;
    # The guest agent would build a riscv64 qemu, and with it pipewire, gtk
    # and nodejs, to serve a VM nothing talks to.
    qemu.guestAgent.enable = false;
  };

  # Closure diet. No riscv64 cache exists, so every dependency below is hours
  # of emulated compiling on the desktop, and none of it serves a headless NAS.
  nixpkgs.overlays = [
    (_final: prev: {
      # systemd's BPF framework pulls clang + LLVM in through 94 paths.
      systemd = prev.systemd.override { withLibBPF = false; };
      # libpcap's RDMA capture support reaches GHC: rdma-core builds its docs
      # with pandoc. iptables links libpcap, systemd links iptables.
      libpcap = prev.libpcap.override { withRdma = false; };
      # shellcheck is a GHC program. nixpkgs already skips it wherever GHC
      # cannot bootstrap, and that one flag is what writeShellApplication and
      # the by-name packages (nixos-firewall-tool) consult. Flip it here.
      shellcheck-minimal = prev.shellcheck-minimal // {
        compiler = prev.shellcheck-minimal.compiler // { bootstrapAvailable = false; };
      };
    })
  ];
  # nixos-generate-config links bcachefs-tools, which is Rust and needs
  # bindgen, hence clang. This host never generates its own config.
  system.tools.nixos-generate-config.enable = false;
  # rustc (and with it LLVM) stays: make-initrd-ng, which builds every NixOS
  # initrd, is Rust, so the Rust switch-to-configuration costs nothing extra.

  system.stateVersion = "26.05";
}

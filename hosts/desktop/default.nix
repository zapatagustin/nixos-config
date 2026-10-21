{ lib, pkgs, username, ... }:
let
  # This node's tailnet address. Container ports are published on it explicitly
  # (see myContainers.publishAddresses). It survives the migration only if
  # /var/lib/tailscale is carried over; a fresh login gets a new address.
  tailnetAddress = "100.74.140.82";
in
{
  imports = [ ../../configuration.nix ];

  # Ryzen 5 5600G + RX 6700 XT (Navi 22) tower, single 1920x1080 HDMI-A-1 monitor.
  # Not a dock host: multiMonitor stays at its default (false).
  # TODO: the shared hyprland module assumes an eDP-1 panel (wallpaper, workspaces
  # 19-27); on this host HDMI-A-1 gets the fallback monitor rule and base00 wallpaper.
  home-manager.users.${username} = {
    myDesktop.panelResolution = { width = 1920; height = 1080; };
    home.packages = with pkgs; [
      bitwarden-desktop
      qbittorrent
      transmission_4
      haruna
      stremio-linux-shell # `stremio` was removed from nixpkgs (qt5 webengine)
      code-cursor
      vscode
      lazygit
      meld
      kdePackages.filelight
      overskride
    ];
  };

  hardware.trackpoint.enable = false; # desktop, no TrackPoint
  # thermald only supports Intel CPUs; on this Ryzen it fails at start.
  services.thermald.enable = lib.mkForce false;

  # ecomono: kernel is the shared chaotic linuxPackages_cachyos from default.nix,
  # not xddxdd/nix-cachyos-kernel. chaotic is archived but still locked and cached,
  # and nixpkgs follows its pin; moving one host to another kernel input would add a
  # second nixpkgs (its `pinned` overlay) or lose the cache. Migrate all hosts at once.

  # GPU overclock/undervolt: unlocks the full PowerPlay mask (was
  # amdgpu.ppfeaturemask=0xffffffff on CachyOS); LACT applies the profile.
  hardware.amdgpu.overdrive = {
    enable = true;
    ppfeaturemask = "0xffffffff";
  };
  services.lact.enable = true;

  # Process priorities from CachyOS's rule set (ananicy-cpp runs on the current
  # install). Off in modules/performance for the laptops, on here.
  services.ananicy = {
    enable = true;
    package = pkgs.ananicy-cpp;
    rulesProvider = pkgs.ananicy-rules-cachyos;
  };

  # Values from the running CachyOS install. zramSwap is already on (hardware.nix);
  # swappiness overrides performance.nix's 180. max_map_count is also nixpkgs'
  # default, pinned here because games (Proton, some anti-cheats) need it.
  boot.kernel.sysctl = {
    "vm.swappiness" = lib.mkForce 150;
    "vm.max_map_count" = 1048576;
  };

  services.gaming.enable = true;
  # Mod managers and some launchers only ship as Flatpak (see default.nix for why
  # it is off elsewhere). Add the remote once:
  #   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  services.flatpak.enable = true;

  # Game streaming host for the laptops' moonlight-qt. The tailnet reaches it
  # anyway (tailscale0 is trusted, network.nix); openFirewall adds LAN clients.
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # KMS capture
    openFirewall = true;
  };
  programs.kdeconnect.enable = true; # opens 1714-1764 tcp/udp itself

  # ── LAN services (previously rootless podman quadlets) ─────────────────
  # Tailnet-only, as the quadlets were: ports are published on loopback + the
  # tailnet address (never 0.0.0.0) and tailscale0 is trusted, so no
  # networking.firewall port is opened for Immich (2283), Jellyfin (8096),
  # SearXNG (8888). Pi-hole + dnscrypt-proxy live on the NAS host only.
  myContainers.publishAddresses = [ "127.0.0.1" tailnetAddress ];
  services.immich-podman.enable = true;
  services.jellyfin-podman.enable = true;
  services.searxng-podman.enable = true;

  # Reached over `tailscale serve` (https://desktop.<tailnet>/ -> 127.0.0.1:4533).
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/mnt/datos/Music";
      Address = "127.0.0.1";
      Port = 4533;
    };
  };

  # This host IS the remote builder in hosts/host.nix: never delegate to itself,
  # and let the laptops' nix-daemon (ssh as ${username}) push unsigned paths.
  # riscv64 runs via boot.binfmt.emulatedSystems, already set in host.nix.
  nix = {
    distributedBuilds = lib.mkForce false;
    buildMachines = lib.mkForce [ ];
    settings.trusted-users = [ "root" username ];
    # Dedup on every build, on top of host.nix's weekly nix.optimise and weekly
    # 14d gc (both already apply here): this host builds for every machine.
    settings.auto-optimise-store = true;
  };
}

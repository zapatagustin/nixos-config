{ lib, pkgs, username, ... }:
let
  # This node's tailnet address. Container ports are published on it explicitly
  # (see myContainers.publishAddresses). /var/lib/tailscale was NOT carried over
  # in the 2026-10 reinstall, so this is the fresh login's address (2026-10-25).
  tailnetAddress = "100.70.43.27";
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

    # Plasma's plasma-workspace.target BindsTo graphical-session.target, so every
    # unit the shared hyprland module hangs off that target would also start under
    # Plasma: the bar over Plasma's panel, hypridle locking with hyprlock and
    # suspending behind powerdevil, hyprpaper, duplicate audio notifications.
    # uwsm exports XDG_CURRENT_DESKTOP=Hyprland to the user manager before the
    # target is reached; Plasma exports KDE. keepassxc is left running in both.
    # mkForce: hypridle/hyprpaper already carry HM's own "WAYLAND_DISPLAY" one.
    systemd.user.services = lib.genAttrs [ "quickshell" "audio-device-watcher" "hypridle" "hyprpaper" ] (_: {
      Unit.ConditionEnvironment = lib.mkForce [ "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP=Hyprland" ];
    });

    # home.nix's qt.platformTheme "gtk3" exports QT_QPA_PLATFORMTHEME globally
    # (hm-session-vars and environment.d). Qt tries that before the desktop's own
    # theme, so under Plasma it would replace plasma-integration's "kde" theme.
    # Here it is scoped to the Hyprland session through uwsm's per-desktop env file.
    qt.platformTheme.name = lib.mkForce null;
    xdg.configFile."uwsm/env-hyprland".text = "export QT_QPA_PLATFORMTHEME=gtk3\n";
  };

  # Plasma-only host (2026-10-23, by request): Hyprland is dropped on the
  # desktop — the shared wm module keeps providing it for the laptops. SDDM +
  # Plasma 6 Wayland mirrors the installer generation this machine actually
  # boots. greetd is force-disabled; so is programs.hyprland, which also kills
  # the old tuigreet session menu's hyprland-uwsm.desktop source. The HM
  # hyprland units stay inert here: they condition on
  # XDG_CURRENT_DESKTOP=Hyprland (block above) and no Hyprland session exists.
  services.desktopManager.plasma6.enable = true;
  programs.hyprland.enable = lib.mkForce false;
  services.greetd.enable = lib.mkForce false;
  services.displayManager = {
    sddm.enable = true;
    sddm.wayland.enable = true;
    defaultSession = "plasma";
  };
  # gnome-keyring stays the one Secret Service (kwalletrc below); greetd's PAM
  # hook used to unlock it at login — give SDDM the same hook.
  security.pam.services.sddm.enableGnomeKeyring = true;

  # One Secret Service provider in both sessions: gnome-keyring (modules/wm/
  # hyprland.nix) holds the existing secrets. Without this, kwalletd6 also
  # claims org.freedesktop.secrets under Plasma and whichever starts first
  # wins, splitting secrets per session.
  environment.etc."xdg/kwalletrc".text = ''
    [org.freedesktop.secrets]
    apiEnabled=false
  '';

  # kde-gtk-config's kded module (applyAllSettings at every Plasma login) deletes
  # and rewrites ~/.gtkrc-2.0, turning HM's symlink into a plain file that HM backs
  # up once (hm-bak) and then refuses to clobber, failing activation. It also writes
  # its own font/icon/cursor/color-scheme into the org.gnome.desktop.interface dconf
  # keys HM sets, which the Hyprland session then reads until the next HM
  # activation. Off: GTK apps keep the stylix look in both sessions. Set as a
  # system default (kded reads kded5rc, even on KF6), so the Background Services
  # KCM can still re-enable it per user.
  environment.etc."xdg/kded5rc".text = ''
    [Module-gtkconfig]
    autoload=false
  '';

  hardware.trackpoint.enable = false; # desktop, no TrackPoint
  # thermald only supports Intel CPUs; on this Ryzen it fails at start.
  services.thermald.enable = lib.mkForce false;
  hardware.cpu.intel.updateMicrocode = false; # Ryzen; amd.updateMicrocode in hardware-configuration.nix
  # TLP is laptop power tuning (hardware.nix header says "ThinkPad power/thermal"):
  # on a wall-powered tower, USB_AUTOSUSPEND and RUNTIME_PM only earn suspended
  # peripherals. The CachyOS install never ran it either.
  services.tlp.enable = lib.mkForce false;

  # ecomono: kernel is the shared chaotic linuxPackages_cachyos from default.nix,
  # not xddxdd/nix-cachyos-kernel. chaotic is archived but still locked and cached,
  # and nixpkgs follows its pin; moving one host to another kernel input would add a
  # second nixpkgs (its `pinned` overlay) or lose the cache. Migrate all hosts at once.

  # GPU overclock/undervolt: unlocks the full PowerPlay mask (was
  # amdgpu.ppfeaturemask=0xffffffff on CachyOS); LACT applies the profile.
  # Ruled out as the GPU-init culprit during the 2026-10 bisect (the failure
  # reproduced WITHOUT the mask, journals 2026-10-23 16:56 and 18:10).
  hardware.amdgpu.overdrive = {
    enable = true;
    ppfeaturemask = "0xffffffff";
  };
  services.lact.enable = true;

  # Bisect verdict (2026-10, GPU-init black screen): the kernel BUILD was the
  # culprit. On chaotic's cachyos 7.3 (LLVM/LTO) the PSP fails loading the SMU
  # fw ("failed to load ucode SMC(0x34)" + AMD-Vi IO_PAGE_FAULT); on stock
  # 6.18 LTS the journal stops right before the SMU step. Stock 7.3
  # (linuxPackages_latest) initializes the SMU and boots — so this host pins
  # it over the shared chaotic linuxPackages_cachyos (default.nix). Also ruled
  # out: wrong root UUID, overdrive, firmware files (byte-identical), early-KMS
  # amdgpu. If a kernel bump regresses this, bisect generations from the
  # systemd-boot menu before touching the config.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;

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

  # Game streaming host for the laptops' moonlight-qt, reached over the tailnet
  # (tailscale0 is trusted, network.nix); no LAN ports are opened.
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # KMS capture
    openFirewall = false;
  };
  programs.kdeconnect.enable = true; # opens 1714-1764 tcp/udp itself

  # ── LAN services (previously rootless podman quadlets) ─────────────────
  # Tailnet-only, as the quadlets were: ports are published on loopback + the
  # tailnet address (never 0.0.0.0) and tailscale0 is trusted, so no
  # networking.firewall port is opened for Immich (2283), Jellyfin (8096) or
  # Pi-hole (53, web 8080).
  myContainers.publishAddresses = [ "127.0.0.1" tailnetAddress ];
  services.immich-podman.enable = true;
  services.jellyfin-podman.enable = true;

  # Temporary: the tailnet's DNS (Tailscale global nameserver, tailnetAddress)
  # until the nas host is deployed. Then disable here and repoint Tailscale DNS.
  services.pihole.enable = true;

  # DoH/DNSCrypt upstream for Pi-hole, same split as the NAS host: Pi-hole on 53,
  # dnscrypt-proxy on localhost 5053. Settings from the old dnscrypt-proxy.toml.
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      listen_addresses = [ "127.0.0.1:5053" ];
      server_names = [ "quad9-doh-ip4-port443-nofilter-pri" "quad9-dnscrypt-ip4-nofilter-pri" "cloudflare" ];
      ipv6_servers = false;
      require_dnssec = true;
      require_nolog = true;
      require_nofilter = true;
      bootstrap_resolvers = [ "9.9.9.11:53" "8.8.8.8:53" ];
      block_unqualified = true;
      block_undelegated = true;
      cache = false; # Pi-hole caches
    };
  };
  # pihole runs with --network=host, so localhost is the host's dnscrypt-proxy.
  virtualisation.oci-containers.containers.pihole.environment.FTLCONF_dns_upstreams =
    lib.mkForce "127.0.0.1#5053";

  # Reached over `tailscale serve` (https://desktop.<tailnet>/ -> 127.0.0.1:4533).
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/mnt/datos/Music";
      # 0.0.0.0 is safe for a NATIVE service: nixos-fw filters its INPUT (unlike
      # podman-published ports, which netavark DNATs past the firewall — that is
      # what the "never 0.0.0.0" rule below is about). No LAN port is opened, so
      # it is reachable only via the trusted tailscale0. Binding tailnetAddress
      # instead would fail at boot until tailscaled brings the address up.
      Address = "0.0.0.0";
      Port = 4533;
    };
  };
  # The music lives on the nofail data disk: never index an empty mountpoint. Not
  # RequiresMountsFor: a failed nofail mount would fail this unit as a dependency,
  # which is never retried. Not an ExecStartPre mountpoint check either: the
  # module sandboxes the service (BindReadOnlyPaths bind-mounts only MusicFolder),
  # so inside the unit /mnt/datos is never a mountpoint and the check looped
  # forever (observed: 53 restarts). A Condition runs in PID1's host namespace.
  # Tradeoff: a dead disk SKIPS the start (shows in `systemctl status`) instead
  # of retrying — `systemctl start navidrome` by hand once the disk is back.
  systemd.services.navidrome = {
    after = [ "mnt-datos.mount" ];
    wants = [ "mnt-datos.mount" ];
    unitConfig.ConditionPathIsMountPoint = "/mnt/datos";
  };

  # This host IS the remote builder in hosts/host.nix: never delegate to itself.
  # The laptops' nix-daemon connects as the dedicated nix-ssh user (forced command
  # `nix-store --serve --write`, no shell/forwarding) instead of ${username}, so the
  # main user is not root-equivalent via trusted-users. `trusted` adds nix-ssh to
  # trusted-users, which --write needs to accept unsigned paths. The key is the
  # personal identity that buildMachines' sshKey points at.
  # riscv64 runs via boot.binfmt.emulatedSystems, already set in host.nix.
  nix.sshServe = {
    enable = true;
    write = true;
    trusted = true;
    protocol = "ssh";
    keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmL82v4Az5e/hFecVw5+hUp5rWeCMeb18KUqrVKsqGq zapatagustin4@gmail.com"
    ];
  };
  nix = {
    distributedBuilds = lib.mkForce false;
    buildMachines = lib.mkForce [ ];
    # Dedup on every build, on top of host.nix's weekly nix.optimise and weekly
    # 14d gc (both already apply here): this host builds for every machine.
    settings.auto-optimise-store = true;
  };
}

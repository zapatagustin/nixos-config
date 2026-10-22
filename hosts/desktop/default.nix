{ config, lib, pkgs, username, ... }:
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

  # KDE Plasma 6 as a second session next to Hyprland, picked from tuigreet's
  # session menu (F3) and remembered for the next login. Hyprland stays the default
  # (--cmd) until another session is chosen. The menu lists only the uwsm Hyprland
  # entry and Plasma: programs.hyprland also registers a plain hyprland.desktop,
  # which skips uwsm, so the bar, hypridle (the only idle lock) and env-hyprland
  # never start, and --remember-session would make that pick stick.
  # kwallet is unlocked at login: plasma6 enables it on the "login" PAM stack, which
  # greetd's stack includes.
  services.desktopManager.plasma6.enable = true;
  myGreeter.extraArgs = [
    "--remember-session"
    "--sessions"
    (toString (pkgs.runCommand "greeter-wayland-sessions" { } ''
      mkdir $out
      cp ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions/{hyprland-uwsm,plasma}.desktop $out/
    ''))
  ];

  # One Secret Service provider in both sessions: gnome-keyring (modules/wm/
  # hyprland.nix) holds the existing secrets, e.g. mono_player's token. Without
  # this, kwalletd6 also claims org.freedesktop.secrets under Plasma and whichever
  # starts first wins, splitting secrets per session.
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
  # networking.firewall port is opened for Immich (2283) or Jellyfin (8096).
  # Pi-hole + dnscrypt-proxy live on the NAS host only.
  myContainers.publishAddresses = [ "127.0.0.1" tailnetAddress ];
  services.immich-podman.enable = true;
  services.jellyfin-podman.enable = true;

  # Reached over `tailscale serve` (https://desktop.<tailnet>/ -> 127.0.0.1:4533).
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/mnt/datos/Music";
      Address = "127.0.0.1";
      Port = 4533;
    };
  };
  # The music lives on the nofail data disk: never index an empty mountpoint.
  systemd.services.navidrome.unitConfig.RequiresMountsFor = [ "/mnt/datos" ];

  # This host IS the remote builder in hosts/host.nix: never delegate to itself,
  # and let the laptops' nix-daemon (ssh as ${username}) push unsigned paths.
  # riscv64 runs via boot.binfmt.emulatedSystems, already set in host.nix.
  nix = {
    distributedBuilds = lib.mkForce false;
    buildMachines = lib.mkForce [ ];
    settings.trusted-users = [ username ]; # root is already in the default
    # Dedup on every build, on top of host.nix's weekly nix.optimise and weekly
    # 14d gc (both already apply here): this host builds for every machine.
    settings.auto-optimise-store = true;
  };
}

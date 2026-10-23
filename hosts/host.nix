{ pkgs, lib, flakePath, username, ... }:
{
  imports = [
    ./locale/locale.nix
    ./software/default_soft.nix
  ];

  programs = {
    git.enable = true;
    nano.enable = true;
    zsh.enable = true;
    ssh = {
      askPassword = "";
      # Pinned so root, which runs the remote builds in nix.buildMachines, never
      # hits a trust-on-first-use prompt. Same key the user's known_hosts holds.
      knownHosts."desktop.taild4c79d.ts.net".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP+ny2CT7fpgioIxZzoSt/+yxAFiTTvJ2yhafcAcVliy";
    };
    command-not-found.enable = false; # use nix-index instead
    appimage = {
      enable = true;
      binfmt = true;
    };
    nix-ld = {
      enable = true;
      package = pkgs.nix-ld;
      libraries = with pkgs; [
        stdenv.cc.cc
        zlib
        fuse3
        icu
        nss
        openssl
        curl
        expat
        libxkbcommon
        libxml2
        libGL
        glib
        dbus
      ];
    };
  };

  environment = {
    systemPackages = [ pkgs.jellyfin-desktop ]; # client; server runs on `desktop` (http://desktop:8096)
    sessionVariables = {
      TERMINAL = "foot";
      NIXPKGS_ALLOW_UNFREE = "1";
      NH_FLAKE = flakePath; # nh os switch w/o passing path
    };
  };

  # riscv64 builds for the NAS host run here under qemu-user emulation. Emulated
  # builds produce the same store hashes as native ones, so the NAS itself can
  # later act as a native remote builder for the same closure; a crossSystem
  # build would not share them. No riscv64 binary cache is listed: the only
  # community one (cache.ztier.in) had its Hydra jobset disabled, last eval
  # 2026-08-29 with 4 jobs, zero hits for this stack (checked 2026-10-14).
  boot.binfmt.emulatedSystems = [ "riscv64-linux" ];

  # Emulating on the laptop is the fallback: the desktop (Ryzen 5 5600G, far
  # more free RAM) takes riscv64 derivations over the tailnet. x86_64 builds
  # never leave the laptop. The desktop side (CachyOS, nix from pacman) needs
  # nix-daemon running, qemu-user-static-binfmt, and in /etc/nix/nix.conf
  # `trusted-users = root desktop` plus `extra-platforms = riscv64-linux`.
  # Once the desktop runs NixOS (hosts/desktop, nix.sshServe) it serves the
  # dedicated nix-ssh user instead; flip sshUser then.
  nix.distributedBuilds = true;
  nix.buildMachines = [{
    hostName = "desktop.taild4c79d.ts.net";
    sshUser = "desktop"; # disabled until the desktop runs NixOS: "nix-ssh"
    # nix-daemon opens the connection as root; the user's key is readable by it.
    sshKey = "/home/${username}/.ssh/id_ed25519_personal";
    systems = [ "riscv64-linux" ];
    # Legacy protocol on purpose: with ssh-ng the forwarded daemon rejected
    # unsigned inputs ("lacks a signature by a trusted key") even though the
    # user is in trusted-users; nix-store --serve over plain ssh accepts them.
    protocol = "ssh";
    # One job at a time: an emulated gcc or kernel build already takes every
    # core, and two of them would exhaust the desktop's 16 GB.
    maxJobs = 1;
    supportedFeatures = [ "big-parallel" ];
  }];

  nix = {
    settings = {
      allowed-users = [ "@wheel" ];
      extra-experimental-features = [
        "nix-command"
        "flakes"
        "cgroups" # required by use-cgroups = true on newer nix
      ];
      # store dedup handled by nix.optimise.automatic (weekly) instead of on every build
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://nyx-cache.chaotic.cx/"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "nyx-cache.chaotic.cx:dJxTrgMC3v3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      ];
      # the remote builder fetches sources from the caches itself instead of
      # receiving them from the laptop
      builders-use-substitutes = true;
      warn-dirty = false;
      keep-going = true;
      fallback = true;
      connect-timeout = 15;
      log-lines = 50;
      use-xdg-base-directories = true;
      use-cgroups = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  boot.tmp.cleanOnBoot = true;

  services = {
    avahi = {
      enable = true;
      nssmdns4 = true;
    };
    journald.settings.Journal = {
      SystemMaxUse = "500M";
      Storage = "persistent";
    };
    dbus.implementation = "broker";
  };

  # disabled: adds `nohibernate` to kernelParams, which breaks hibernation and
  # upower's HybridSleep criticalPowerAction. Swap (17G ≥ RAM) + per-host
  # boot.resumeDevice make real hibernation the intended behaviour here.
  # security.protectKernelImage = true;

  networking.firewall.enable = true;

  nixpkgs.config.allowUnfree = lib.mkDefault true;

  system.stateVersion = "26.05";
}

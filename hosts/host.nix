{ pkgs, lib, flakePath, ... }:
{
  imports = [
    ./locale/locale.nix
    ./software/default_soft.nix
  ];

  programs = {
    git.enable = true;
    nano.enable = true;
    zsh.enable = true;
    ssh.askPassword = "";
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
    systemPackages = [ ];
    sessionVariables = {
      TERMINAL = "foot";
      NIXPKGS_ALLOW_UNFREE = "1";
      NH_FLAKE = flakePath; # nh os switch w/o passing path
    };
  };

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
      # builders-use-substitutes dropped: it only applies to remote builders, and
      # there is no nix.distributedBuilds / nix.buildMachines anywhere in the tree.
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
    journald.extraConfig = "SystemMaxUse=500M\nStorage=persistent";
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

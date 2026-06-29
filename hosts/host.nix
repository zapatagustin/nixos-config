{ pkgs, lib, ... }:
{
  imports = [
    ./locale/locale.nix
    ./software/default_soft.nix
  ];

  programs = {
    git.enable = true;
    nano.enable = true;
    zsh.enable = true;
    tmux.enable = true;
    ssh.askPassword = "";
    command-not-found.enable = false;  # use nix-index instead
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
    systemPackages = [];
    sessionVariables = {
      TERMINAL = "kitty";
      NIXPKGS_ALLOW_UNFREE = "1";
      NH_FLAKE = "/home/thinkpad/nixos-config";  # nh os switch w/o passing path
    };
  };

  nix = {
    settings = {
      allowed-users = [ "@wheel" ];
      extra-experimental-features = [
        "nix-command"
        "flakes"
        "cgroups"   # required by use-cgroups = true on newer nix
      ];
      # store dedup handled by nix.optimise.automatic (weekly) instead of on every build
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      builders-use-substitutes = true;
      warn-dirty = false;
      keep-going = true;
      fallback = true;
      connect-timeout = 5;
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
    journald.extraConfig = "SystemMaxUse=500M";
    dbus.implementation = "broker";
  };

  security.protectKernelImage = true;

  networking.firewall.enable = true;

  nixpkgs.config.allowUnfree = lib.mkDefault true;

  system.stateVersion = "26.05";
}

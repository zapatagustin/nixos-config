{ pkgs, lib, ... }: with lib;
{
  imports = [
    ./locale/locale.nix
    ./software/default_soft.nix
  ];

  programs = {
    git.enable = true;
    nano.enable = true;
    zsh.enable = true;
    ssh.askPassword = ""; # Prevent OpenSSH popup during 'git push'
    nix-ld = {
      enable = true;
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
    };
  };

  nix = {
    settings = {
      allowed-users = [ "@wheel" ];
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      builders-use-substitutes = true;
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

  services.avahi = {
    enable = true;
    nssmdns4 = true;
  };

  networking.firewall.enable = true;

  nixpkgs.config.allowUnfree = mkDefault true;

  system.stateVersion = "26.05";
}

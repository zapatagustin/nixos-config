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
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
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

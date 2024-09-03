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
      ssh.askPassword = ""; # Preventing OpenSSH popup during 'git push'
    };

    environment = {
      systemPackages = [];
      sessionVariables = {
        EDITOR = "nano";
        BROWSER = "floorp";
        SHELL = "/run/current-system/sw/bin/zsh";
        TERMINAL = "kitty";
        TERM = "xterm-256color";
        NIXPKGS_ALLOW_UNFREE = "1"; # To allow nix-shell to use unfree packages
      };
    };

    # ----- System Config -----
    # nix config
    nix = {
      package = pkgs.nixStable;
      settings = {
        allowed-users = ["@wheel"]; #locks down access to nix-daemon
        extra-experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
      };
    };

    # Allow unfree packages
    nixpkgs.config.allowUnfree = mkDefault true;

    # Dont change
    system.stateVersion = "24.05";
}

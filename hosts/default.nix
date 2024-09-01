{ config, pkgs, lib, ... }: with lib; let
in {
  imports = [
    ./locale
    ./software
  ];

  config = mkIf (config.thinkpad.baseConfiguration || config.thinkpad.baseHosts) {
    programs = {
      git.enable = true;
      nano.enable = true;
      ssh.askPassword = ""; # Preventing OpenSSH popup during 'git push'
    };

    programs.${config.thinkpad.mainShell} = mkIf ("${config.thinkpad.mainShell}" != "zsh") {
      enable = true;
    };

    home-manager.users.${config.thinkpad.homeManagerUser} = { pkgs, ... }: {
      /* The home.stateVersion option does not have a default and must be set */
      home.stateVersion = "24.05";
      nixpkgs.config.allowUnfree = true;
    };

    environment = {
      systemPackages = [ shellrocket ];
      sessionVariables = {
        EDITOR = "nano";
        BROWSER = "${config.thinkpad.browser}";
        SHELL = "/run/current-system/sw/bin/${config.thinkpad.mainShell}";
        TERMINAL = "${config.thinkpad.terminal}";
        TERM = "xterm-256color";
        NIXPKGS_ALLOW_UNFREE = "1"; # To allow nix-shell to use unfree packages
      };

      # Used mkForce to override/merge values in os-release. Needed because "text" attr is lib.types.lines type that is a mergeable type (so it appends values we assign to the attributes) mkForce prevents this appending because overwrites values.
      etc."os-release" = mkForce {
        text = attrsToText osReleaseContents;
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
      };
    };

    # Allow unfree packages
    nixpkgs.config.allowUnfree = mkDefault true;

    nix.settings.auto-optimise-store = true;

    # Dont change
    system.stateVersion = "24.05";
  };
}

{ lib, config, ... }@inputs: let 
  cfg = config.thinkpad;
in {
  options = {
    thinkpad = {
      enable = lib.mkEnableOption
      baseConfiguration = lib.mkEnableOption "Enable base configuration";
      baseSoftware = lib.mkEnableOption "Enable base software";
      baseLocale = lib.mkEnableOption "Enable base locale";
      baseHosts = lib.mkEnableOption "Make base changes. Such as setting the stateVersion.";
      homeManagerUser = lib.mkOption {
        type = lib.types.str;
        default = "thinkpad";
        description = ''
          The user to use for home-manager.
        '';
      };

      bootloader = lib.mkOption {
        type = with lib.types; nullOr (enum [ "grub" "systemd" ]);
        default = "systemd";
        description = ''
          The bootloader to use.
        '';
      };

      desktopManager = lib.mkOption {
        type = with lib.types; nullOr (enum [
          "gnome"
          "kde"
        ]);

        default = "kde";
        description = ''
          The desktop manager to use.
        '';
      };

      displayManager = lib.mkOption {
        type = with lib.types; nullOr (enum [ "gdm" "sddm" "lightdm" ]);
        default = "sddm";
        description = ''
          The display manager to use.
        '';
      };

      mainShell = lib.mkOption {
        type = with lib.types; nullOr (enum [
          "bash"
          "fish"
          "zsh"
        ]);

        default = "zsh";
        description = ''
          The shell to use.
        '';
      };

      terminal = lib.mkOption {
        type = with lib.types; nullOr (enum [
          "alacritty"
          "kitty"
        ]);

        default = "kitty";
        description = ''
          The terminal to use.
        '';
      };

      browser = lib.mkOption {
        type = with lib.types; nullOr (enum [ "floorp" ]);
        default = "floorp";
        description = ''
          The browser to use.
        '';
      };
    };
  };

  imports = [
    ./home-manager
    ./modules
    ./modules/themes/gruvbox.nix
    ./home-manager/desktops
    ./modules/dms
    ./home-manager/shells
    ./home-manager/terminals
    ./home-manager/browsers
    ./modules/boot
    ./hosts
  ];
}


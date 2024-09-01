{ lib, config, ...}: {
  config = lib.mkIf config.thinkpad.baseConfiguration {
    home-manager.users.${config.thinkpad.homeManagerUser} = { pkgs, ...}: {
      programs.starship = {
        enable = true;
        enableZshIntegration = true;
      };
    };
  };
}

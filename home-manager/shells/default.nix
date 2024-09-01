{ lib, config, ... }: {
  imports = [
    ./bash
    ./zsh
  ];

  config = lib.mkIf config.thinkpad.baseConfiguration {
    home-manager.users.${config.thinkpad.homeManagerUser} = { pkgs, ...}: {
      home.file.".bash_aliases".source = ./bash_aliases;
      # home.packages = with pkgs; [
      #   neofetch
      #   zoxide
      # ];

      xdg.desktopEntries."shell" = {
        type = "Application";
        name = "Shell";
        comment = "Shell";
        icon = "shell";
        exec = "${config.thinkpad.terminal}";
        terminal = false;
        categories = [ "Application" "Utility" ];
      };
    };
  };
}

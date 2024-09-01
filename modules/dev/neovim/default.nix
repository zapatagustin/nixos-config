{ lib, config, ... }: {
  config = lib.mkIf config.thinkpad.baseConfiguration {
    home-manager.users.${config.thinkpad.homeManagerUser} = { pkgs, ...}: {
      home.packages = with pkgs; [
        gnumake
        nodejs
        nodePackages.npm
        vscode-extensions.ms-vscode.cpptools
        vscode-extensions.vadimcn.vscode-lldb
      ];
      programs = {
        neovim = {
          enable = true;
          viAlias = true;
          vimAlias = true;
        };
      };
      xdg.configFile."nvim/lua".source = ./lua;
      xdg.configFile."nvim/init.lua".source = ./init.lua;
    };
  };
}

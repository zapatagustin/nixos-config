{ ... }:
{
  imports = [
    ./editors/emacs/emacs.nix
    ./editors/neovim/vim.nix
    ./editors/vscode/vscode.nix
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./browsers/browsers.nix
  ];

  home.username = "thinkpad";
  home.homeDirectory = "/home/thinkpad";
  
  programs.home-manager.enable = true;

  home-manager.users.thinkpad = { pkgs, ... }: {
    /* The home.stateVersion option does not have a default and must be set */
    home.stateVersion = "24.11";
    nixpkgs.config.allowUnfree = true;
  };
}

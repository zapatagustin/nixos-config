{ ... }:
{
  imports = [
    ./editors/emacs/emacs.nix
    ./editors/neovim/vim.nix
    ./editors/vscode/vscode.nix
    ./shells/shells.nix
    ./terminals/terminals.nix
    ./browsers/browsers.nix
    ./desktops/desktops.nix
  ];

  home-manager.users.thinkpad = { pkgs, ... }: {
    /* The home.stateVersion option does not have a default and must be set */
    home.stateVersion = "24.05";
    nixpkgs.config.allowUnfree = true;
  };
}

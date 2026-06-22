{ pkgs, ... }:
{
  imports = [
    ./editors/vscode/vscode.nix
    ./shells/shells.nix
    ./terminals/terminals.nix
  ];

  home.username = "thinkpad";
  home.homeDirectory = "/home/thinkpad";

  programs.home-manager.enable = true;

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    floorp
    nnn
    zathura
    calibre
    stremio
  ];
}

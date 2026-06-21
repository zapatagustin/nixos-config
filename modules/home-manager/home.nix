{ pkgs, inputs, ... }:
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

  home.packages = [
    inputs.nix-alien.packages.${pkgs.system}.nix-alien
    pkgs.floorp
    pkgs.nnn
    pkgs.zathura
    pkgs.calibre
    pkgs.stremio
  ];
}

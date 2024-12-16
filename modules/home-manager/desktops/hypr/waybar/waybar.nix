{ pkgs, ... }: 
{
  imports = [
    ./way_settings.nix
    ./style.nix
  ];

  programs.waybar = {
    enable = true;
  };
}

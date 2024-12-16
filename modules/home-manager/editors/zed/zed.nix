{ pkgs, ... }:
{
  programs.zed-editor = {
    enable = true;
    extensions = ["nix" "make"];

    userSettings = {
      font_family = "UDEV Gothic";

      vim_mode = true;
      ## tell zed to use direnv and direnv can use a flake.nix enviroment.
      load_direnv = "shell_hook";
      theme = {
          mode = "dark";
          light = "Gruvbox Light Hard";
          dark = "Gruvbox Dark Hard";
      };

      languages = {
        "Nix" = {
          formatter = "nil";
        };
      };
    };
  };
}

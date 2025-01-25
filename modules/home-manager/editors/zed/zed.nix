{ ... }:
{
  programs.zed-editor = {
    enable = true;
    extensions = ["nix" "make"];

    userSettings = {
      font_family = "UDEV Gothic";

      vim_mode = true;
      ## tell zed to use direnv and direnv can use a flake.nix enviroment.
      load_direnv = "shell_hook";
      #theme = "Gruvbox Dark Hard";

      languages = {
        "Nix" = {
          formatter = "nil";
        };
      };
    };
  };
}

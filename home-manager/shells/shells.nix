{ ... }: {
  imports = [
    ./zsh/zsh.nix
    ./starship/starship.nix
    ./zellij/zellij.nix
  ];

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
        exec = "kitty";
        terminal = false;
        categories = [ "Application" "Utility" ];
      };
}

{ ... }: {
    programs.kitty = {
      enable = true;
      # Colors, font family and size come from stylix.targets.kitty
      # (modules/home-manager/stylix.nix): base16 gruvbox-dark-medium + Terminess.
      settings = {
        # stylix sets the base font_family; bold/italic variants stay explicit.
        bold_font = "Terminess Nerd Font Mono";
        italic_font = "Terminess Nerd Font Mono";
        bold_italic_font = "Terminess Nerd Font Mono";

        adjust_line_height = "92%";
        confirm_os_window_close = 0;
      };
    };
}

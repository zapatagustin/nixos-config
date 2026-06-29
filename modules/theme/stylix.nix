{ pkgs, config, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    # No DE/compositor: wallpaper is just a solid bg pixel.
    image = config.lib.stylix.pixel "base00";

    # simp1e cursor, gruvbox dark variant (matches base16Scheme above).
    # https://gitlab.com/cursors/simp1e
    cursor = {
      package = pkgs.simp1e-cursors;
      name = "Simp1e-Gruvbox-Dark";
      size = 24;
    };

    fonts = {
      # Terminess = Terminus patched by Nerd Fonts: same look + glyphs (bar/prompt icons)
      monospace = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font Mono"; };
      sansSerif = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
      serif = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
    };

    # Stylix's starship target imposes its own palette and breaks the custom
    # prompt (uses named colors). Manual palette is already gruvbox — keep it.
    #targets.starship.enable = false;
    # bat's stylix theme is a home-manager target, disabled in shells/shells.nix

    # Let stylix drive hyprlock's input-field colors (base16). Layout/fonts/bg
    # stay in programs.hyprlock; the hardcoded input-field rgba were removed.
    #targets.hyprlock.enable = true;
  };
}

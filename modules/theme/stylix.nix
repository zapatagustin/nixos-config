{ pkgs, config, ... }: {
  stylix = {
    enable = true;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    # No DE/compositor: wallpaper is just a solid bg pixel.
    image = config.lib.stylix.pixel "base00";

    fonts = {
      # Terminess = Terminus patched by Nerd Fonts: same look + glyphs (bar/prompt icons)
      monospace = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font Mono"; };
      sansSerif = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
      serif = { package = pkgs.udev-gothic; name = "UDEV Gothic"; };
    };

    # Cursor: stylix sets XCURSOR_SIZE + HYPRCURSOR_SIZE (was XCURSOR_SIZE/HYPRCURSOR_SIZE=24
    # in cachy's uwsm/env) plus the theme. Name verified against the release's share/icons dirs.
    cursor = {
      package = pkgs.capitaine-cursors-themed;
      name = "Capitaine Cursors (Gruvbox)";
      size = 24;
    };

    # Stylix's starship target imposes its own palette and breaks the custom
    # prompt (uses named colors). Manual palette is already gruvbox — keep it.
    targets.starship.enable = false;

    # Let stylix drive hyprlock's input-field colors (base16). Layout/fonts/bg
    # stay in programs.hyprlock; the hardcoded input-field rgba were removed.
    targets.hyprlock.enable = true;
  };
}

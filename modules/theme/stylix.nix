{ pkgs, config, ... }: {
  # ponytail: autoEnable=false + explicit targets to avoid missing-option
  # errors from targets referencing DE configs we don't have (gnome, kmscon, etc.)
  stylix = {
    enable = true;
    autoEnable = false;
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

    # stylix's starship & hyprlock targets are HM-only (no nixos.nix).
    # gnome target needs explicit disable since we don't have GNOME.
    # ponytail: disable HM autoImport → HM targets (anki, gtk, etc.) reference
    # HM options that don't exist; condition=false doesn't prevent validation.
    homeManagerIntegration.autoImport = false;
    targets.gnome.enable = false;
  };
}

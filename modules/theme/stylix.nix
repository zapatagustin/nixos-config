{ pkgs, config, ... }: {
  # ecomono: autoEnable=false + explicit targets to avoid missing-option
  # errors from targets referencing DE configs we don't have (gnome, kmscon, etc.)
  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

    # No DE/compositor: wallpaper is just a solid bg pixel.
    image = config.lib.stylix.pixel "base00";

    fonts = {
      # Terminess = Terminus patched by Nerd Fonts: same look + glyphs (bar/prompt
      # icons). Used for all three roles so stylix targets that pick sansSerif for
      # UI (gtk.font, zed ui_font) render Terminess too, not a different family.
      monospace = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font Mono"; };
      sansSerif = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font"; };
      serif = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font"; };
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
    # ecomono: disable HM autoImport → HM targets (anki, gtk, etc.) reference
    # HM options that don't exist; condition=false doesn't prevent validation.
    homeManagerIntegration.autoImport = false;
    targets.gnome.enable = false;

    # Stylix's starship target imposes its own palette and breaks the custom
    # prompt (uses named colors). Manual palette is already gruvbox — keep it.
    #targets.starship.enable = false;
    # bat's stylix theme is a home-manager target, disabled in shells/shells.nix

    # hyprlock: do NOT enable stylix's target, here or at the HM level. Besides
    # being HM-only (so it could never work from this file), it also forces
    # settings.background to a solid base00, which collides with the blurred
    # wallpaper list in modules/home-manager/wm/hyprland/default.nix ("defined
    # multiple times ... expected to be unique"). The input-field colours are
    # written there directly from config.lib.stylix.colors instead — the same
    # base16 values the target would have set, so they still follow the light/dark
    # specialisation. See the matching note in modules/home-manager/stylix.nix.
  };
}

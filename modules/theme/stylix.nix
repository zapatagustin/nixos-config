{ pkgs, config, ... }:
let
  # Scheme, fonts and cursor are shared with the HM stylix instance -- stylix does
  # not propagate them, so both files declare them and ./tokens.nix is the one place
  # they are written.
  tokens = import ./tokens.nix pkgs;
in
{
  # ecomono: autoEnable=false + explicit targets to avoid missing-option
  # errors from targets referencing DE configs we don't have (gnome, kmscon, etc.)
  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";
    base16Scheme = tokens.scheme "dark";

    # No DE/compositor: wallpaper is just a solid bg pixel.
    image = config.lib.stylix.pixel "base00";

    inherit (tokens) fonts;

    # Sets environment.variables.XCURSOR_SIZE plus the theme name. The session's own
    # XCURSOR_/HYPRCURSOR_ vars come from home.pointerCursor (home-manager/home.nix),
    # which reads the same tokens.cursor. Name verified against the release's
    # share/icons dirs.
    inherit (tokens) cursor;

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

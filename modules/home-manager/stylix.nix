{ pkgs, lib, inputs, ... }:
let
  scheme = variant: "${pkgs.base16-schemes}/share/themes/gruvbox-${variant}-medium.yaml";
in
{
  # Runtime light/dark switch, with no per-target rules to maintain.
  #
  # stylix has no dual-scheme or runtime-switch support: base16Scheme is one value
  # per evaluation. (polarity is NOT the switch axis here — with base16Scheme set
  # explicitly, polarity only feeds stylix's wallpaper-driven palette generator,
  # and none of the targets enabled below read it.) So the light palette is a
  # home-manager specialisation: a second full evaluation of this config. Every
  # stylix target regenerates for free — verified, 11 files differ between the two
  # generations (kitty, neovim, bat, yazi, zellij, zathura, zed, gtk-3.0, gtk-4.0,
  # and stylix's own palette.json/html).
  #
  # mkForce is required, not optional: inheritParentConfig is on, so the parent's
  # base16Scheme definition below is also present and must be outranked rather
  # than merged (a plain assignment is a "conflicting definition values" error).
  #
  # Switch with `set-theme {dark|light|toggle|auto}` (scripts/set-theme.sh). Dark
  # is the parent generation, so a nixos-rebuild switch reverts to it.
  specialisation.light.configuration.stylix.base16Scheme =
    lib.mkForce (scheme "light");

  # Central HM stylix instance. The stylix HM module computes read-only options
  # (stylix.base16), so it must be imported and configured exactly ONCE — a second
  # scoped instance in another module conflicts. Global homeManagerIntegration.autoImport
  # stays off (it pulls every HM target and clashes with the manual gtk/cursor/kitty/bat
  # setup), so targets are enabled explicitly here, one line per app.
  #
  # Same gruvbox-dark-medium scheme as the system (modules/theme/stylix.nix).
  imports = [ inputs.stylix.homeModules.stylix ];
  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";
    base16Scheme = scheme "dark";

    # This HM instance does NOT inherit fonts from the system stylix (modules/theme/
    # stylix.nix) — it falls back to stylix's DejaVu defaults. HM targets (gtk.font,
    # zed ui_font, kitty font) read THESE, so mirror the system fonts here: Terminess
    # everywhere, including sansSerif/serif, so no target picks DejaVu.
    fonts = {
      monospace = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font Mono"; };
      sansSerif = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font"; };
      serif = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font"; };
    };

    targets = {
      neovim.enable = true;
      zed.enable = true;
      kitty.enable = true;
      bat.enable = true;
      zathura.enable = true;
      yazi.enable = true;
      zellij.enable = true; # activated via `theme "stylix"` in zellij/config.kdl
      # hyprlock deliberately NOT enabled: stylix's hyprlock target also sets
      # `programs.hyprlock.settings.background` to a solid base00 colour, which
      # collides with the blurred-wallpaper background list in
      # wm/hyprland/default.nix ("defined multiple times ... expected to be
      # unique"). That collision is why it was commented out before. The
      # input-field colours are instead written there directly from
      # config.lib.stylix.colors — same base16 values the target would have used,
      # so they still follow the light/dark specialisation.
      # adw-gtk3 skeleton + base16 gtk.css overlay: same 16 colors as everything
      # else, native GTK4/libadwaita, and flatpak theming. Replaces the manual
      # gruvbox-gtk-theme (only the theme; iconTheme=papirus stays in home.nix).
      gtk.enable = true;

      # Deliberately OFF — stylix here is a no-op or a regression:
      #   starship -> shells/starship/starship.nix already uses the exact
      #               gruvbox-dark-medium hexes with lib.mkForce; stylix's base16
      #               palette uses different color names, so the target either
      #               no-ops (mkForce wins) or needs a full format rewrite for
      #               zero visual change.
      #   emacs    -> doom owns its theme (doom-theme); stylix's load-theme is
      #               overridden by doom at init. Unify in doom config, not here.
    };
  };
}

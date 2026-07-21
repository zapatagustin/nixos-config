{ pkgs, inputs, ... }:
{
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
    base16Scheme = "${pkgs.base16-schemes}/share/themes/gruvbox-dark-medium.yaml";

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

# Single source for the theme values that BOTH stylix instances need.
#
# There are two instances on purpose -- the NixOS one (./stylix.nix) and the
# home-manager one (../home-manager/stylix.nix) -- because HM targets read the HM
# instance and console/system bits read the system one. What is NOT on purpose is
# that stylix propagates nothing between them: the HM instance falls back to
# stylix's DejaVu defaults rather than inheriting the system fonts. So each file
# has to declare the same values, and they were duplicated verbatim: editing the
# font in one and not the other was a silent, invisible drift, and the cursor had
# already drifted (system 24 vs session 36) before this file existed.
#
# A plain function of `pkgs`, not a NixOS/HM module: it is `import`ed from two
# different module systems, and each passes its own pkgs instance.
pkgs: {
  # gruvbox medium, per polarity. `variant` is "dark" or "light" -- the light one
  # is the home-manager specialisation that set-theme.sh activates.
  scheme = variant: "${pkgs.base16-schemes}/share/themes/gruvbox-${variant}-medium.yaml";

  # Terminess = Terminus patched by Nerd Fonts: same look + glyphs (bar/prompt
  # icons). Monospace only.
  #
  # sansSerif/serif used to be Terminess too, so that stylix targets picking
  # sansSerif for UI (gtk.font, zed ui_font, qt general font) stayed in one family.
  # That is the wrong tradeoff: Terminess is drawn for a fixed pixel grid and a
  # terminal's cell metrics, and it renders badly as proportional UI text --
  # especially on a light background, where the thin stems lose the contrast that
  # made them legible on dark. The visible symptom was "the font looks wrong in
  # light mode"; the font was equally wrong in dark, just less obvious.
  #
  # IBM Plex Sans/Serif for the UI roles. The quickshell bar is unaffected: every
  # bar element pins "Terminess Nerd Font Mono" (or "Symbols Nerd Font") by name in
  # its QML, so the Nerd Font glyphs never went through sansSerif.
  #
  # Sizes stay at stylix's defaults (desktop 10, applications 12, terminal ->
  # applications, popups -> desktop): they were never part of this bug.
  fonts = {
    monospace = { package = pkgs.nerd-fonts.terminess-ttf; name = "Terminess Nerd Font Mono"; };
    sansSerif = { package = pkgs.ibm-plex; name = "IBM Plex Sans"; };
    serif = { package = pkgs.ibm-plex; name = "IBM Plex Serif"; };
  };

  # Consumed by stylix.cursor (system, which exports XCURSOR_SIZE into
  # environment.variables) and by home.pointerCursor (HM, which installs the theme
  # to ~/.icons and exports the session's XCURSOR_/HYPRCURSOR_ vars). Each adds its
  # own enable/gtk/hyprcursor flags; only these three fields are shared.
  #
  # Size 36 is the value the graphical session has always used. The system instance
  # said 24, so a user unit that did not inherit the session env drew a smaller
  # cursor than anything launched from Hyprland -- the two scopes now agree.
  cursor = {
    package = pkgs.capitaine-cursors-themed;
    name = "Capitaine Cursors (Gruvbox)";
    size = 36;
  };
}

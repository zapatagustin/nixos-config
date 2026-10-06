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
  # The one scheme: dither, a warm sepia base16 palette.
  scheme = ./dither.yaml;

  # PxPlus IBM VGA8 is the terminal/monospace face: a faithful recreation of the
  # IBM VGA 8x16 glyph set. It intentionally has no Nerd Font glyphs, so targets
  # that name the family (kitty, foot, GTK) get the retro look, as does any generic
  # `monospace` request via fonts.fontconfig.defaultFonts (default.nix), while
  # the quickshell bar uses it through its Theme.qml singleton, while Emacs pins
  # Terminess Nerd Font Mono by name and migrates separately.
  #
  # sansSerif/serif stay IBM Plex Sans/Serif for UI text: VGA is drawn for a fixed
  # pixel grid and terminal cell metrics, and it renders badly as proportional UI
  # text. Sizes stay at stylix's defaults (desktop 10, applications 12, terminal ->
  # applications, popups -> desktop): they were never part of this change.
  fonts = {
    monospace = { package = pkgs.callPackage ./pxplus-ibm-vga8.nix { }; name = "PxPlus IBM VGA8"; };
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

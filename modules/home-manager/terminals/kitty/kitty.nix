_: {
  programs.kitty = {
    enable = true;
    # Colors, font family and size come from stylix.targets.kitty
    # (modules/home-manager/stylix.nix): the dither base16 scheme
    # + PxPlus IBM VGA8.
    settings = {
      # No bold_font/italic_font/bold_italic_font overrides: VGA8 is a single-face
      # pixel font, so explicit overrides just re-named the same regular face the
      # default (`auto`, fontconfig-resolved) already lands on — zero control over
      # how kitty renders emphasis, three extra settings to drift. Deriving from
      # the regular face is what foot does too. Tradeoff, accepted: kitty renders
      # bold/italic emphasis itself rather than from real faces; a pixel font has
      # no real variants to offer either way.

      # VGA8 has no Nerd Font glyphs; map the private-use ranges to Symbols Nerd
      # Font so plugin icons and powerline separators still render. The CJK
      # Radicals Supplement (U+2E80-U+2EF3) is deliberately NOT mapped: Symbols
      # Nerd Font has no CJK, and symbol_map bypasses normal fallback for mapped
      # ranges — mapping it rendered those codepoints as tofu instead of letting
      # them fall through to Noto CJK.
      symbol_map = "U+23FB-U+23FE,U+E000-U+F8FF,U+F0000-U+FFFFD,U+100000-U+10FFFD Symbols Nerd Font";

      # adjust_line_height = "92%"; # disabled until a non-8x16 monospace font
      # returns: the PxPlus IBM VGA8 cell (12pt @ 96 dpi = 16px) must stay at 100%.
      confirm_os_window_close = 0;
    };
  };
}

{ config, ... }:
let
  # Palette of the one theme, straight from the active stylix scheme.
  # withHashtag yields the `#`-prefixed form zellij wants.
  colors = config.lib.stylix.colors.withHashtag;

  # Copied from stylix's own zellij target (its modules/zellij/hm.nix) rather than
  # invented, so the theme renders exactly like stylix's. It IS a second copy of
  # that mapping and can drift from upstream -- accepted because stylix's target
  # is disabled (it declares a theme called `default`, not `dither`).
  mkTheme = c: with c; {
    text_unselected = {
      base = base05;
      background = base01;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0B;
      emphasis_3 = base0F;
    };
    text_selected = {
      base = base05;
      background = base04;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0B;
      emphasis_3 = base0F;
    };
    ribbon_selected = {
      base = base01;
      background = base0E;
      emphasis_0 = base08;
      emphasis_1 = base09;
      emphasis_2 = base0F;
      emphasis_3 = base0D;
    };
    ribbon_unselected = {
      base = base05;
      background = base02;
      emphasis_0 = base08;
      emphasis_1 = base05;
      emphasis_2 = base0D;
      emphasis_3 = base0F;
    };
    table_title = {
      base = base0E;
      background = base00;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0B;
      emphasis_3 = base0F;
    };
    table_cell_selected = {
      base = base05;
      background = base04;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0B;
      emphasis_3 = base0F;
    };
    table_cell_unselected = {
      base = base05;
      background = base01;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0B;
      emphasis_3 = base0F;
    };
    list_selected = {
      base = base05;
      background = base04;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0B;
      emphasis_3 = base0F;
    };
    list_unselected = {
      base = base05;
      background = base01;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0B;
      emphasis_3 = base0F;
    };
    frame_selected = {
      base = base0E;
      background = base00;
      emphasis_0 = base09;
      emphasis_1 = base0C;
      emphasis_2 = base0F;
      emphasis_3 = base00;
    };
    frame_highlight = {
      base = base08;
      background = base00;
      emphasis_0 = base0F;
      emphasis_1 = base09;
      emphasis_2 = base09;
      emphasis_3 = base09;
    };
    exit_code_success = {
      base = base0B;
      background = base00;
      emphasis_0 = base0C;
      emphasis_1 = base01;
      emphasis_2 = base0F;
      emphasis_3 = base0D;
    };
    exit_code_error = {
      base = base08;
      background = base00;
      emphasis_0 = base0A;
      emphasis_1 = base00;
      emphasis_2 = base00;
      emphasis_3 = base00;
    };
    multiplayer_user_colors = {
      player_1 = base0F;
      player_2 = base0D;
      player_3 = base00;
      player_4 = base0A;
      player_5 = base0C;
      player_6 = base00;
      player_7 = base08;
      player_8 = base00;
      player_9 = base00;
      player_10 = base00;
    };
  };
in
{
  programs.zellij.enable = true;

  # The outer attr name is the FILENAME (themes/dither.kdl); the inner one is the
  # theme NAME config.kdl's `theme` refers to. Keeping the two equal avoids the trap
  # in stylix's own target, whose themes/stylix.kdl declares a theme called
  # `default`.
  programs.zellij.themes.dither.themes.dither = mkTheme colors;

  xdg.configFile."zellij/config.kdl".source = ./config.kdl;
}

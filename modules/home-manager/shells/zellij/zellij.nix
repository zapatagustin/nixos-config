{ pkgs, lib, ... }:
let
  inherit ((import ../../../theme/tokens.nix pkgs)) scheme;

  # BOTH palettes have to exist at once, which is the whole reason this file
  # generates the themes instead of stylix.targets.zellij (now disabled in
  # ../../stylix.nix). stylix evaluates ONE palette per generation, so its target
  # can only ever ship the active one -- and zellij's `set-dark-theme` /
  # `set-light-theme` actions, the only way to retheme a LIVE session, switch
  # between the two themes named in theme_dark/theme_light. One theme means there
  # is nothing to switch to.
  #
  # That the actions really do retheme a running session was verified by
  # screenshot, not by reading docs: the status bar accent went d3869b -> 8f3f71,
  # i.e. base0E of gruvbox-dark-medium to base0E of gruvbox-light-medium, with no
  # restart and no new session.
  #
  # Side benefit: these two files are identical in both generations, so
  # zellij/themes drops out of the set of files a palette switch has to relink.

  # The yaml is the same file stylix itself reads (../../../theme/tokens.nix), so
  # this adds a second READER of the palette, never a second copy of the hexes.
  # Values come out already `#`-prefixed, which is the form zellij wants.
  #
  # Fails loudly rather than shipping a half-built theme: a scheme that stopped
  # parsing would otherwise silently produce null colours deep inside the kdl.
  readScheme = yaml:
    let
      lines = lib.splitString "\n" (builtins.readFile yaml);
      matches = lib.filter (m: m != null)
        (map (builtins.match "[[:space:]]*(base[0-9A-F]{2}):[[:space:]]*\"(#[0-9a-fA-F]{6})\".*") lines);
    in
    lib.throwIf (builtins.length matches != 16)
      "zellij.nix: expected 16 base16 colours in ${yaml}, parsed ${toString (builtins.length matches)}"
      (builtins.listToAttrs
        (map (m: lib.nameValuePair (builtins.elemAt m 0) (builtins.elemAt m 1)) matches));

  # Copied from stylix's own zellij target (its modules/zellij/hm.nix) rather than
  # invented, so both themes render exactly like the single one that shipped before
  # this file existed. It IS a second copy of that mapping and can drift from
  # upstream -- the tradeoff accepted in exchange for having both palettes at once.
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

  # The outer attr name is the FILENAME (themes/<name>.kdl); the inner one is the
  # theme NAME config.kdl's theme_dark/theme_light refer to. Keeping the two equal
  # avoids the trap in stylix's own target, whose themes/stylix.kdl declares a theme
  # called `default` while config.kdl asked for `theme "stylix"` -- it worked, but
  # only because zellij also resolves a theme by its file name.
  programs.zellij.themes = {
    stylix-dark.themes.stylix-dark = mkTheme (readScheme (scheme "dark"));
    stylix-light.themes.stylix-light = mkTheme (readScheme (scheme "light"));
  };

  xdg.configFile."zellij/config.kdl".source = ./config.kdl;
}

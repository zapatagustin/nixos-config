{ pkgs, lib, config, ... }:
let
  inherit ((import ../../../theme/tokens.nix pkgs)) scheme;

  # Which palette THIS generation carries. The sepia specialisation
  # (modules/home-manager/stylix.nix) mkForces stylix.base16Scheme to the sepia
  # yaml; the parent and the dark specialisation carry the gruvbox one. Compared
  # against the scheme value itself rather than a second flag that could drift --
  # same pinning as flake.nix's theme-invariants check. toString normalises
  # path-vs-string before comparing.
  mode =
    if toString config.stylix.base16Scheme == toString (scheme "sepia")
    then "sepia"
    else "dark";
  # zellij's hue vocabulary is dark/light; sepia occupies the "light" slot of the
  # dark/sepia pair (the same mapping theme_light uses in config.kdl).
  hue = if mode == "sepia" then "light" else "dark";

  # BOTH palettes have to exist at once, which is the whole reason this file
  # generates the themes instead of stylix.targets.zellij (now disabled in
  # ../../stylix.nix). stylix evaluates ONE palette per generation, so its target
  # can only ever ship the active one -- and zellij's `set-dark-theme` /
  # `set-light-theme` actions, the only way to retheme a LIVE session, switch
  # between the two themes named in theme_dark/theme_light. One theme means there
  # is nothing to switch to.
  #
  # The actions retheme a running session with no restart and no new session:
  # set-theme.sh sends set-dark-theme / set-light-theme to every live (non-EXITED)
  # session via `zellij --session <name> action ...`. theme_light is the sepia
  # palette.
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
  #
  # theme_light points at stylix-sepia: Athanor sepia is the "light" slot in the
  # dark/sepia pair, even though it is still a dark palette by luminance.
  programs.zellij.themes = {
    stylix-dark.themes.stylix-dark = mkTheme (readScheme (scheme "dark"));
    stylix-sepia.themes.stylix-sepia = mkTheme (readScheme (scheme "sepia"));
  };

  # config.kdl's `theme`/`explicit_theme_hue` are per-generation (@theme@/@hue@
  # placeholders), so the file is substituted rather than deployed verbatim.
  # A static `theme` line cannot be mode-aware; see the comment block above the
  # theme_dark/theme_light pair in config.kdl for why hue is the knob that works.
  xdg.configFile."zellij/config.kdl".source = pkgs.replaceVars ./config.kdl {
    theme = "stylix-${mode}";
    inherit hue;
  };
}

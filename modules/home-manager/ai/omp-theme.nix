{ config, lib, pkgs, inputs, ... }:
let
  # Palette of the one theme, straight from the active stylix scheme.
  c = config.lib.stylix.colors.withHashtag;

  # The token list follows omp 18.15.0's tui/src/theme/theme-schema.json
  # (`colors.required`, plus the optional assistantMessageText and thinkingMax).
  # It IS a copy of that schema and drifts on omp bumps: a new required token
  # makes omp reject the theme, so re-diff the schema when bumping omp.
  # dim/muted are base04, never base03: omp paints pending todo rows and phase
  # headers with them, and base03 (comment grey) is unreadable there.
  colors = {
    accent = c.base0A;
    borderAccent = c.base0A;
    customMessageLabel = c.base0A;
    toolTitle = c.base0A;
    mdHeading = c.base0A;
    mdListBullet = c.base0A;
    statusLineModel = c.base0A;
    syntaxType = c.base0A;
    thinkingHigh = c.base0A;

    border = c.base03;
    mdCodeBlockBorder = c.base03;
    mdQuoteBorder = c.base03;
    mdHr = c.base03;
    statusLineSep = c.base03;
    thinkingOff = c.base03;
    syntaxComment = c.base03;

    borderMuted = c.base02;
    selectedBg = c.base02;

    text = c.base05;
    assistantMessageText = c.base05;
    userMessageText = c.base05;
    customMessageText = c.base05;
    toolOutput = c.base05;
    mdCodeBlock = c.base05;
    statusLineOutput = c.base05;
    syntaxOperator = c.base05;
    syntaxPunctuation = c.base05;

    dim = c.base04;
    muted = c.base04;
    thinkingText = c.base04;
    mdLinkUrl = c.base04;
    mdQuote = c.base04;
    toolDiffContext = c.base04;
    statusLineContext = c.base04;
    thinkingMinimal = c.base04;

    success = c.base0B;
    toolDiffAdded = c.base0B;
    statusLineGitClean = c.base0B;
    statusLineStaged = c.base0B;
    syntaxString = c.base0B;

    error = c.base08;
    toolDiffRemoved = c.base08;
    statusLineUntracked = c.base08;
    syntaxVariable = c.base08;
    thinkingMax = c.base08;

    warning = c.base09;
    mdCode = c.base09;
    statusLineGitDirty = c.base09;
    statusLineDirty = c.base09;
    syntaxNumber = c.base09;
    bashMode = c.base09;
    thinkingXhigh = c.base09;

    mdLink = c.base0C;
    pythonMode = c.base0C;
    statusLineSubagents = c.base0C;
    thinkingMedium = c.base0C;

    statusLinePath = c.base0D;
    syntaxFunction = c.base0D;
    thinkingLow = c.base0D;

    statusLineSpend = c.base0E;
    statusLineCost = c.base0E;
    syntaxKeyword = c.base0E;

    userMessageBg = c.base01;
    customMessageBg = c.base01;
    toolPendingBg = c.base01;
    toolSuccessBg = c.base01;
    toolErrorBg = c.base01;
    statusLineBg = c.base01;
  };

  theme = {
    name = "dither";
    inherit colors;
    symbols = {
      preset = "unicode";
      # Rounding 0 (house style): every rounded box key takes its sharp glyph.
      # PxPlus IBM VGA8 has these; it lacks the unicode preset's ☐ ☑ ╭.
      overrides = {
        "checkbox.checked" = "✓";
        "checkbox.unchecked" = "○";
        "boxRound.topLeft" = "┌";
        "boxRound.topRight" = "┐";
        "boxRound.bottomLeft" = "└";
        "boxRound.bottomRight" = "┘";
        "boxRound.horizontal" = "─";
        "boxRound.vertical" = "│";
      };
      spinnerFrames = [ "░" "▒" "▓" "█" "▓" "▒" ];
    };
  };
in
{
  home.file.".omp/agent/themes/dither.json".text = builtins.toJSON theme;

  # omp owns ~/.omp/agent/config.yml and rewrites it at runtime, so the
  # settings cannot be a home.file link (ai/default.nix skips programs.omp for
  # the same reason). omp's own `config set` puts them in at activation: it
  # validates the key, writes atomically (temp + rename), keeps every other key
  # and leaves the file alone when the value already matches. A failure warns
  # and never stops the switch. `--` lets -1 through as a value, not an option.
  #   symbolPreset: the setting beats the theme's preset, and today's `nerd`
  #     draws glyphs PxPlus IBM VGA8 lacks; the theme's overrides still apply.
  #   tasks.todoClearDelay -1: the todo HUD never hides itself once all done.
  #   tui.vimMode: the prompt gets vim's insert/normal/visual modes; the mode
  #     shows as text in the status line's `vim` segment (starship colors it
  #     the same way: insert green, normal amber, visual teal).
  #   statusLine custom: vim mode, path and git counters on the left; the
  #     ecomono extension's `todo N` (its `status` entry), model, context,
  #     cost and time on the right. `block` separators: the powerline caps
  #     are glyphs the VGA8 font lacks. Array values are JSON for `config set`;
  #     omp refuses an unknown segment id, so a typo fails the switch's log
  #     line, never the file.
  #   statusLine.showHookStatus false: omp's legacy status renderer repeats
  #     every hook status as a line under the bar even when the `status`
  #     segment already shows it inline (tui/src/status-line/component.ts
  #     render); this keeps the inline copy only.
  #   startup.quiet: omp's own welcome (pi logo, wordmark, tip) is off; the
  #     ecomono extension draws its own banner, the wallpaper's engraving
  #     (an inline image when the terminal draws one: kitty, iTerm2, sixel; the PNG
  #     nixos-config builds, handed over in ECOMONO_OMP_BANNER; else a block-glyph cut), as a widget above the editor, taken down at the first prompt.
  home.activation.ompSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ompSet() {
      run ${pkgs.coreutils}/bin/timeout 10 ${inputs.oh-my-pi.packages.${pkgs.stdenv.hostPlatform.system}.omp}/bin/omp \
        config set "$1" -- "$2" >/dev/null \
        || echo "omp-theme: omp config set $1 $2 failed; set it by hand" >&2
    }
    ompSet theme.dark dither
    ompSet symbolPreset unicode
    ompSet tasks.todoClearDelay -1
    ompSet tui.vimMode true
    ompSet tui.vimModeDisplay text
    ompSet statusLine.preset custom
    ompSet statusLine.leftSegments '["vim","path","git"]'
    ompSet statusLine.rightSegments '["status","model","context_pct","cost","time"]'
    ompSet statusLine.separator block
    ompSet statusLine.showHookStatus false
    ompSet startup.quiet true
  '';
}

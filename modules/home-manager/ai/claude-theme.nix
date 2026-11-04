# Claude Code dressed like omp (./omp-theme.nix): the same stylix palette as a
# custom theme, vim mode, no spinner tips, and a status line with omp's segments
# (vim mode, path, git on the left; model, context, cost, time on the right),
# plus the plan-usage windows ecomono's own statusline shows.
{ config, lib, pkgs, ... }:
let
  c = config.lib.stylix.colors;
  h = c.withHashtag;

  # `share` of colour `n` over the background, per channel. Claude Code's diff
  # tokens are line BACKGROUNDS, so the raw base08/base0B would bury the text.
  mix = share: n:
    let
      one = k:
        let
          fg = lib.toInt c."${n}-rgb-${k}";
          bg = lib.toInt c."base00-rgb-${k}";
        in
        lib.fixedWidthString 2 "0" (lib.toHexString (builtins.floor (bg + share * (fg - bg))));
    in
    "#${one "r"}${one "g"}${one "b"}";

  # Tokens follow code.claude.com/docs/en/terminal-config ("Create a custom
  # theme"); unknown tokens are silently ignored, so a renamed one falls back to
  # the `dark` base instead of breaking. Roles mirror the omp theme: accent
  # base0A, borders base03, muted base04, panels base01.
  theme = {
    name = "Dither";
    base = "dark";
    overrides = {
      claude = h.base0A;
      text = h.base05;
      inverseText = h.base00;
      inactive = h.base04;
      subtle = h.base03;
      suggestion = h.base0A;
      permission = h.base0A;
      remember = h.base0E;

      success = h.base0B;
      error = h.base08;
      warning = h.base09;
      merged = h.base0E;

      promptBorder = h.base03;
      planMode = h.base0C;
      autoAccept = h.base0E;
      bashBorder = h.base09;
      ide = h.base0D;
      fastMode = h.base09;
      effortUltra = h.base08;

      diffAdded = mix 0.25 "base0B";
      diffRemoved = mix 0.25 "base08";
      diffAddedDimmed = mix 0.12 "base0B";
      diffRemovedDimmed = mix 0.12 "base08";
      diffAddedWord = mix 0.5 "base0B";
      diffRemovedWord = mix 0.5 "base08";

      userMessageBackground = h.base01;
      userMessageBackgroundHover = h.base02;
      bashMessageBackgroundColor = h.base01;
      memoryBackgroundColor = h.base01;
      selectionBg = h.base02;
      composerSidebarBackground = h.base01;

      rate_limit_fill = h.base0A;
      rate_limit_empty = h.base02;
      briefLabelYou = h.base0A;
      briefLabelClaude = h.base0D;

      claudeShimmer = h.base06;
      warningShimmer = h.base0A;
      permissionShimmer = h.base06;
      promptBorderShimmer = h.base04;
      inactiveShimmer = h.base05;
      fastModeShimmer = h.base0A;
    }
    // lib.mapAttrs' (k: v: lib.nameValuePair "${k}_FOR_SUBAGENTS_ONLY" h.${v}) {
      red = "base08";
      orange = "base09";
      yellow = "base0A";
      green = "base0B";
      cyan = "base0C";
      blue = "base0D";
      purple = "base0E";
      pink = "base0F";
    }
    // lib.concatMapAttrs
      (k: v: {
        "rainbow_${k}" = h.${v};
        "rainbow_${k}_shimmer" = h.base06;
      })
      {
        red = "base08";
        orange = "base09";
        yellow = "base0A";
        green = "base0B";
        blue = "base0D";
        indigo = "base0E";
        violet = "base0F";
      };
  };

  # ANSI codes, not hex: the terminal palette is already the stylix base16 one
  # (32 green = base0B, 33 yellow = base0A, 34 blue = base0D, 35 magenta =
  # base0E, 36 cyan = base0C, 90 bright black = base03), so these land on the
  # same colours omp's status line uses for each segment.
  statusline = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = with pkgs; [ jq git coreutils ];
    text = ''
      # ''${#var} must count characters, not bytes, for the right-alignment pad.
      export LC_ALL=C.UTF-8

      IFS=$'\t' read -r vim cwd model ctx cost p5 r5 p7 r7 < <(jq -r '
        [(.vim.mode // "-"),
         (.workspace.current_dir // .cwd // "-"),
         (.model.display_name // "?"),
         (.context_window.used_percentage // "-"),
         (.cost.total_cost_usd // "-"),
         (.rate_limits.five_hour.used_percentage // "-"),
         (.rate_limits.five_hour.resets_at // "-"),
         (.rate_limits.seven_day.used_percentage // "-"),
         (.rate_limits.seven_day.resets_at // "-")] | @tsv')

      lp="" lc="" rp="" rc=""
      sepP=" │ " sepC=$'\e[90m │ \e[0m'
      # seg SIDE PLAIN COLOURED: plain text measures, coloured text prints.
      seg() {
        if [[ $1 == L ]]; then
          [[ -n $lp ]] && { lp+=$sepP; lc+=$sepC; }
          lp+=$2 lc+=$3
        else
          [[ -n $rp ]] && { rp+=$sepP; rc+=$sepC; }
          rp+=$2 rc+=$3
        fi
      }
      paint() { printf '\e[%sm%s\e[0m' "$1" "$2"; }
      # green <50, yellow <80, red >=80
      pct() {
        local p; p=$(printf '%.0f' "$1")
        if ((p >= 80)); then paint 31 "$p%"; elif ((p >= 50)); then paint 33 "$p%"; else paint 32 "$p%"; fi
      }

      # vim: insert green, normal amber, visual teal (omp/starship colours).
      if [[ $vim != - ]]; then
        case $vim in
          INSERT) code=32 ;; NORMAL) code=33 ;; *) code=36 ;;
        esac
        seg L "$vim" "$(paint "$code" "$vim")"
      fi

      if [[ $cwd != - ]]; then
        path=''${cwd/#"$HOME"/\~}
        seg L "$path" "$(paint 34 "$path")"

        # git: branch, then +staged !dirty ?untracked, like omp's counters.
        if status=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null); then
          branch="" staged=0 dirty=0 untracked=0
          while IFS= read -r line; do
            case $line in
              "# branch.head "*) branch=''${line#"# branch.head "} ;;
              "? "*) untracked=$((untracked + 1)) ;;
              [12u]" "*)
                xy=''${line:2:2}
                [[ ''${xy:0:1} != . ]] && staged=$((staged + 1))
                [[ ''${xy:1:1} != . ]] && dirty=$((dirty + 1))
                ;;
            esac
          done <<<"$status"
          gp=$branch
          if ((staged + dirty + untracked == 0)); then gc=$(paint 32 "$branch"); else gc=$(paint 33 "$branch"); fi
          ((staged)) && { gp+=" +$staged"; gc+=" $(paint 32 "+$staged")"; }
          ((dirty)) && { gp+=" !$dirty"; gc+=" $(paint 33 "!$dirty")"; }
          ((untracked)) && { gp+=" ?$untracked"; gc+=" $(paint 31 "?$untracked")"; }
          seg L "$gp" "$gc"
        fi
      fi

      seg R "$model" "$(paint 33 "$model")"
      if [[ $ctx != - ]]; then
        p=$(printf '%.0f' "$ctx")
        seg R "ctx $p%" "ctx $(pct "$ctx")"
      fi
      if [[ $cost != - ]]; then
        usd=$(printf '$%.2f' "$cost")
        seg R "$usd" "$(paint 35 "$usd")"
      fi
      # Plan usage (subscription auth only, after the first API response).
      if [[ $p5 != - ]]; then
        p=$(printf '%.0f' "$p5") t=""
        [[ $r5 != - ]] && t=" →$(date -d "@$r5" +%H:%M)"
        seg R "5h $p%$t" "5h $(pct "$p5")$(paint 2 "$t")"
      fi
      if [[ $p7 != - ]]; then
        p=$(printf '%.0f' "$p7") t=""
        [[ $r7 != - ]] && t=" →$(date -d "@$r7" +'%a %H:%M')"
        seg R "7d $p%$t" "7d $(pct "$p7")$(paint 2 "$t")"
      fi
      now=$(date +%H:%M)
      seg R "$now" "$now"

      # Right-align like omp when it fits. ecomono: Claude Code exports
      # COLUMNS but does not document how much of it the status row may use;
      # the 4-column margin is a guess. Too small wraps the line; then raise it.
      width=$((''${COLUMNS:-0} - 4))
      pad=$((width - ''${#lp} - ''${#rp}))
      if ((pad >= 1)); then
        printf '%s%*s%s\n' "$lc" "$pad" "" "$rc"
      elif [[ -n $lc ]]; then
        printf '%s%s%s\n' "$lc" "$sepC" "$rc"
      else
        printf '%s\n' "$rc"
      fi
    '';
  };
in
{
  home.file = {
    # ecomono links ~/.claude/themes as one store directory; recursive makes it
    # a real directory of per-file links, so the generated theme can sit beside
    # ecomono's own.
    ".claude/themes".recursive = true;
    ".claude/themes/dither.json".text = builtins.toJSON theme;
  };

  # One-time migration: before `recursive`, ~/.claude/themes was a single link
  # into an old home-manager-files store path. Home Manager does not treat it as
  # an orphan (the path still exists in the new generation, as a directory), so
  # it survives and linking dither.json through it hits the read-only store.
  # Only a link into /nix/store is removed; a real directory is never touched.
  home.activation.claudeThemesUnlink = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    themes="$HOME/.claude/themes"
    if [ -L "$themes" ] && [[ "$(${pkgs.coreutils}/bin/readlink "$themes")" == /nix/store/* ]]; then
      run ${pkgs.coreutils}/bin/rm "$themes"
    fi
  '';

  # Claude Code owns ~/.claude/settings.json and rewrites it at runtime (the
  # ecomono flake leaves it unmanaged for that reason), so the keys are merged
  # in at activation, the same way omp-theme.nix uses `omp config set`. Every
  # other key is kept; jq failing leaves the file untouched, and a missing file
  # is left for Claude Code to create rather than seeded half-empty.
  #   refreshInterval 30: the clock segment would otherwise only move on events.
  #   hideVimModeIndicator: the status line already shows the mode.
  home.activation.claudeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.claude/settings.json"
    if [ -f "$settings" ]; then
      tmp=$(${pkgs.coreutils}/bin/mktemp "$settings.XXXXXX")
      if ${pkgs.jq}/bin/jq --arg cmd ${lib.getExe statusline} '
        .theme = "custom:dither"
        | .editorMode = "vim"
        | .spinnerTipsEnabled = false
        | .statusLine = {
            type: "command", command: $cmd,
            refreshInterval: 30, hideVimModeIndicator: true
          }' "$settings" >"$tmp"; then
        run ${pkgs.coreutils}/bin/mv "$tmp" "$settings"
      else
        ${pkgs.coreutils}/bin/rm -f "$tmp"
        echo "claude-theme: could not merge into $settings; left as is" >&2
      fi
    else
      echo "claude-theme: $settings missing; run Claude Code once, then switch again" >&2
    fi
  '';
}

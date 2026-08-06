{ pkgs, lib, inputs, ... }:
let
  # Shared with the system stylix instance (../theme/stylix.nix), which cannot
  # propagate them here. See ../theme/tokens.nix.
  tokens = import ../theme/tokens.nix pkgs;
  inherit (tokens) scheme;

  # Activation steps a palette switch must not pay for. Measured per step on a
  # real switch of this config:
  #
  #   reloadSystemd          6.86s   53%   <- neutralised
  #   ecomonoAgents          4.73s   36%   <- neutralised
  #   linkGeneration         0.44s         the actual work
  #   batCache               0.36s         bat compiles themes into a cache
  #   onFilesChange          0.40s
  #   checkLinkTargets       0.15s
  #   everything else       ~0.05s
  #   TOTAL                 12.99s   ->   0.99s measured with these two removed
  #
  # The entry is replaced whole, with the SAME dag position the real ones have
  # (queried, not guessed: reloadSystemd is entryAfter ["linkGeneration"],
  # ecomonoAgents entryAfter ["writeBoundary"], neither has a `before`), so
  # anything ordered against them still resolves. Overriding just `.data` does
  # NOT work — home.activation is a dagOf, and a bare `data` override lands
  # inside the coercion as a nested attrset and fails the type check.
  #
  # Both skips are safe BY CONSTRUCTION, and flake.nix's theme-invariants-<host>
  # check enforces the reasoning rather than leaving it as a comment nobody
  # rechecks:
  #   reloadSystemd  the generations emit byte-identical systemd user units
  #                  (zero systemd files differ of 168), so it has nothing to
  #                  restart. Skipping it also removes the re-entrancy at its
  #                  root — it was reloadSystemd that started theme-sync.service
  #                  inside set-theme's own run, costing a lock timeout per switch.
  #   ecomonoAgents  manages Claude Code plugins. `diff` of the two activate
  #                  scripts is 4 lines (newGenPath, two onFilesChange _cmp paths,
  #                  zed-user-settings) and none are in this step, so it is
  #                  identical in both and the parent has already run it.
  #
  # Deliberately KEPT: linkGeneration (the point), batCache (bat's theme is
  # compiled into a cache, not read from the file), zedSettingsActivation (its
  # input genuinely differs), onFilesChange and checkLinkTargets (cheap, and they
  # guard the linking).
  trimmedActivation = {
    reloadSystemd = lib.mkForce (lib.hm.dag.entryAfter [ "linkGeneration" ] ":");
    ecomonoAgents = lib.mkForce (lib.hm.dag.entryAfter [ "writeBoundary" ] ":");
  };
in
{
  # Runtime light/dark switch, with no per-target rules to maintain.
  #
  # stylix has no dual-scheme or runtime-switch support: base16Scheme is one value
  # per evaluation. So the light palette is a home-manager specialisation: a second
  # full evaluation of this config. Every stylix target regenerates for free —
  # verified by diffing the two generations, 18 files: bat, btop, kitty, nvim,
  # opencode, zathura, zed, hypr/hyprlock.conf, gtk-3.0 and gtk-4.0 (gtk.css AND settings.ini,
  # the latter because the icon variant follows the palette), .gtkrc-2.0, stylix's
  # own palette.json/html, and zen's userChrome.css, userContent.css and user.js (the
  # last one because stylix's reader-mode prefs are palette-derived too). Notably
  # NOT zellij: shells/zellij/zellij.nix generates both palettes unconditionally, so
  # its themes are byte-identical here.
  #
  # `polarity` is switched alongside base16Scheme. It used to be pinned to "dark"
  # in both, on the reasoning that no ENABLED target reads it (still true of
  # targets.gtk — checked against stylix's modules/gtk/, which never mentions it).
  # But polarity is also the natural place for *us* to branch on, and home.nix now
  # does: the XDG portal's color-scheme and the Papirus icon variant are both
  # derived from it. Leaving it at "dark" is what made "light mode" a lie to every
  # app that asks the portal instead of reading our gtk.css.
  #
  # mkForce is required, not optional: inheritParentConfig is on, so the parent's
  # base16Scheme definition below is also present and must be outranked rather
  # than merged (a plain assignment is a "conflicting definition values" error).
  #
  # Switch with `set-theme {dark|light|toggle|auto}` (scripts/set-theme.sh).
  #
  # BOTH palettes are specialisations, including dark — which carries the same
  # scheme as the parent and therefore produces byte-identical files. That looks
  # redundant and is not: set-theme must never activate the PARENT, because the
  # parent runs the full untrimmed activation. Measured, before dark existed as a
  # specialisation: switching to light took 0.99s and switching back took 12.48s,
  # because "back" meant re-running the parent. With both as specialisations the
  # two directions cost the same. The parent stays untouched so a real
  # `nixos-rebuild switch` still runs every activation step, which is exactly what
  # a rebuild should do.
  #
  # A rebuild therefore lands on the parent, i.e. dark, and theme-sync's `auto`
  # run at login puts the time-of-day palette back.
  specialisation =
    let
      mode = variant: {
        configuration = {
          stylix.polarity = lib.mkForce variant;
          stylix.base16Scheme = lib.mkForce (scheme variant);
          home.activation = trimmedActivation;
        };
      };
    in
    {
      light = mode "light";
      dark = mode "dark";
    };

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
    # zed ui_font, kitty font) read THESE, so both instances read ../theme/tokens.nix
    # instead of each carrying its own copy.
    inherit (tokens) fonts;

    targets = {
      neovim.enable = true;
      zed.enable = true;
      kitty.enable = true;
      bat.enable = true;
      zathura.enable = true;
      btop.enable = true;
      # Needs the mkForce below to evaluate at all — see it for why.
      opencode.enable = true;
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

      # Browser CHROME only -- tabs, toolbar, menus -- via userChrome.css and
      # userContent.css, plus the three font.name.*.x-western prefs. Page content is
      # out of reach by construction: a site only ever learns dark-vs-light through
      # prefers-color-scheme, and no freedesktop mechanism carries a palette.
      #
      # profileNames indexes programs.zen-browser.profiles, whose `default` entry is
      # pinned to the real on-disk directory in home.nix. Leaving this empty is not
      # an error, just a warning and a no-op, so it has to match that attribute name.
      zen-browser = {
        enable = true;
        profileNames = [ "default" ];
      };

      # Deliberately OFF — stylix here is a no-op or a regression:
      #   zellij   -> shells/zellij/zellij.nix generates BOTH palettes instead, which
      #               this target structurally cannot: it evaluates one palette per
      #               generation, and zellij's set-dark-theme/set-light-theme (the
      #               only way to retheme a LIVE session) needs two themes to exist
      #               at once. Enabling both would also collide on
      #               programs.zellij.themes.
      #   starship -> shells/starship/starship.nix already uses the exact
      #               gruvbox-dark-medium hexes with lib.mkForce; stylix's base16
      #               palette uses different color names, so the target either
      #               no-ops (mkForce wins) or needs a full format rewrite for
      #               zero visual change.
      #   emacs    -> doom owns its theme (doom-theme); stylix's load-theme is
      #               overridden by doom at init. Unify in doom config, not here.
    };
  };

  # The ecomono flake pins `"theme": "gruvbox"` in its opencode/tui.json, and
  # stylix's opencode target sets tui.theme = "stylix". Both are ordinary-priority
  # definitions of the same option, so enabling that target without this line is a
  # hard eval error, not a silent last-one-wins:
  #
  #   error: The option `...programs.opencode.tui.theme' has conflicting definition
  #   values: - stylix modules/opencode/hm.nix: "stylix"  - ecomono flake.nix: "gruvbox"
  #
  # Resolved HERE rather than by deleting the key from ecomono, and that is the whole
  # point: ecomono is a standalone flake other machines install without stylix, and
  # dropping its theme would leave every one of them on opencode's default. The
  # collision is local to this config, so the override belongs in this config.
  #
  # Only tui.theme collides. programs.opencode.tui takes pkgs.formats.json's type,
  # which merges per key, so ecomono's `plugin` list survives untouched — verified,
  # not assumed.
  programs.opencode.tui.theme = lib.mkForce "stylix";
}

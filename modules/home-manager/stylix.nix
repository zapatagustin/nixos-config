{ pkgs, lib, inputs, ... }:
let
  # Shared with the system stylix instance (../theme/stylix.nix), which cannot
  # propagate them here. See ../theme/tokens.nix.
  tokens = import ../theme/tokens.nix pkgs;
  inherit (tokens) scheme;
in
{
  # Central HM stylix instance. The stylix HM module computes read-only options
  # (stylix.base16), so it must be imported and configured exactly ONCE — a second
  # scoped instance in another module conflicts. Global homeManagerIntegration.autoImport
  # stays off (it pulls every HM target and clashes with the manual gtk/cursor/kitty/bat
  # setup), so targets are enabled explicitly here, one line per app.
  #
  # Same dither scheme as the system (modules/theme/stylix.nix).
  imports = [ inputs.stylix.homeModules.stylix ];
  stylix = {
    enable = true;
    autoEnable = false;
    polarity = "dark";
    base16Scheme = scheme;

    # This HM instance does NOT inherit fonts from the system stylix (modules/theme/
    # stylix.nix) — it falls back to stylix's DejaVu defaults. HM targets (gtk.font,
    # zed ui_font, kitty font) read THESE, so both instances read ../theme/tokens.nix
    # instead of each carrying its own copy.
    inherit (tokens) fonts;

    targets = {
      neovim.enable = true;
      zed.enable = true;
      kitty.enable = true;
      foot.enable = true;
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
      # so they follow the dither scheme.
      # adw-gtk3 skeleton + base16 gtk.css overlay: same 16 colors as everything
      # else, native GTK4/libadwaita, and flatpak theming. Replaces the manual
      # gtk theme (only the theme; iconTheme=papirus stays in home.nix).
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
      #   zellij   -> shells/zellij/zellij.nix writes its one `dither` theme
      #               directly from config.lib.stylix.colors.
      #   starship -> shells/starship/starship.nix derives its palette from
      #               config.lib.stylix.colors, so it follows the dither
      #               scheme without stylix's target needing to override it.
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

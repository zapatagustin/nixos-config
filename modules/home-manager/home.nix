{ config, pkgs, inputs, username, ... }:
{
  imports = [
    ./options.nix
    ./stylix.nix
    ./shells/shells.nix
    ./syncthing.nix
    ./terminals/terminals.nix
    ./editors/neovim
    ./editors/emacs
    ./editors/zed
    ./wm/hyprland
    ./ai
    ./dev
    # Claude Code + opencode config, from the ecomono flake. Replaces the local
    # ./claude-code and ./opencode modules, which were a second copy of it.
    inputs.ecomono.homeModules.default
    # Zen as a MODULE rather than a bare package in home.packages: stylix's
    # zen-browser target is gated on `options.programs ? zen-browser`, so with the
    # package alone it silently did nothing. homeModules.default is the beta channel,
    # which matches the `zen-beta` binary that was already installed.
    inputs.zen-browser.homeModules.default
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Migrated from bare packages to programs.* so stylix can theme them
  # (stylix.targets.{zathura,btop} in ./stylix.nix). btop came from
  # hosts/software/default_soft.nix; stylix's btop target is home-manager-only, so
  # the system package could never have been themed.
  programs.zathura.enable = true;
  programs.btop.enable = true;

  # stylix.cursor never applies because homeManagerIntegration.autoImport=false,
  # so set the pointer here directly: installs the theme to ~/.icons and sets
  # XCURSOR_THEME + hyprcursor env for Hyprland/GTK. package/name/size come from
  # ../theme/tokens.nix, the same values the system stylix.cursor reads — they used
  # to be two independent copies and the size had already drifted (24 vs 36).
  home.pointerCursor = (import ../theme/tokens.nix pkgs).cursor // {
    enable = true;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  # GTK theme (adw-gtk3 + base16 css) and font come from stylix.targets.gtk
  # (modules/home-manager/stylix.nix). Icons stay manual — stylix's gtk target
  # doesn't set an icon theme — so the variant has to follow the palette by hand.
  gtk = {
    enable = true;
    iconTheme = {
      package = pkgs.papirus-icon-theme;
      name = if config.stylix.polarity == "dark" then "Papirus-Dark" else "Papirus-Light";
    };
  };

  # THE cross-toolkit theme signal. Everything that "follows the system theme"
  # — browsers, libadwaita/GTK4, Qt6, Electron — asks the XDG desktop portal for
  # org.freedesktop.appearance/color-scheme rather than reading our gtk.css.
  #
  # The chain, verified live on this host:
  #   dconf write  ->  xdg-desktop-portal-gtk watches this GSettings key
  #                ->  emits org.freedesktop.portal.Settings.SettingChanged
  #                ->  subscribed apps repaint, no restart
  # That signal is exactly what makes a KDE theme switch look instant; we already
  # had every piece of it running (xdg-desktop-portal-gtk.service is the only
  # backend that implements impl.portal.Settings — the hyprland backend declares
  # only Screenshot/ScreenCast/GlobalShortcuts/InputCapture, and cannot implement
  # Settings because Hyprland has no appearance state to publish). The key was
  # simply hardcoded to prefer-dark, so `set-theme light` left every portal-aware
  # app dark and the desktop disagreed with itself.
  #
  # "prefer-light", NOT stylix's own targets.gnome value of "default": default
  # means "no preference" and lets each app fall back to its own, which is dark
  # for a good number of them. (That target is also unusable here for a second
  # reason — it writes org/gnome/desktop/background from stylix.image, which is a
  # 1x1 pixel in this config, and would fight hyprpaper.)
  dconf.settings."org/gnome/desktop/interface".color-scheme =
    if config.stylix.polarity == "dark" then "prefer-dark" else "prefer-light";

  # Qt apps (zapzap is PyQt6) via Qt's own GTK3 platform theme: they read the GTK
  # colours, font and icon theme we already generate, so they follow the palette
  # with zero extra state to keep in sync.
  #
  # Deliberately NOT stylix.targets.qt: it drives qt6ct + a Kvantum theme BUILT
  # from the base16 palette, i.e. a store path that differs per palette. That
  # breaks flake.nix's theme-invariants check ("home-path must be identical, no
  # package differs by palette"), and with it the reasoning that a theme switch is
  # only a relink. platformTheme "gtk3" adds no package at all — the plugin
  # (libqgtk3.so) already ships inside qtbase; this only sets QT_QPA_PLATFORMTHEME.
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };

  # `path` is what decides which directory on disk the profile is, and it must keep
  # pointing at the one that already holds the history, extensions and logins --
  # `qu5xpc4r.Default Profile`, read out of ~/.config/zen/profiles.ini. The attribute
  # name is only a label, so it stays readable instead of carrying that random salt.
  #
  # This module is home-manager's own mkFirefoxModule underneath, which means it
  # takes ownership of ~/.config/zen/profiles.ini and replaces it with a store
  # symlink as soon as `profiles` is non-empty. That rewrites the `Name=` field
  # (cosmetic; zen resolves the profile by Path) and makes the file read-only, which
  # is the one thing to watch if zen ever wants to rewrite it itself.
  #
  # FIRST ACTIVATION AFTER THIS LANDS WILL FAIL unless the existing profiles.ini is
  # moved aside: it is a real file, and home-manager's checkLinkTargets refuses to
  # clobber anything it does not already own. The generated one is equivalent --
  # same Path, same Default=1, same IsRelative=1, same Version=2 -- so
  # `mv ~/.config/zen/profiles.ini{,.bak}` with zen closed is the whole migration.
  programs.zen-browser = {
    enable = true;
    profiles.default = {
      path = "qu5xpc4r.Default Profile";
      # SearXNG runs on the desktop (CachyOS, github:zapatagustin/cachy-config
      # -- a rootless podman quadlet set up imperatively there, same as
      # syncthing). It publishes on the tailnet address only, so this is
      # reachable from any network but never from the LAN or the internet.
      search = {
        # search.json.mozlz4 already exists in the profile; without force,
        # home-manager refuses to overwrite it and the default never applies.
        force = true;
        default = "searxng";
        privateDefault = "searxng";
        engines.searxng = {
          name = "SearXNG";
          urls = [{
            template = "http://desktop.taild4c79d.ts.net:8888/search";
            params = [{ name = "q"; value = "{searchTerms}"; }];
          }];
          iconMapObj."16" = "http://desktop.taild4c79d.ts.net:8888/favicon.ico";
          definedAliases = [ "@sx" ];
        };
      };
    };
  };

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    brave-origin # was a local pkgs/brave-origin.nix repack; nixpkgs carries it now
    # zen -> programs.zen-browser below, so stylix.targets.zen-browser can theme it.
    # Zed lives in ./editors/zed now (programs.zed-editor + stylix + sops wrapper).
    sone
    claude-code
    zapzap
    slack
    teams-for-linux
    pavucontrol
    discord
    thunderbird-latest-bin
    keepassxc # vault synced from the desktop's kdbx via syncthing
    feishin
    superfile
    moonlight-qt # game streaming client for the desktop's sunshine host
    # YouTube client from its own flake; ships its .desktop entry, so it shows
    # up in the launcher. Update: `nix flake update mono_player` + rebuild.
    inputs.mono_player.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}

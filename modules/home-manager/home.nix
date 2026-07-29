{ pkgs, inputs, username, ... }:
{
  imports = [
    ./options.nix
    ./stylix.nix
    ./shells/shells.nix
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
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  programs.home-manager.enable = true;

  # Migrated from bare packages to programs.* so stylix can theme them
  # (stylix.targets.{zathura,yazi} in ./stylix.nix).
  programs.zathura.enable = true;
  programs.yazi.enable = true;

  # stylix.cursor never applies because homeManagerIntegration.autoImport=false,
  # so set the pointer here directly: installs the theme to ~/.icons and sets
  # XCURSOR_THEME + hyprcursor env for Hyprland/GTK. Mirrors stylix.cursor.
  home.pointerCursor = {
    enable = true;
    package = pkgs.capitaine-cursors-themed;
    name = "Capitaine Cursors (Gruvbox)";
    size = 36;
    gtk.enable = true;
    hyprcursor.enable = true;
  };

  # GTK theme (adw-gtk3 + base16 css) and font come from stylix.targets.gtk
  # (modules/home-manager/stylix.nix). Icons stay manual — stylix's gtk target
  # doesn't set an icon theme.
  gtk = {
    enable = true;
    iconTheme = { package = pkgs.papirus-icon-theme; name = "Papirus-Dark"; };
  };

  # Make the XDG desktop portal report a dark color-scheme: libadwaita/GTK4 apps
  # and browsers (prefers-color-scheme) then go dark. Browsers won't be *gruvbox*
  # (that needs a browser theme), just dark.
  dconf.settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    (callPackage ../../pkgs/brave-origin.nix { }) # Brave Origin (not in nixpkgs); see pkgs/brave-origin.nix
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    nnn
    # Zed lives in ./editors/zed now (programs.zed-editor + stylix + sops wrapper).
    sone
    calibre
    claude-code
    zapzap
    slack
    teams-for-linux
    pavucontrol
    superfile
    # stremio removed from nixpkgs (qt5 webengine dep); use flatpak
    # stremio
  ];
}

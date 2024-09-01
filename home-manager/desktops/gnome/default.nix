{ lib, pkgs, config, ... }:
let
  gnomeExtensionsList = with pkgs.gnomeExtensions; [
    appindicator
    arcmenu
    dash-to-dock
    desktop-icons-ng-ding
    fly-pie
    hide-activities-button
    pop-shell
    top-bar-organizer
    vitals
    window-title-is-back
  ];

  gnomeshellTheme = "${config.thinkpad.theme-components.gtk-theme}";
  backgroundTheme = "${config.thinkpad.theme-components.background}";

  fontList = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "NerdFontsSymbolsOnly" ]; })
  ];
in {
  config = lib.mkIf (config.thinkpad.desktopManager == "gnome") {
    # ---- System Configuration ----
    services = {
      udev.packages = with pkgs; [ gnome.gnome-settings-daemon ];
      xserver = {
        enable = true;
        desktopManager.gnome.enable = true;
      };

      gnome = {
        evolution-data-server.enable = true;
        gnome-keyring.enable = true;
      };
    };

    programs.dconf.enable = true;
    gtk.iconCache.enable = true;

    environment = {
      pathsToLink = [ "/share/backgrounds" ];
      systemPackages = with pkgs; [ eog gnome-tweaks gnome-screenshot ];
      gnome.excludePackages = (with pkgs; [
        atomix
        epiphany
        evince
        geary
        gnome-characters
        gnome-music
        gnome-photos
        gnome-tour
        hitori
        iagno
        tali
        totem
        ]);
    };

    # ---- Home Configuration ----

    home-manager.users.${config.thinkpad.homeManagerUser} = { pkgs, ...}: {
      home.packages = gnomeExtensionsList ++ fontList;
      dconf.settings = {
        "org/gnome/shell/extensions/user-theme" = {
          name = gnomeshellTheme;
        };
      };

      # It copies "./config/menus/gnome-applications.menu" source file to the nix store, and then symlinks it to the location.
      xdg.configFile."menus/applications-merged/gnome-applications.menu".source = ./config/menus/applications-merged/gnome-applications.menu;

      dconf.settings = {
        "org/gnome/shell".disable-user-extensions = false;
        "org/gnome/shell".enabled-extensions = (map (extension: extension.extensionUuid) gnomeExtensionsList)
        ++ [
          "appindicatorsupport@rgcjonas.gmail.com"
          "arcmenu@arcmenu.com"
          "dash-to-dock@micxgx.gmail.com"
          "ding@rastersoft.com"
          "flypie@schneegans.github.com"
          "Hide_Activities@shay.shayel.org"
          "pop-shell@system76.com"
          "top-bar-organizer@julian.gse.jsts.xyz"
          "Vitals@CoreCoding.com"
          "user-theme@gnome-shell-extensions.gcampax.github.com"
          "window-title-is-back@fthx"
        ];

        "org/gnome/shell".disabled-extensions = [
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
          "places-menu@gnome-shell-extensions.gcampax.github.com"
          "apps-menu@gnome-shell-extensions.gcampax.github.com"
        ];
        
        # /desktop/applications/terminal
        "org/gnome/desktop/applications/terminal" = {
          exec = "${config.thinkpad.terminal}";
        };

        # /desktop/interface
        "org/gnome/desktop/interface" = {
          document-font-name = "JetBrainsMono Nerd Font Mono 11";
          enable-hot-corners = false;
          font-antialiasing = "grayscale";
          font-hinting = "slight";
          monospace-font-name = "JetBrainsMono Nerd Font Mono 11";
          font-name = "JetBrainsMono Nerd Font Mono 11";
          color-scheme = "prefer-dark";
        };

        # /desktop/wm/keybindings
        "org/gnome/desktop/wm/keybindings" = {
          show-desktop = ["<Super>D"];
          toggle-message-tray = "disabled";
          close = ["<Super>w"];
          maximize = "disabled";
          minimize = "disabled";
          move-to-monitor-down = "disabled";
          move-to-monitor-left = "disabled";
          move-to-monitor-right = "disabled";
          move-to-monitor-up = "disabled";
          move-to-workspace-down = "disabled";
          move-to-workspace-up = "disabled";
          move-to-corner-nw = "disabled";
          move-to-corner-ne = "disabled";
          move-to-corner-sw = "disabled";
          move-to-corner-se = "disabled";
          move-to-side-n = "disabled";
          move-to-side-s = "disabled";
          move-to-side-e = "disabled";
          move-to-side-w = "disabled";
          move-to-center = "disabled";
          toggle-maximized = "disabled";
          unmaximize = "disabled";
        };

        # /desktop/wm/preferences
        "org/gnome/desktop/wm/preferences" = {
          action-middle-click-titlebar = "none";
          button-layout = "appmenu:minimize,maximize,close";
          num-workspaces = 6;
          resize-with-right-button = true;
          titlebar-font = "JetBrains Mono Bold 11";
          workspace-names = ["🕵️" "📖" "🍒" "🎸" "🎮" "🐝"];
        };

        # Keybindings
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          ];
          home = ["<Super>E"];
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          binding = "<Super>L";
          command = "dm-tool lock";
          name = "Lock Screen";
        };

        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          binding = "<CTRL><ALT>T";
          command = "kitty";
          name = "Terminal";
        };

        "org/gnome/mutter" = {   
          dynamic-workspaces = false;
        };

        # Configure Extensions
        "org/gnome/shell/extensions/Logo-menu" = {
          menu-button-icon-click-type = 2;
          menu-button-icon-image = 6;
          menu-button-icon-size = 25;
          show-power-options = false;
        };

        "org/gnome/shell/extensions/arcmenu" = {
          arc-menu-icon=69;
          dash-to-panel-standalone = false;
          directory-shortcuts-list = [["Home" "user-home-symbolic" "ArcMenu_Home"] ["Documents" ". GThemedIcon folder-documents-symbolic folder-symbolic folder-documents folder" "ArcMenu_Documents"] ["Downloads" ". GThemedIcon folder-download-symbolic folder-symbolic folder-download folder" "ArcMenu_Downloads"] ["Music" ". GThemedIcon folder-music-symbolic folder-symbolic folder-music folder" "ArcMenu_Music"] ["Pictures" ". GThemedIcon folder-pictures-symbolic folder-symbolic folder-pictures folder" "ArcMenu_Pictures"] ["Videos" ". GThemedIcon folder-videos-symbolic folder-symbolic folder-videos folder" "ArcMenu_Videos"]];
          menu-background-color = "rgba(48,48,49,0.98)";
          menu-border-color = "rgb(60,60,60)";
          menu-button-appearance = "Icon";
          menu-foreground-color = "rgb(223,223,223)";
          menu-item-active-bg-color = "rgb(25,98,163)";
          menu-item-active-fg-color = "rgb(255,255,255)";
          menu-item-hover-bg-color = "rgb(21,83,158)";
          menu-item-hover-fg-color = "rgb(255,255,255)";
          menu-layout = "Whisker";
          menu-separator-color = "rgba(255,255,255,0.1)";
          multi-monitor = false;
          #pop-folders-data = { "Library Home" = "Library Home"; "Utilities" = "Utilities"; };
          prefs-visible-page = 0;
          recently-installed-apps = ["alacarte-made.desktop" "ettercap.desktop" "guymager.desktop" "autopsy.desktop" "jshell-java11-openjdk.desktop" "jconsole-java11-openjdk.desktop" "minicom.desktop" "org.codeberg.dnkl.footclient.desktop" "nm-connection-editor.desktop" "org.codeberg.dnkl.foot.desktop" "org.codeberg.dnkl.foot-server.desktop" "linguist.desktop" "yad-icon-browser.desktop" "org.kde.klipper.desktop" "yad-settings.desktop" "assistant.desktop" "qdbusviewer.desktop" "designer.desktop" "org.kde.kuserfeedback-console.desktop" "jshell-java17-openjdk.desktop" "jconsole-java17-openjdk.desktop" "thunar-settings.desktop" "thunar.desktop" "kdesystemsettings.desktop" "org.kde.discover.desktop"];
          show-category-sub-menus = true;
        };

        "org/gnome/shell/extensions/dash-to-dock" = {
          apply-custom-theme = true;
          autohide-in-fullscreen = false;
          background-opacity = 0.9;
          custom-theme-shrink = true;
          dash-max-icon-size = 48;
          dock-position = "BOTTOM";
          height-fraction = 0.9;
          intellihide = true;
          intellihide-mode = "FOCUS_APPLICATION_WINDOWS";
          multi-monitor = true;
          preferred-monitor = -2;
          preferred-monitor-by-connector = "Virtual-1";
          preview-size-scale = 0.2;
          require-pressure-to-show = false;
          show-trash = false;
          transparency-mode = "FIXED";
        };

        "org/gnome/shell/extensions/ding" = {
          check-x11wayland = true;
        };

        "org/gnome/shell/extensions/pop-shell" = {
          show-skip-taskbar = false;
        };

        "org/gnome/shell/extensions/top-bar-organizer" = {
          center-box-order = ["Workspace Indicator" "media-player" "Space Bar" "media-player-controls"];
          left-box-order = ["LogoMenu" "ArcMenu" "menuButton" "appMenu" "Notifications" "places-menu" "apps-menu" "dateMenu" "activities"];
          right-box-order = ["dash-button" "power-menu" "battery-bar" "vitalsMenu" "pop-shell" "screenRecording" "screenSharing" "dwellClick" "a11y" "keyboard" "quickSettings"];
        };

        "org/gnome/shell/extensions/window-title-is-back" = {
          colored-icon = true;
          show-title = false;
        };

        "org/gnome/shell/extensions/flypie" = {
          active-stack-child = "menu-editor-page";
          center-background-image = "";
          center-background-image-hover = "";
          center-icon-crop = 1.0;
          center-icon-crop-hover = 1.0;
          center-icon-scale = 0.55000000000000004;
          center-size = 109.0;
          child-background-image = "";
          child-background-image-hover = "";
          child-color-mode = "fixed";
          child-color-mode-hover = "auto";
          child-icon-crop = 1.0;
          child-icon-crop-hover = 1.0;
          child-offset = 106.0;
          child-size = 63.0;
          global-scale = 1.6000000000000001;
          grandchild-background-image = "";
          grandchild-background-image-hover = "";
          trace-color = "rgba(51,0,79,0)";
        };
      };
    };
  };
}

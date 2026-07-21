{ pkgs, lib, config, ... }:
let
  mm = config.myDesktop.multiMonitor.enable;
  iscale = toString config.myDesktop.internalScale; # eDP-1 fractional scale (per host)
  walls = ../../../../wallpapers; # repo-root/wallpapers (only the used images, ~1.7MB)

  # monitor-watcher is the only monitor script behind a systemd unit, so it's the only
  # one that needs its deps declared (the rest live in ~/.config/hypr and use the session
  # PATH). runtimeInputs also covers setup-monitors.sh, which the watcher spawns.
  monitorWatcher = pkgs.writeShellApplication {
    name = "monitor-watcher";
    runtimeInputs = with pkgs; [ socat systemd hyprland hyprpaper jq procps coreutils bash gawk ];
    bashOptions = [ "nounset" ]; # match the script's original `set -u`; errexit would abort best-effort hyprctl/kill calls
    text = builtins.readFile ./scripts/monitor-watcher.sh;
  };

  # TV 4K HDR toggle (Super+Shift+T). Invoked by store path from the bind, gated by `mm`.
  tvScale = pkgs.writeShellApplication {
    name = "tv-scale";
    runtimeInputs = with pkgs; [ hyprland coreutils gnugrep gawk ];
    bashOptions = [ "nounset" ]; # script uses `set -u`
    text = builtins.readFile ./scripts/tv-scale.sh;
  };
  # Brightness keys: internal backlight always, external DDC monitors only when
  # multiMonitor (dock) is enabled — ddcutil is only pulled in then, so on the
  # nomad host `command -v ddcutil` fails and the script stays internal-only.
  brightnessScript = pkgs.writeShellApplication {
    name = "brightness";
    runtimeInputs = with pkgs; [ brightnessctl coreutils gnugrep util-linux ]
      ++ lib.optional mm ddcutil;
    bashOptions = [ "nounset" ]; # script uses `set -u`; errexit would abort best-effort ddcutil calls
    text = builtins.readFile ./scripts/brightness.sh;
  };

  # Audio device watcher: notifies when sinks/sources change (USB headset, HDMI, etc.)
  audioDeviceWatcher = pkgs.writeShellApplication {
    name = "audio-device-watcher";
    runtimeInputs = with pkgs; [ coreutils libnotify ];
    bashOptions = [ "nounset" ]; # script uses `set -u`
    text = builtins.readFile ./scripts/audio-device-watcher.sh;
  };

  # hyprpaper 0.8.4 ignores config-file `wallpaper=`/`preload=` (hyprtoolkit-rewrite
  # regression: logs "Monitor eDP-1 has no target" at every startup, sets nothing).
  # Only the IPC path works, so apply the built-in-display wallpaper via
  # `hyprctl hyprpaper wallpaper` once the daemon's IPC socket is up. External monitors
  # are applied separately by setup-monitors.sh (also over IPC).
  setEdpWallpaper = pkgs.writeShellScript "hyprpaper-set-edp" ''
    for _ in $(seq 1 20); do
      ${pkgs.hyprland}/bin/hyprctl hyprpaper listactive >/dev/null 2>&1 && break
      sleep 0.3
    done
    ${pkgs.hyprland}/bin/hyprctl hyprpaper wallpaper "eDP-1,${walls}/keyboard.jpg"
  '';

  ws = builtins.genList (i: toString (i + 1)) 9; # ["1".."9"]
  # workspace binds call scripts via `bash` so no exec-bit needed on store files
  mkWsBinds = mod: script: map (n: "${mod}, ${n}, exec, bash ~/.config/hypr/${script} ${n}") ws;
in
{
  home.packages = with pkgs; [
    # session/wm tools used by binds, scripts and quickshell (must be on PATH)
    uwsm
    quickshell
    hyprpolkitagent # hyprpaper/hyprlock installed by their HM modules below
    cliphist
    wl-clipboard
    grim
    slurp
    brightnessctl
    playerctl
    jq
    socat
    libnotify
    kitty
    # yazi -> programs.yazi (home.nix), so stylix.targets.yazi themes it
    satty # screenshot annotation (screenshot.sh edit)
    # gruvbox-gtk-theme dropped: GTK now themed by stylix.targets.gtk
    papirus-icon-theme
    noto-fonts-cjk-sans # hyprlock clock font (Noto Sans JP)
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # uwsm manages the session (programs.hyprland.withUWSM at system level)
    systemd.enable = false;
    # stateVersion 26.05 flips the HM default to configType="lua", whose generator
    # emits invalid Lua for hyprlang-style keys ($mainMod, exec-once) -> Hyprland
    # falls back to emergency mode. Our settings are hyprlang; pin the format.
    configType = "hyprlang";

    settings = {
      "$mainMod" = "SUPER";
      "$terminal" = "kitty";

      env = [
        "WALLPAPER_DIR,${walls}"
        "EDP_SCALE,${iscale}" # setup-monitors.sh reuses the per-host eDP scale on dock
      ];

      monitor = [
        "eDP-1,preferred,auto,${iscale}" # scale per host (myDesktop.internalScale); externals via setup-monitors.sh
        ",preferred,auto,auto" # fallback for unknown monitors
      ] ++ lib.optional mm
        "HDMI-A-1,3840x2160@60,0x0,2,bitdepth,10,cm,wide"; # TV 4K: 10-bit + wide gamut (SDR desktop); tv-scale toggles game/HDR

      general = {
        gaps_in = 3;
        gaps_out = 6;
        border_size = 1;
        "col.active_border" = "rgba(d79921ff) rgba(fe8019ff) 45deg";
        "col.inactive_border" = "rgba(3c3836ff)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      decoration = {
        rounding = 0;
        active_opacity = 1.0;
        inactive_opacity = 1.0;
        shadow.enabled = false;
        blur.enabled = false;
      };

      animations.enabled = false; # cachy disabled them ("enabled = no, please :)")

      master.new_status = "master";

      # HW cursor plane renders at a fixed size and ignores per-monitor scale, so
      # the pointer looks a different size on the fractional-scaled eDP (1.57) vs
      # the scale-1 externals. Software cursors rescale correctly per output.
      cursor.no_hardware_cursors = true;

      misc = {
        force_default_wallpaper = 1;
        disable_hyprland_logo = true;
        vrr = 1; # adaptive sync (free win on panels that support it)
      };

      render.direct_scanout = true; # bypass compositing on fullscreen surfaces (perf; lost in the cachy port)

      input = {
        kb_layout = "es,us";
        kb_variant = ",dvorak";
        kb_options = "grp:ctrl_alt_toggle";
        follow_mouse = 1;
        sensitivity = 0;
        touchpad = {
          disable_while_typing = true;
          natural_scroll = true;
          tap-to-click = true;
        };
      };

      gesture = "4, horizontal, workspace";
      binds.allow_workspace_cycles = true;

      exec-once = [
        "uwsm finalize HYPRLAND_INSTANCE_SIGNATURE"
        "systemctl --user start hyprpolkitagent"
        "wl-paste --type text --watch cliphist store"
        "wl-paste --type image --watch cliphist store"
        "echo dark > /tmp/qs-theme" # Stylix is fixed-dark; tell quickshell
      ] ++ lib.optional mm "bash ~/.config/hypr/setup-monitors.sh";

      bind = [
        # apps
        "$mainMod, RETURN, exec, uwsm app -- $terminal"
        "$mainMod, C, killactive,"
        "$mainMod, Space, togglefloating,"
        "$mainMod, F, fullscreen"
        "$mainMod, D, exec, echo toggle >> /tmp/qs-launcher"
        "ALT, Tab, cyclenext,"
        "ALT, Tab, bringactivetotop,"
        "SUPER SHIFT, L, exec, loginctl lock-session"
        "SUPER, P, exec, echo toggle >> /tmp/qs-clipboard"
        "SUPER SHIFT, P, exec, echo toggle >> /tmp/qs-clipboard"
        "SUPER SHIFT, N, exec, echo toggle >> /tmp/qs-notif"
        # screenshots (via bash → no exec-bit needed)
        ", Print, exec, bash ~/.config/hypr/screenshot.sh region"
        "SHIFT, Print, exec, bash ~/.config/hypr/screenshot.sh window"
        "CTRL, Print, exec, bash ~/.config/hypr/screenshot.sh output"
        "SUPER, Print, exec, bash ~/.config/hypr/screenshot.sh screen"
        "$mainMod SHIFT, S, exec, bash ~/.config/hypr/screenshot.sh edit"
        # focus (vim + arrows)
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"
        "$mainMod, left, movefocus, l"
        "$mainMod, right, movefocus, r"
        "$mainMod, up, movefocus, u"
        "$mainMod, down, movefocus, d"
        # move window (vim + arrows)
        "$mainMod SHIFT, h, movewindow, l"
        "$mainMod SHIFT, l, movewindow, r"
        "$mainMod SHIFT, k, movewindow, u"
        "$mainMod SHIFT, j, movewindow, d"
        "$mainMod SHIFT, left, movewindow, l"
        "$mainMod SHIFT, right, movewindow, r"
        "$mainMod SHIFT, up, movewindow, u"
        "$mainMod SHIFT, down, movewindow, d"
        # scroll workspaces
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ]
      ++ mkWsBinds "$mainMod" "switch-monitor.sh"
      ++ mkWsBinds "ALT" "switch-group.sh"
      ++ mkWsBinds "$mainMod SHIFT" "move-to-group.sh"
      ++ mkWsBinds "ALT SHIFT" "move-all-to-group.sh"
      ++ lib.optional mm "$mainMod SHIFT, T, exec, ${tvScale}/bin/tv-scale";

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && echo . >> /tmp/qs-volume"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && echo . >> /tmp/qs-volume"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && echo . >> /tmp/qs-volume"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, ${brightnessScript}/bin/brightness up"
        ",XF86MonBrightnessDown, exec, ${brightnessScript}/bin/brightness down"
      ];

      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];
    };

    # rules.conf uses the new structured windowrule{} block syntax — not a clean
    # attr mapping, kept verbatim.
    extraConfig = ''
      windowrule {
          name = suppress-maximize-events
          match:class = .*
          suppress_event = maximize
      }
      windowrule {
          name = fix-xwayland-drags
          match:class = ^$
          match:title = ^$
          match:xwayland = true
          match:float = true
          match:fullscreen = false
          match:pin = false
          no_focus = true
      }
      windowrule {
          name = move-hyprland-run
          match:class = hyprland-run
          move = 20 monitor_h-120
          float = yes
      }
    '';
  };

  # hyprpaper: built-in display here; external monitors set at runtime by setup-monitors.sh.
  # NOTE: `wallpaper=` below is dead on hyprpaper 0.8.4 (config-file wallpapers are
  # ignored — see setEdpWallpaper); it stays as documented intent. The eDP wallpaper is
  # actually applied by the ExecStartPost IPC call wired below.
  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      ipc = "on";
      wallpaper = [ "eDP-1,${walls}/keyboard.jpg" ];
    };
  };
  systemd.user.services.hyprpaper.Service.ExecStartPost = "${setEdpWallpaper}";

  # idle management. On NixOS the lock works because hyprlock has a PAM entry
  # (modules/wm/hyprland.nix). lock_cmd guards against double-launch.
  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        { timeout = 240; on-timeout = "brightnessctl -s set 20%"; on-resume = "brightnessctl -r"; }
        { timeout = 300; on-timeout = "loginctl lock-session"; on-resume = "hyprctl dispatch dpms on"; }
        { timeout = 360; on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on"; }
        { timeout = 900; on-timeout = "systemctl suspend"; }
      ];
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        hide_cursor = true;
        grace = 0;
        no_fade_in = false;
      };
      background = [{
        monitor = "";
        path = "${walls}/3.png";
        blur_passes = 2;
        blur_size = 4;
        brightness = 0.6;
        contrast = 0.9;
        vibrancy = 0.2;
      }];
      label = [
        {
          monitor = "";
          text = ''cmd[update:1000] echo "<b>$(date +"%H:%M")</b>"'';
          color = "rgba(235, 219, 178, 0.95)";
          font_size = 96;
          font_family = "Noto Sans JP Bold";
          position = "0, 120";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = ''cmd[update:60000] echo "$(date +"%A, %d de %B de %Y" | sed 's/\b./\u&/g')"'';
          color = "rgba(168, 153, 132, 0.90)";
          font_size = 22;
          font_family = "Noto Sans JP";
          position = "0, 30";
          halign = "center";
          valign = "center";
        }
        {
          monitor = "";
          text = "Ingresá tu contraseña para desbloquear";
          color = "rgba(168, 153, 132, 0.70)";
          font_size = 13;
          font_family = "Noto Sans JP";
          position = "0, -155";
          halign = "center";
          valign = "center";
        }
      ];
      # input-field colors come from stylix.targets.hyprlock (base16)
      "input-field" = [{
        monitor = "";
        size = "280, 42";
        placeholder_text = ''<span foreground="##a89984">contraseña...</span>'';
        hide_input = false;
        dots_size = 0.30;
        dots_spacing = 0.20;
        dots_center = true;
        fade_on_empty = true;
        position = "0, -100";
        halign = "center";
        valign = "center";
        rounding = 6;
      }];
    };
  };

  # systemd user services (replace the cachy /usr/bin units)
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.quickshell}/bin/quickshell -p %h/.config/quickshell/bar";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.monitor-watcher = lib.mkIf mm {
    Unit = {
      Description = "Hyprland monitor hotplug watcher";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${monitorWatcher}/bin/monitor-watcher";
      # WALLPAPER_DIR is consumed by setup-monitors.sh, which the watcher spawns on
      # hotplug. A systemd user service does not inherit Hyprland's `env` (uwsm finalize
      # only exports HYPRLAND_INSTANCE_SIGNATURE), so set it here. PATH is no longer set
      # manually — runtimeInputs handles it.
      Environment = [ "WALLPAPER_DIR=${walls}" "EDP_SCALE=${iscale}" ];
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.audio-device-watcher = {
    Unit = {
      Description = "PipeWire audio device hotplug watcher";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" "pipewire.service" "wireplumber.service" ];
      BindsTo = [ "pipewire.service" ];
    };
    Service = {
      ExecStart = "${audioDeviceWatcher}/bin/audio-device-watcher";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # scripts deployed individually so they coexist with the generated hyprland.conf
  xdg.configFile = {
    "hypr/monitors-detect.sh".source = ./scripts/monitors-detect.sh;
    "hypr/switch-monitor.sh".source = ./scripts/switch-monitor.sh;
    "hypr/switch-group.sh".source = ./scripts/switch-group.sh;
    "hypr/move-to-group.sh".source = ./scripts/move-to-group.sh;
    "hypr/move-all-to-group.sh".source = ./scripts/move-all-to-group.sh;
    "hypr/screenshot.sh".source = ./scripts/screenshot.sh;
    "quickshell".source = ./quickshell;
  } // lib.optionalAttrs mm {
    "hypr/setup-monitors.sh".source = ./scripts/setup-monitors.sh;
  };
}

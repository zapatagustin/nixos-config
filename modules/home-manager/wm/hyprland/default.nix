{ pkgs, lib, config, ... }:
let
  mm = config.myDesktop.multiMonitor.enable;
  iscale = toString config.myDesktop.internalScale; # eDP-1 fractional scale (per host)
  bexp = toString config.myDesktop.brightnessExponent; # perceptual brightness gamma (per host)
  # repo-root/wallpapers, copied whole into the store. Every image here is
  # referenced by exact filename (below, and setup-monitors.sh) -- nothing picks one
  # dynamically, so an unreferenced file is dead bytes in the closure. Four of them
  # were, ~1.7MB; the remaining four are ~12MB, mostly View_of_Vent (8.4MB).
  walls = ../../../../wallpapers;

  # monitor-watcher is the only monitor script behind a systemd unit, so it's the only
  # one that needs its deps declared (the rest live in ~/.config/hypr and use the session
  # PATH). runtimeInputs also covers setup-monitors.sh, which the watcher spawns.
  monitorWatcher = pkgs.writeShellApplication {
    name = "monitor-watcher";
    # brightnessScript: run_setup calls `brightness sync` to repair the externals'
    # DDC value after a dock change or a reload re-inits the link.
    runtimeInputs = with pkgs; [ socat systemd hyprland hyprpaper jq procps coreutils bash gawk ]
      ++ [ brightnessScript ];
    bashOptions = [ "nounset" ]; # match the script's original `set -u`; errexit would abort best-effort hyprctl/kill calls
    text = builtins.readFile ./scripts/monitor-watcher.sh;
  };

  # Brightness keys: internal backlight always, external DDC monitors only when
  # multiMonitor (dock) is enabled — ddcutil is only pulled in then, so on the
  # nomad host `command -v ddcutil` fails and the script stays internal-only.
  brightnessScript = pkgs.writeShellApplication {
    name = "brightness";
    runtimeInputs = with pkgs; [ brightnessctl coreutils gnugrep util-linux ]
      ++ lib.optional mm ddcutil;
    bashOptions = [ "nounset" ]; # script uses `set -u`; errexit would abort best-effort ddcutil calls
    # EXPONENT is prepended rather than living in the script, so the perceptual
    # gamma has ONE definition (myDesktop.brightnessExponent) instead of a copy per
    # consumer. The script's own `#!/usr/bin/env bash` ends up below
    # writeShellApplication's shebang and is inert there, same as every other
    # script wrapped this way in this file.
    text = "readonly EXPONENT=${bexp}\n" + builtins.readFile ./scripts/brightness.sh;
  };

  # System-wide gruvbox dark/light switch. Wrapped rather than deployed into
  # ~/.config/hypr because the systemd timers below invoke it and a user unit does
  # not inherit the session PATH — it needs systemd/procps/coreutils declared. It
  # sources nothing, so it has no reason to sit flat next to the other scripts.
  # Also on home.packages so the bar can call it by name.
  setTheme = pkgs.writeShellApplication {
    name = "set-theme";
    runtimeInputs = with pkgs; [ systemd coreutils gnugrep procps hyprland util-linux libnotify jq ];
    bashOptions = [ "nounset" ]; # script uses `set -u`; errexit would abort the best-effort kitty/hyprctl pokes
    text = builtins.readFile ./scripts/set-theme.sh;
  };

  # Idle/sleep inhibitor toggle. Wrapped rather than left to the session PATH for
  # the same reason as set-theme: the bar calls it through a fixed-path shim and
  # execDetached fails silently when a bare name does not resolve. Also on
  # home.packages so `caffeine` works from a terminal.
  caffeine = pkgs.writeShellApplication {
    name = "caffeine";
    runtimeInputs = with pkgs; [ systemd coreutils libnotify ];
    bashOptions = [ "nounset" ]; # script uses `set -u`; errexit would abort the best-effort notify-send calls
    text = builtins.readFile ./scripts/caffeine.sh;
  };

  # Audio device watcher: notifies when sinks/sources change (USB headset, HDMI, etc.)
  audioDeviceWatcher = pkgs.writeShellApplication {
    name = "audio-device-watcher";
    runtimeInputs = with pkgs; [ coreutils libnotify ];
    bashOptions = [ "nounset" ]; # script uses `set -u`
    text = builtins.readFile ./scripts/audio-device-watcher.sh;
  };

  # `hl.dsp.dpms` with a non-table argument silently means TOGGLE — see
  # tableToggleAction in Hyprland's src/config/lua/bindings/LuaBindingsInternal.cpp, which
  # returns TOGGLE_ACTION_TOGGLE when arg 1 is not a table. So `hl.dsp.dpms("on")` parses,
  # answers `ok`, and does the wrong thing; the state has to go in `{ action = ... }`.
  dpms = state: "hyprctl dispatch 'hl.dsp.dpms({ action = \"${state}\" })'";

  # Re-assert the current brightness on the external DDC monitors. They drop back to
  # their OSD default (100%) every time the link is re-initialised and nothing used
  # to restore it, so the laptop panel and the externals drifted apart on every idle
  # timeout. See the `sync` case in scripts/brightness.sh for the measurements.
  ddcSync = "${brightnessScript}/bin/brightness sync";

  # Everything that brings the outputs back: turn them on, then repair the
  # brightness. Chained in one string rather than spread across hypridle entries
  # because hypridle guarantees no order between listeners, and the sync has to
  # happen after the panels are awake.
  wakeUp = "${dpms "on"}; ${ddcSync}";

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
    setTheme # gruvbox dark/light switch; the bar's theme toggle calls it by name
    caffeine # idle/suspend inhibitor toggle; the bar's coffee icon calls it too
    jq
    socat
    libnotify
    # kitty -> programs.kitty (terminals/kitty/kitty.nix), which installs it and lets
    # stylix.targets.kitty theme it. Listing it here as well was a second path to the
    # same package.
    satty # screenshot annotation (screenshot.sh edit)
    # gruvbox-gtk-theme dropped: GTK now themed by stylix.targets.gtk
    papirus-icon-theme
    noto-fonts-cjk-sans # hyprlock clock font (Noto Sans JP)
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    # uwsm manages the session (programs.hyprland.withUWSM at system level)
    systemd.enable = false;
    # hyprlang is deprecated since 0.55 and upstream drops it "after 1 - 2 releases"
    # (hypr.land/news/26_lua), so the config is Lua now.
    # Kept as one raw Lua block rather than `settings`: binds take `hl.dsp.*`
    # dispatcher objects, which the HM attrset -> Lua generator can only emit as
    # quoted strings. Validate edits with `Hyprland --verify-config -c <file>`.
    #
    # A Lua config also switches the IPC parser, so every external caller had to move too:
    # `hyprctl dispatch <hyprlang>` now parses its argument as Lua, and `hyprctl keyword`
    # is refused outright ("keyword can't work with non-legacy parsers. Use eval.").
    # The map used across scripts/ and quickshell/ (verified against Hyprland 0.56.1
    # src/config/lua/bindings/LuaBindingsDispatchers.cpp):
    #
    #   dispatch workspace N               -> dispatch hl.dsp.focus({ workspace = N })
    #   dispatch focusmonitor M            -> dispatch hl.dsp.focus({ monitor = "M" })
    #   dispatch moveworkspacetomonitor W M-> dispatch hl.dsp.workspace.move({ workspace = W, monitor = "M" })
    #   dispatch movetoworkspacesilent W   -> dispatch hl.dsp.window.move({ workspace = W, follow = false })
    #   ... same, but ",address:0xA"       -> ... plus `window = "address:0xA"`
    #   dispatch dpms on                   -> dispatch hl.dsp.dpms({ action = "on" })   # see `dpms` above
    #   dispatch exec CMD                  -> dispatch hl.dsp.exec_cmd("CMD")
    #   keyword monitor "O,MODE,POS,S"     -> eval hl.monitor({ output = "O", mode = "MODE", position = "POS", scale = S })
    #   keyword workspace "N, monitor:M, persistent:true"
    #                                      -> eval hl.workspace_rule({ workspace = "N", monitor = "M", persistent = true })
    #
    # `follow = false` is the old `...silent` suffix. Note the dispatchers' "unrecognized
    # arguments. Expected one of: ..." errors list only the mode keys, not every accepted
    # key (`window` and `follow` are absent from it but both work).
    configType = "lua";

    extraConfig = ''
      local mainMod = "SUPER"
      local terminal = "kitty"
      local hyprDir = "~/.config/hypr"

      hl.env("WALLPAPER_DIR", "${walls}")
      hl.env("EDP_SCALE", "${iscale}") -- setup-monitors.sh reuses the per-host eDP scale on dock

      -- scale per host (myDesktop.internalScale); externals via setup-monitors.sh
      hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = ${iscale} })
      hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" }) -- fallback for unknown monitors

      -- Virtual-desktop slots: 1-9 left external, 10-18 right external, 19-27 eDP-1.
      -- Only the external slots depend on which port each Samsung landed on, so only those
      -- are applied at runtime by setup-monitors.sh. eDP-1 is always present and always
      -- owns 19-27, so those rules live here: applied at parse time, they cannot fail over
      -- IPC. That failure is exactly what broke the laptop's virtual desktops when the
      -- runtime `hyprctl keyword workspace` calls started being rejected.
      for i = 19, 27 do
          hl.workspace_rule({ workspace = tostring(i), monitor = "eDP-1", persistent = true, default = true })
      end

      hl.config({
          general = {
              gaps_in     = 3,
              gaps_out    = 6,
              border_size = 1,
              -- gruvbox-dark-medium base0A / base09 / base01, written as literals
              -- ON PURPOSE. These used to read config.lib.stylix.colors so they would
              -- follow the light specialisation, and that is exactly what made a theme
              -- switch expensive: it left hyprland.lua differing between the two
              -- generations, so home-manager's onChange hook for that file fired
              -- `hyprctl reload config-only` on every switch. Measured, reading the
              -- monitors' DDC brightness before and after: that reload alone drops both
              -- externals from 41% to 100% (they do not persist a DDC write and revert
              -- to their OSD default when the link is re-initialised), and it is what
              -- the switch's flicker came from. Nothing else in the switch touches
              -- Hyprland.
              --
              -- So the palette is pushed at RUNTIME instead, by set-theme.sh, over
              -- `hyprctl eval` -- no config reload, no event, no flicker, brightness
              -- untouched. These literals are only the parse-time baseline (a fresh
              -- session, or the moment right after a real rebuild's reload); set-theme
              -- corrects them on every run, including its no-op path.
              --
              -- Two flake checks keep this honest: theme-invariants-<host> asserts the
              -- generated hyprland.lua is byte-identical across the two specialisations
              -- (re-introducing a stylix colour here breaks it), and that these three
              -- hexes still match gruvbox-dark-medium, the scheme modules/theme/
              -- tokens.nix resolves for the dark variant.
              --
              -- hl.config takes rgba(RRGGBBAA), hence the bare hex plus "ff".
              col = {
                  active_border   = { colors = { "rgba(fabd2fff)", "rgba(fe8019ff)" }, angle = 45 },
                  inactive_border = "rgba(3c3836ff)",
              },
              resize_on_border = false,
              allow_tearing    = false,
              layout           = "dwindle",
          },

          decoration = {
              rounding         = 0,
              active_opacity   = 1.0,
              inactive_opacity = 1.0,
              shadow = { enabled = false },
              blur   = { enabled = false },
          },

          animations = { enabled = false }, -- cachy disabled them ("enabled = no, please :)")

          master = { new_status = "master" },

          -- HW cursor plane renders at a fixed size and ignores per-monitor scale, so
          -- the pointer looks a different size on the fractional-scaled eDP (1.57) vs
          -- the scale-1 externals. Software cursors rescale correctly per output.
          cursor = { no_hardware_cursors = true },

          misc = {
              force_default_wallpaper = 1,
              disable_hyprland_logo   = true,
              vrr                     = 1, -- adaptive sync (free win on panels that support it)

              -- Hyprland watches its config PATH and reloads when it changes. Under
              -- nix that watcher can only ever produce false positives: this file is
              -- an immutable store symlink, so it is never hand-edited, and the only
              -- thing that ever "changes" it is home-manager relinking
              -- ~/.config/hypr/hyprland.lua at a new home-manager-files path. That
              -- happens on EVERY theme switch -- the directory hash moves because the
              -- 13 palette files in it moved, even though hyprland.lua itself is
              -- byte-identical across the two generations.
              --
              -- Measured, by relinking the symlink to an identical-content path with
              -- nothing else running: setup-monitors.log went 20 -> 21 -> 22, i.e. two
              -- spurious reloads for zero config change. With this set to true the
              -- same two relinks produced 22 -> 22 -> 22.
              --
              -- Each of those reloads re-inits the outputs: the externals blank for
              -- ~1.2s and come back at 100% brightness (they do not persist a DDC
              -- write). That was the last remaining source of the theme-switch
              -- flicker, after set-theme.sh stopped reloading and the colours were
              -- made static so home-manager's own onChange hook stops firing.
              --
              -- Nothing is lost: that onChange hook still runs `hyprctl reload
              -- config-only`, and it is content-aware (_cmp against the deployed
              -- file), so a real rebuild that genuinely changes this config still
              -- reloads exactly once.
              disable_autoreload      = true,
          },

          -- bypass compositing on fullscreen surfaces (perf; lost in the cachy port)
          render = { direct_scanout = true },

          input = {
              kb_layout    = "es,us",
              kb_variant   = ",dvorak",
              kb_options   = "grp:ctrl_alt_toggle",
              follow_mouse = 1,
              sensitivity  = 0,
              touchpad = {
                  disable_while_typing = true,
                  natural_scroll       = true,
                  tap_to_click         = true,
              },
          },

          binds = { allow_workspace_cycles = true },
      })

      hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

      hl.on("hyprland.start", function()
          hl.exec_cmd("uwsm finalize HYPRLAND_INSTANCE_SIGNATURE")
          hl.exec_cmd("systemctl --user start hyprpolkitagent")
          hl.exec_cmd("wl-paste --type text --watch cliphist store")
          hl.exec_cmd("wl-paste --type image --watch cliphist store")
          hl.exec_cmd("echo dark > $XDG_RUNTIME_DIR/qs-theme") -- Stylix is fixed-dark; tell quickshell
          ${lib.optionalString mm ''hl.exec_cmd("bash " .. hyprDir .. "/setup-monitors.sh")''}
      end)

      -- Letter binds are keysym names on purpose: with resolve_binds_by_sym=0
      -- (the default) Hyprland matches binds through a translation state pinned
      -- to the FIRST layout in kb_layout (es = qwerty positions), so these stay
      -- at US/qwerty physical positions even while the us(dvorak) group is
      -- active. Do NOT switch them to code:NN -- the Lua parser in 0.56 stores
      -- keycode binds only in sMkKeys, leaving key/keycode empty, which breaks
      -- matching, conflict detection and hyprctl introspection (dead binds).

      -- `description` in the opts table is the ONLY human-readable thing a Lua bind
      -- exposes: `hyprctl binds -j` reports every one of them as
      -- dispatcher "__lua" plus an opaque numeric arg, so without it there is
      -- nothing to introspect. The cheat-sheet panel (quickshell/bar/Cheatsheet.qml,
      -- SUPER+? below) hides any bind with has_description=false, which is how the
      -- plumbing binds stay out of it.
      --
      -- Unknown opts keys are silently ignored by the Lua parser (verified in
      -- 0.56.2 src/config/lua/bindings/LuaBindingsToplevel.cpp), so a typo'd
      -- `descrption` still passes --verify-config and just never shows up.

      -- apps
      hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd("uwsm app -- " .. terminal), { description = "Open terminal" })
      hl.bind(mainMod .. " + C", hl.dsp.window.close(), { description = "Close window" })
      hl.bind(mainMod .. " + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
      hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen(), { description = "Toggle fullscreen" })
      hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("echo toggle >> $XDG_RUNTIME_DIR/qs-launcher"), { description = "Open app launcher" })
      hl.bind("ALT + Tab", hl.dsp.window.cycle_next(), { description = "Cycle windows" })
      -- Deliberately undescribed: same keystroke as the line above, it only raises
      -- what that one focused. One key, one cheat-sheet row.
      hl.bind("ALT + Tab", hl.dsp.window.bring_to_top())
      -- CTRL, not SHIFT: SUPER+SHIFT+l is move-window-right (vim loop), and the
      -- shifted keysym L collided with it. No SHIFT means the keysym must be
      -- lowercase l -- capital L only exists as a shifted keysym.
      hl.bind("SUPER + CTRL + l", hl.dsp.exec_cmd("loginctl lock-session"), { description = "Lock session" })
      hl.bind("SUPER + P", hl.dsp.exec_cmd("echo toggle >> $XDG_RUNTIME_DIR/qs-clipboard"), { description = "Open clipboard history" })
      hl.bind("SUPER + SHIFT + P", hl.dsp.exec_cmd("echo toggle >> $XDG_RUNTIME_DIR/qs-clipboard"), { description = "Open clipboard history" })
      hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("echo toggle >> $XDG_RUNTIME_DIR/qs-notif"), { description = "Open notification center" })
      -- F1, not a shifted symbol: bind keysyms resolve against level 0 of the
      -- FIRST kb_layout (es), where slash/question only exist behind Shift --
      -- a bind on either keysym can never fire. F1 is level 0 on every layout.
      hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("echo toggle >> $XDG_RUNTIME_DIR/qs-cheatsheet"), { description = "Show keybindings" })

      -- launch-or-focus: focus the window if the app runs, launch it if not.
      -- mono_player matches by title (-t): it runs under the generic class
      -- "python3", so class matching cannot single it out.
      hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("bash " .. hyprDir .. "/launch-or-focus.sh '^zen' zen-beta"), { description = "Focus or launch browser" })
      hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("bash " .. hyprDir .. "/launch-or-focus.sh keepassxc keepassxc"), { description = "Focus or launch KeePassXC" })
      hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("bash " .. hyprDir .. "/launch-or-focus.sh -t '^mono_player$' mono_player"), { description = "Focus or launch music player" })

      -- screenshots (via bash -> no exec-bit needed)
      hl.bind("Print", hl.dsp.exec_cmd("bash " .. hyprDir .. "/screenshot.sh region"), { description = "Screenshot region" })
      hl.bind("SHIFT + Print", hl.dsp.exec_cmd("bash " .. hyprDir .. "/screenshot.sh window"), { description = "Screenshot active window" })
      hl.bind("CTRL + Print", hl.dsp.exec_cmd("bash " .. hyprDir .. "/screenshot.sh output"), { description = "Screenshot monitor under cursor" })
      hl.bind("SUPER + Print", hl.dsp.exec_cmd("bash " .. hyprDir .. "/screenshot.sh screen"), { description = "Screenshot all monitors" })
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("bash " .. hyprDir .. "/screenshot.sh edit"), { description = "Screenshot region and annotate" })

      -- focus / move window (vim + arrows)
      for _, d in ipairs({
          { key = "h",     dir = "left"  },
          { key = "l",     dir = "right" },
          { key = "k",     dir = "up"    },
          { key = "j",     dir = "down"  },
          { key = "left",  dir = "left"  },
          { key = "right", dir = "right" },
          { key = "up",    dir = "up"    },
          { key = "down",  dir = "down"  },
      }) do
          hl.bind(mainMod .. " + " .. d.key, hl.dsp.focus({ direction = d.dir }), { description = "Focus " .. d.dir })
          hl.bind(mainMod .. " + SHIFT + " .. d.key, hl.dsp.window.move({ direction = d.dir }), { description = "Move window " .. d.dir })
      end

      -- scroll workspaces
      hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Focus next workspace" })
      hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Focus previous workspace" })

      -- workspace/group binds call scripts via `bash` so no exec-bit is needed on store files.
      -- `desc` is the cheat-sheet wording; the slot number is appended per iteration, so the
      -- 36 rows read "Focus desktop 3 on this monitor" and friends.
      for _, s in ipairs({
          { mods = mainMod,               script = "switch-monitor.sh",    desc = "Focus desktop %d on this monitor" },
          { mods = "ALT",                 script = "switch-group.sh",      desc = "Focus desktop %d on all monitors" },
          { mods = mainMod .. " + SHIFT", script = "move-to-group.sh",     desc = "Move window to desktop %d" },
          { mods = "ALT + SHIFT",         script = "move-all-to-group.sh", desc = "Move all windows to desktop %d" },
      }) do
          for i = 1, 9 do
              hl.bind(s.mods .. " + " .. i, hl.dsp.exec_cmd("bash " .. hyprDir .. "/" .. s.script .. " " .. i),
                      { description = string.format(s.desc, i) })
          end
      end

      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })

      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ && echo . >> $XDG_RUNTIME_DIR/qs-volume"), { locked = true, repeating = true, description = "Volume up" })
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && echo . >> $XDG_RUNTIME_DIR/qs-volume"), { locked = true, repeating = true, description = "Volume down" })
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && echo . >> $XDG_RUNTIME_DIR/qs-volume"), { locked = true, repeating = true, description = "Mute output" })
      hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true, description = "Mute microphone" })
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${brightnessScript}/bin/brightness up"), { locked = true, repeating = true, description = "Brightness up" })
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${brightnessScript}/bin/brightness down"), { locked = true, repeating = true, description = "Brightness down" })

      hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
      hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
      hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
      hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })

      -- window rules
      hl.window_rule({
          name  = "suppress-maximize-events",
          match = { class = ".*" },
          suppress_event = "maximize",
      })

      hl.window_rule({
          name  = "fix-xwayland-drags",
          match = {
              class      = "^$",
              title      = "^$",
              xwayland   = true,
              float      = true,
              fullscreen = false,
              pin        = false,
          },
          no_focus = true,
      })

      hl.window_rule({
          name  = "move-hyprland-run",
          match = { class = "hyprland-run" },
          move  = "20 monitor_h-120",
          float = true,
      })
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
        after_sleep_cmd = wakeUp;
        # Fires when the session actually stops being locked, not when the Unlock
        # signal arrives (that is `unlock_cmd`). hyprlock's exit is what re-inits the
        # outputs, so this is the edge the externals need.
        on_unlock_cmd = ddcSync;
      };
      listener = [
        { timeout = 240; on-timeout = "brightnessctl -s set 20%"; on-resume = "brightnessctl -r"; }
        { timeout = 300; on-timeout = "loginctl lock-session"; on-resume = wakeUp; }
        { timeout = 360; on-timeout = dpms "off"; on-resume = wakeUp; }
        { timeout = 900; on-timeout = "systemctl suspend"; }
      ];
    };
  };

  # The lock that `caffeine` flips. Holding it is the unit's entire job, so the
  # inhibitor's lifetime is exactly the unit's lifetime — nothing to clean up and
  # nothing to leak. Deliberately NO Install.WantedBy: it is started on demand
  # only. PartOf graphical-session.target so logging out cannot leave a machine
  # that refuses to suspend.
  systemd.user.services.caffeine = {
    Unit = {
      Description = "Inhibit idle, sleep and lid-switch handling (caffeine mode)";
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      # --mode=block, the default, is the one hypridle sees: it reads logind's
      # BlockInhibited, which lists block locks only. `idle` is what stops
      # hypridle's listeners, `sleep` blocks an explicit `systemctl suspend`, and
      # handle-lid-switch keeps a closed lid running — logind's own lid policy is
      # otherwise unconfigured here, so its default (suspend) would apply.
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=idle:sleep:handle-lid-switch --who=caffeine --why=caffeine-mode ${pkgs.coreutils}/bin/sleep infinity";
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
      # base16 input-field colors, written here rather than via
      # stylix.targets.hyprlock: that target also forces settings.background to a
      # solid base00, which collides with the blurred-wallpaper background above.
      # These are the exact values it would have set (see stylix modules/hyprlock/
      # hm.nix), so the lock screen follows the light/dark specialisation either way.
      "input-field" = [{
        monitor = "";
        size = "280, 42";
        outer_color = "rgb(${config.lib.stylix.colors.base03})";
        inner_color = "rgb(${config.lib.stylix.colors.base00})";
        font_color = "rgb(${config.lib.stylix.colors.base05})";
        fail_color = "rgb(${config.lib.stylix.colors.base08})";
        check_color = "rgb(${config.lib.stylix.colors.base0A})";
        # doubled ## is hyprlock's escape for a literal # inside pango markup
        placeholder_text = ''<span foreground="##${config.lib.stylix.colors.base04}">contraseña...</span>'';
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
      # quickshell loads QML once at startup; without this, a switch deploys the
      # new config but the running bar keeps the old one until a manual restart.
      # Interpolating the source dir bakes its store hash into the unit file, so
      # any change under quickshell/ makes sd-switch restart the service.
      X-Restart-Triggers = [ "${./quickshell}" ];
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

  # Restores the palette that was last chosen. The ONLY thing that changes it
  # automatically -- there is no time-of-day switching; a theme-sync.timer used to
  # fire at 09:00/18:00 and was removed, so the palette now changes only on request.
  #
  # This unit still has to exist, because a `nixos-rebuild switch` re-runs the
  # home-manager unit and lands on the parent generation, i.e. dark, whatever you
  # had picked. It reads the recorded mode rather than the active one for exactly
  # that reason, and no-ops when the two already agree, so firing it at login is
  # free.
  systemd.user.services.theme-sync = {
    Unit = {
      Description = "Restore the last chosen gruvbox palette";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      # The timer is WantedBy=timers.target, so it fires from ANY login that
      # starts the user systemd manager -- including a bare SSH session, where a
      # multi-second home-manager generation switch is an unwanted surprise and
      # there is no bar to update. After= does not prevent that (it only orders).
      # Hyprland creates $XDG_RUNTIME_DIR/hypr/<signature>, so this is the cheapest
      # honest "is there a desktop here" test. A failed Condition skips the unit
      # quietly rather than logging a failure, unlike Requisite=.
      ConditionPathExistsGlob = "%t/hypr/*";
      # Do not let a home-manager activation start or restart this unit. set-theme
      # IS what triggers that activation, and HM's reloadSystemd step would then
      # start theme-sync inside it, re-entering set-theme one level deep on every
      # single switch. The lock in the script makes that nested call harmless, but
      # this stops it being spawned at all — a theme switch has no business
      # re-running the thing that asked for it.
      X-SwitchMethod = "keep-old";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${setTheme}/bin/set-theme restore";
    };
    # Runs at login, which is what re-applies the chosen palette after a
    # nixos-rebuild switch reverted it to the parent/dark generation.
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # scripts deployed individually so they coexist with the generated hyprland.lua
  xdg.configFile = {
    "hypr/monitors-detect.sh".source = ./scripts/monitors-detect.sh;
    "hypr/hyprctl-classify.sh".source = ./scripts/hyprctl-classify.sh;
    "hypr/switch-monitor.sh".source = ./scripts/switch-monitor.sh;
    "hypr/switch-group.sh".source = ./scripts/switch-group.sh;
    "hypr/move-to-group.sh".source = ./scripts/move-to-group.sh;
    "hypr/move-all-to-group.sh".source = ./scripts/move-all-to-group.sh;
    "hypr/screenshot.sh".source = ./scripts/screenshot.sh;
    "hypr/launch-or-focus.sh".source = ./scripts/launch-or-focus.sh;
    # Thin shim so the bar can reach set-theme at a FIXED path. QML is a static
    # file and cannot interpolate a store path, and every other consumer here
    # invokes wrapped scripts by absolute `${pkg}/bin/name`. Calling `set-theme`
    # by bare name would have worked (home.packages lands in
    # /etc/profiles/per-user/$USER/bin, which is on the systemd user PATH) but it
    # depends on the session environment rather than on the closure, and
    # execDetached fails silently when a name does not resolve. Forwarding through
    # the wrapper also keeps its runtimeInputs, and puts the reference back under
    # repo-lint's ~/.config/hypr/*.sh rule, which does not see bare-name calls.
    "hypr/set-theme.sh".text = ''
      #!/usr/bin/env bash
      exec ${setTheme}/bin/set-theme "$@"
    '';
    # Same shim rationale as set-theme.sh above.
    "hypr/caffeine.sh".text = ''
      #!/usr/bin/env bash
      exec ${caffeine}/bin/caffeine "$@"
    '';
    "quickshell".source = ./quickshell;
  } // lib.optionalAttrs mm {
    "hypr/setup-monitors.sh".source = ./scripts/setup-monitors.sh;
  };
}

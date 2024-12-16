{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    exec-once = [
      "nm-applet &"
      "hyprctl setcursor gruvbox 24"
      "waybar"
    ];

    input = {
      kb_layout = "es,us";
      kb_variant =  ",dvorak";
      kb_options = grp:alt_shift_toggle;

      force_no_accel = true;

      follow_mouse = 1;

      touchpad = {
        disable_while_typing = true;
        natural_scroll = true;
        tap-to-click = true;
      };
    };

    monitor = "desc:BOE 0x074F,preferred,auto,1.2";

    general = {
      gaps_in = 3;
      gaps_out = 6;
      border_size = 3;
      #active_border= "0xff282828";
      #inactive_border= "0xffFBF1C7";
    };

      misc = {
        disable_hyprland_logo = 1;
        disable_splash_rendering = 1;
        vfr = true;
        vrr = 1;
      };

      binds = {
        allow_workspace_cycles = 1;
      };

    # Decorations
decoration = {
    drop_shadow = false;
    # Rounded corners
    rounding = 8;
    #multisample_edges = true
    # Opacity
    active_opacity = 1.0;
    inactive_opacity = 1.0;
    # Shadow
    #drop_shadow = true
    shadow_ignore_window = true;
    shadow_offset = "2 2";
    shadow_range = 4;
    shadow_render_power = 2;
      #col.shadow = "0x66000000";
    # Blur
    blur = {
        enabled = true;
        size = 10;
        passes = 4;
        new_optimizations = true;
      }; 
    };

      animations = {
        enabled = true;

        bezier = [
          "fluent_decel, 0, 0.2, 0.4, 1"
          "easeOutCirc, 0, 0.55, 0.45, 1"
          "easeOutCubic, 0.33, 1, 0.68, 1"
          "easeinoutsine, 0.37, 0, 0.63, 1"
        ];

        animation = [
          # Windows
          "windowsIn, 1, 3, easeOutCubic, popin 30%" # window open
          "windowsOut, 1, 3, fluent_decel, popin 70%" # window close.
          "windowsMove, 1, 2, easeinoutsine, slide" # everything in between, moving, dragging, resizing.

          # Fade
          "fadeIn, 1, 3, easeOutCubic" # fade in (open) -> layers and windows
          "fadeOut, 1, 2, easeOutCubic" # fade out (close) -> layers and windows
          "fadeSwitch, 0, 1, easeOutCirc" # fade on changing activewindow and its opacity
          "fadeShadow, 1, 10, easeOutCirc" # fade on changing activewindow for shadows
          "fadeDim, 1, 4, fluent_decel" # the easing of the dimming of inactive windows
          "border, 1, 2.7, easeOutCirc" # for animating the border's color switch speed
          "borderangle, 1, 30, fluent_decel, once" # for animating the border's gradient angle - styles: once (default), loop
          "workspaces, 1, 4, easeOutCubic, fade" # styles: slide, slidevert, fade, slidefade, slidefadevert
        ];
      };

      gestures = {
        workspace_swipe = true;
      };
  };
}

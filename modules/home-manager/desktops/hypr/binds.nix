{ ... }:
{
  wayland.windowManager.hyprland.settings = {
    bind = [
      # show keybindings
      #"SUPER, F1, exec, show-keybinds"

      #terminal
      "SUPER, Return, exec, kitty"

      # close
      "SUPER, C, killactive,"

      # fullscreen
      "SUPER, F, fullscreen,"

      # toggle floating
      "SUPER, Space, togglefloating,"
      "SUPER, Space, centerwindow,"
      "SUPER, Space, resizeactive, exact 500 600"

      # toggle rofi
      "SUPER, D, exec, rofi -show drun || pkill rofi"

      # hyprlock
      "SUPER, Escape, exec, hyprlock"
      #"switch:Lid Switch, exec, hyprlock"

      # laptop brigthness
        ",XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        "SUPER, XF86MonBrightnessUp, exec, brightnessctl set 100%+"
        "SUPER, XF86MonBrightnessDown, exec, brightnessctl set 100%-"

      # volume
        ",XF86AudioRaiseVolume,exec, pamixer -i 2"
        ",XF86AudioLowerVolume,exec, pamixer -d 2"

      # change focus
      "SUPER, left, movefocus, l"
      "SUPER, right, movefocus, h"
      "SUPER, up, movefocus, j"
      "SUPER, down, movefocus, k"

      # Move/resize windows with mainMod + LMB/RMB and dragging
      "SUPER, mouse:272, movewindow"
      "SUPER, mouse:273, resizeactive"

      # switch workspace
      "SUPER, 1, workspace, 1"
      "SUPER, 2, workspace, 2"
      "SUPER, 3, workspace, 3"
      "SUPER, 4, workspace, 4"
      "SUPER, 5, workspace, 5"
      "SUPER, 6, workspace, 6"
      "SUPER, 7, workspace, 7"
      "SUPER, 8, workspace, 8"
      "SUPER, 9, workspace, 9"

      # move to workspace
      "SUPER SHIFT, 1, movetoworkspacesilent, 1"
      "SUPER SHIFT, 2, movetoworkspacesilent, 2"
      "SUPER SHIFT, 3, movetoworkspacesilent, 3"
      "SUPER SHIFT, 4, movetoworkspacesilent, 4"
      "SUPER SHIFT, 5, movetoworkspacesilent, 5"
      "SUPER SHIFT, 6, movetoworkspacesilent, 6"
      "SUPER SHIFT, 7, movetoworkspacesilent, 7"
      "SUPER SHIFT, 8, movetoworkspacesilent, 8"
      "SUPER SHIFT, 9, movetoworkspacesilent, 9"


    ];
  };
}

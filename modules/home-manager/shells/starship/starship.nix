{ config, lib, ... }:
let
  c = config.lib.stylix.colors;
in
{
  programs.starship = {
    enable = true;

    enableZshIntegration = true;

    settings = {
      format = lib.concatStrings [
        "[](color_orange)"
        "$os"
        "[](bg:color_yellow fg:color_orange)"
        "$directory"
        "[](fg:color_yellow bg:color_aqua)"
        "$git_branch"
        "$git_status"
        "[](fg:color_aqua bg:color_blue)"
        "$nix_shell"
        "[](fg:color_blue bg:color_bg3)"
        "$cmd_duration"
        "[](fg:color_bg3 bg:color_bg1)"
        "$time"
        "[](fg:color_bg1)"
        "$line_break"
        "$character"
      ];

      palette = "stylix";
      palettes.stylix = {
        color_fg0 = "#${c.base07}";
        color_bg1 = "#${c.base01}";
        color_bg3 = "#${c.base03}";
        color_blue = "#${c.base0D}";
        color_aqua = "#${c.base0C}";
        color_green = "#${c.base0B}";
        color_orange = "#${c.base09}";
        color_purple = "#${c.base0E}";
        color_red = "#${c.base08}";
        color_yellow = "#${c.base0A}";
      };

      os = {
        disabled = false;
        style = "bg:color_orange bold fg:color_fg0";
        symbols = {
          NixOS = " ";
        };
      };

      directory = {
        style = "bold fg:color_fg0 bg:color_yellow";
        format = "[ $path ]($style)";
        truncation_length = 3;
      };

      git_branch = {
        symbol = "";
        style = "bg:color_aqua";
        format = "[[ $symbol $branch ](bold fg:color_fg0 bg:color_aqua)]($style)";
      };

      git_status = {
        style = "bg:color_aqua bold fg:color_fg0";
        format = "[$all_status$ahead_behind]($style)";
      };

      nix_shell = {
        format = "[ via nix $name ]($style)";
        style = "bg:color_blue bold fg:color_fg0";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:color_bg1";
        format = "[[   $time ](fg:color_fg0 bg:color_bg1)]($style)";
      };

      cmd_duration = {
        format = "[ 󰔛 $duration ]($style)";
        disabled = false;
        style = "bg:color_bg3 fg:color_fg0";
        show_notifications = false;
        min_time_to_notify = 60000;
      };

      line_break = {
        disabled = false;
      };

      character = {
        disabled = false;
        success_symbol = "[  ](bold fg:color_green)";
        error_symbol = "[  ](bold fg:color_red)";
        vimcmd_symbol = "[  ](bold fg:color_yellow)";
        vimcmd_replace_symbol = "[  ](bold fg:color_purple)";
        vimcmd_replace_one_symbol = "[  ](bold fg:color_purple)";
        vimcmd_visual_symbol = "[  ](bold fg:color_aqua)";
      };
    };
  };
}


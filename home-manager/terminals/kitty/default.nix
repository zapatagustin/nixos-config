{ lib, config, ... }: {
  config = lib.mkIf (config.thinkpad.terminal == "kitty") {
    home-manager.users.${config.thinkpad.homeManagerUser}.programs.kitty = {
      enable = true;
      settings = {
        font_family = "UDEV Gothic Medium";
        bold_font = "UDEV Gothic Bold";
        italic_font = "UDEV Gothic Italic";
        bold_italic_font = "UDEV Gothic Bold Italic";

        font_size = "12.0";

        adjust_line_height = "92%";

        confirm_os_window_close = 0;
      };
    };
  };
}

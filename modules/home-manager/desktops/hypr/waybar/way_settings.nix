{ ... }: 
{
  programs.waybar.settings.mainBar = {
    position= "left";
    layer= "top";
    height= 200;
    margin-left= 10;
    modules-center= [
        "hyprland/workspaces"
        "network"
        "pulseaudio"
        "battery"
        "backlight"
        "tray"
        "clock"
    ];

    "hyprland/workspaces"= {
        format = "{icon}";
        on-click = "activate";
        sort-by-name = true;
        format-icons = {
            "1" = "一";
            "2" = "二";
            "3" = "三";
            "4" = "四";
            "5" = "五";
            "6" = "六";
            "7" = "七";
            "8" = "八";
            "9" = "九";
        };
        persistent-workspaces = {
            "1"= [];
            "2"= [];
            "3"= [];
            "4"= [];
            "5"= [];
            "6"= [];
            "7"= [];
            "8"= [];
            "9"= [];
        };
    };

    clock= {
        calendar = {
          format = { today = "<span color='#98971A'><b>{}</b></span>"; };
        };
        format = "  {:%H:%M}";
        tooltip= "true";
        tooltip-format= "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        format-alt= "  {:%d/%m}";
    };

    network = {
        format-wifi = "WIFI {essid}";
        format-ethernet = "ETH {ipaddr}/{cidr}";
        format-alt = "ALT";
        format-disconnected = "<span>󰖪 </span>";
    };

    tray= {
        spacing= 10;
    };

    pulseaudio= {
        format= "VOL {volume}%";
        format-muted= "<span> </span> {volume}%";
        format-icons= {
            default= ["<span> </span>"];
        };
        scroll-step= 5;
        on-click= "pamixer -t";
    };

    battery = {
        states = {
            warning = 20;
            critical = 10;
        };
        format = "BAT";
        format-icons = [" " " " " " " " " "];
        format-charging = "<span> </span>{capacity}%";
        format-full = "<span> </span>{capacity}%";
        format-warning = "<span> </span>{capacity}%";
        interval = 5;
        format-time = "{H}h{M}m";
        tooltip = true;
        tooltip-format = "{time}";
    };

    backlight = {
        tooltip = "false";
        format = "{icon} {percent}%";
        format-icons = ["BHT" "BHT" "BHT" "BHT" "BHT" "BHT" "BHT"];
     };
  };
}

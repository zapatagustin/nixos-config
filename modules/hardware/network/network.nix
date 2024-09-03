{ ... }: {
    networking.networkmanager.enable = true;
    services.vnstat.enable = true;
    users.users.thinkpad = {
      extraGroups = [ "networkmanager" ];
    };
}

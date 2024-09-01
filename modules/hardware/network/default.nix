{ lib, config, ... }: {
  config = lib.mkIf config.thinkpad.baseConfiguration {
    networking.networkmanager.enable = true;
    services.vnstat.enable = true;
    users.users.${config.thinkpad.homeManagerUser} = {
      extraGroups = [ "networkmanager" ];
    };
  };
}

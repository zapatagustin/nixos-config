{ lib, config, ... }: {
  config = lib.mkIf (config.thinkpad.displayManager == "lightdm") {
    services.xserver.displayManager.lightdm = {
      enable = true;
      greeters.slick.enable = true;
    };
  };
}

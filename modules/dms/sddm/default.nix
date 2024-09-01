{ lib, config, ... }: {
  config = lib.mkIf (config.thinkpad.displayManager == "sddm") {
    services.displayManager.sddm.enable = true;
  };
}
{ lib, config, ... }: {
  config = lib.mkIf (config.thinkpad.bootloader == "systemd") {
    # Bootloader
    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
      };
    };
  };
}

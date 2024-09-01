{ lib, config, ... }: {
  config = lib.mkIf (config.thinkpad.bootloader == "grub") {
    # Bootloader
    boot.loader = {
      grub = {
        device = "/dev/sda";
        enableCryptodisk = true;
        configurationLimit = 5;
      };
    };
  };
}

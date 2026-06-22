{ lib, config, ... }: {
  boot = {
    loader = {
      timeout = 1;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        consoleMode = "max";
      };
    };

    # Modern systemd-in-initrd (faster, TPM/encrypt-friendly)
    initrd.systemd.enable = true;

    kernelParams = [ "quiet" "splash" "loglevel=3" "udev.log_level=3" ];
  };

  systemd.services.NetworkManager-wait-online.enable = false;
}

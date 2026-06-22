{ lib, config, ... }: {
  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        consoleMode = "max";
      };
    };

    # Quiet boot
    kernelParams = [ "quiet" "splash" "loglevel=3" "udev.log_level=3" ];
  };

  # Don't block boot waiting for network
  systemd.services.NetworkManager-wait-online.enable = false;
}

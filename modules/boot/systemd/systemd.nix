{ lib, config, ... }: {
  boot = {
    loader = {
      timeout = 1;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        consoleMode = "max";
        editor = false;                  # no edit-cmdline at boot menu (security)
      };
    };

    # Modern systemd-in-initrd
    initrd = {
      systemd.enable = true;
      compressor = "zstd";
      compressorArgs = [ "-19" "-T0" ];
    };

    consoleLogLevel = 0;
    kernelParams = [ "quiet" "splash" "loglevel=3" "udev.log_level=3" ];
  };

  systemd.services.NetworkManager-wait-online.enable = false;
}

_: {
  boot = {
    # NOTE: boot.resumeDevice is per-host (swap UUID differs per machine) and
    # lives in hosts/<host>/default.nix — needed so HybridSleep
    # (upower criticalPowerAction) can actually resume after hibernation.

    loader = {
      timeout = 5;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        consoleMode = "max";
        editor = false; # no edit-cmdline at boot menu (security)
      };
    };

    # Modern systemd-in-initrd
    initrd = {
      systemd.enable = true;
      compressor = "zstd";
      # -6 over -19: much faster initrd builds (every rebuild) for a marginally
      # larger image. zstd decompresses at ~the same speed regardless of level,
      # so boot time is unaffected.
      compressorArgs = [ "-6" "-T0" ];
      # early KMS: load i915 in initrd so the native 1366x768 i915 framebuffer
      # comes up in the initrd instead of ~18s into boot (currently fbcon only
      # takes over the i915 console late; until then the firmware GOP framebuffer
      # is in charge). Helps if early boot text renders at a sub-native firmware
      # resolution; harmless otherwise. Panel only mode is 1366x768.
      kernelModules = [ "i915" ];
    };

    consoleLogLevel = 0;
    # splash removed: no plymouth configured, kernel ignores it silently.
    kernelParams = [ "quiet" "loglevel=3" "udev.log_level=3" ];
  };

  systemd.services.NetworkManager-wait-online.enable = false;
}

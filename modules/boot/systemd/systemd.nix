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

    # systemd-in-initrd is mandatory since the scripted initrd was removed
    # (nixos-unstable 26.11); boot.initrd.systemd.enable no longer exists.
    initrd = {
      compressor = "zstd";
      # -6 over -19: much faster initrd builds (every rebuild) for a marginally
      # larger image. zstd decompresses at ~the same speed regardless of level,
      # so boot time is unaffected.
      compressorArgs = [ "-6" "-T0" ];
      # early-KMS modules (i915 on the laptops, amdgpu on desktop) are per-host:
      # they live in hosts/<host>/default.nix / hardware-configuration.nix. This
      # module used to load i915 here, which leaked the Intel driver into the
      # all-AMD desktop's initrd.
    };

    consoleLogLevel = 0;
    # splash removed: no plymouth configured, kernel ignores it silently.
    kernelParams = [ "quiet" "loglevel=3" "udev.log_level=3" ];
  };

  systemd.services.NetworkManager-wait-online.enable = false;
}

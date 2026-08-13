{ pkgs, hostname, lib, config, ... }: {
  imports = [
    ./bluetooth/bluetooth.nix
    ./network/network.nix
    ./sound/sound.nix
  ];

  # brightnessctl udev rules: make /sys/class/backlight writable by `video`
  # group so XF86MonBrightness keys work without root.
  services.udev.packages = [ pkgs.brightnessctl ];

  powerManagement.enable = true;

  services = {
    # The power button suspends instead of powering off. It sits next to keys you
    # actually use on this chassis, and logind's default of `poweroff` turns a
    # mis-hit into lost work with no confirmation.
    #
    # HandlePowerKeyLongPress stays at its default of `ignore`, so there is no
    # hold-to-force-off either -- a hard power cut is what the firmware's own
    # multi-second hold is for, below the OS entirely.
    #
    # Set under services.logind.settings.Login, which is the current path; the flat
    # services.logind.powerKey option it replaced no longer exists here.
    logind.settings.Login.HandlePowerKey = "suspend";

    hardware.bolt.enable = true;
    timesyncd.enable = true;
    gpm.enable = true;
    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
    };

    # ThinkPad power/thermal
    tlp = {
      enable = true;
      settings = {
        # CPU governor + energy policy
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";

        # Battery longevity (ThinkPad charge thresholds) — ThinkPad-only
        START_CHARGE_THRESH_BAT0 = lib.mkIf (hostname == "thinkpad") 40;
        STOP_CHARGE_THRESH_BAT0 = lib.mkIf (hostname == "thinkpad") 80;

        # WiFi / WoL / USB power
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";
        WOL_DISABLE = "Y";
        USB_AUTOSUSPEND = 1;

        # Runtime PM + disk
        RUNTIME_PM_ON_AC = "on";
        RUNTIME_PM_ON_BAT = "on";
        DISK_IDLE_SECS_ON_BAT = 2;

        # Audio
        SOUND_POWER_SAVE_ON_AC = 0;
        SOUND_POWER_SAVE_ON_BAT = 1;
      };
    };

    # Intel BD PROCHOT throttling fix — for Skylake/Kaby-era ThinkPads (T480/X1C6).
    # disabled: measured no-op on this i7-1185G7 (Tiger Lake). Under all-core load
    # the package caps at ~32W / 86-93C (thermal-bound), never reaching the 44W PL1
    # throttled maintains; forcing PL1=28W changed sustained clocks <2%. 11th-gen
    # isn't affected by the BD PROCHOT bug, and the config didn't disable it anyway.
    # throttled.enable = true;

    thermald.enable = true;
    power-profiles-daemon.enable = false;
    fwupd.enable = true;

    upower = {
      enable = true;

      # HybridSleep suspends AND writes a hibernation image, so a battery that dies
      # mid-suspend resumes from disk instead of cold-booting. That fallback needs
      # boot.resumeDevice, which is per-host (the swap UUID differs per machine) and
      # is NOT set on every host -- thinkpad's is still a commented-out TODO.
      #
      # This file is shared by both hosts, so asking for HybridSleep unconditionally
      # promised a safety net one of them could not deliver, and silently: the image
      # gets written, nothing can read it back, and the machine cold-boots at exactly
      # the moment the feature existed to prevent that. Derive the action from the
      # precondition instead of asserting it, so each host gets the strongest option
      # it can actually honour -- and so thinkpad upgrades itself the day its
      # resumeDevice is filled in, with no TODO left to remember.
      #
      # PowerOff rather than Suspend for the host without it: at percentageAction the
      # battery has minutes left, and a plain suspend would drain into an unclean
      # shutdown anyway. Losing the session to a clean power-off is the honest
      # outcome, not a worse one.
      #
      # Hibernation itself stays possible because security.protectKernelImage is left
      # off (hosts/host.nix) -- turning it on would block hibernation and make this
      # whole branch moot.
      criticalPowerAction =
        if config.boot.resumeDevice != "" then "HybridSleep" else "PowerOff";

      percentageLow = 20;
      percentageCritical = 10;
      percentageAction = 5;
    };

    # SSD
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    smartd.enable = true;

    # USB / removable mount
    udisks2.enable = true;
    gvfs.enable = true;
  };

  programs.fuse.userAllowOther = true;

  # TPM2: sealed keys and attestation. NOT doing LUKS auto-unlock, whatever an
  # earlier version of this comment claimed -- neither host has an encrypted root
  # (both are plain ext4, no boot.initrd.luks anywhere), so there is nothing to
  # auto-unlock and this is inert on that front.
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 75;
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    # was enableAllFirmware: measured — every firmware this machine loads (i915,
    # iwlwifi, intel-bluetooth) is in linux-firmware (redistributable). All-firmware
    # only added non-redistributable blobs this hardware never requests.
    enableRedistributableFirmware = true;

    graphics = {
      enable = true;

      # VA-API. Mesa ships no Intel video driver, so a bare graphics.enable leaves
      # these machines with zero hardware video decode: /run/opengl-driver/lib/dri
      # holds the gallium drivers for other vendors and no iHD_drv_video.so at all,
      # vainfo finds nothing, and every player falls back to software without
      # saying so. Measured on surface (i7-1185G7, Tiger Lake / Gen12) -- with
      # intel-media-driver present vainfo reports VAProfileAV1Profile0 and VP9
      # profiles 0-3 under VAEntrypointVLD, which is the exact format ladder
      # YouTube serves.
      #
      # iHD only. The legacy i965 driver predates Gen12 and would only ever be
      # picked by mistake; leaving it out also removes the ambiguity that makes
      # LIBVA_DRIVER_NAME necessary, since libva has a single candidate to probe.
      # vpl-gpu-rt is likewise left out -- it is the oneVPL runtime for QSV
      # transcoding, and nothing here transcodes.
      extraPackages = [ pkgs.intel-media-driver ];
    };
    trackpoint = {
      enable = lib.mkDefault true;
      speed = 200;
      emulateWheel = true;
    };
  };
}

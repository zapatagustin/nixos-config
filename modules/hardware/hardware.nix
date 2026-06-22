{ ... }: {
  imports = [
    ./bluetooth/bluetooth.nix
    ./network/network.nix
    ./sound/sound.nix
  ];

  powerManagement.enable = true;

  services = {
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

        # Battery longevity (ThinkPad charge thresholds)
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;

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

    # Intel BD PROCHOT throttling fix (massive perf bug on ThinkPads)
    throttled.enable = true;

    thermald.enable = true;
    power-profiles-daemon.enable = false;
    fwupd.enable = true;

    upower = {
      enable = true;
      criticalPowerAction = "Suspend";   # safe without real swap; switch to Hibernate when swap exists
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

  # TPM2 (LUKS auto-unlock, sealed keys, attestation)
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
    enableAllFirmware = true;
    graphics.enable = true;
    trackpoint = {
      enable = true;
      speed = 200;
      emulateWheel = true;
    };
  };
}

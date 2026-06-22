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
    gpm.enable = true;  # mouse in TTY
    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
    };

    # ThinkPad power/thermal
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;  # battery longevity
      };
    };
    thermald.enable = true;
    power-profiles-daemon.enable = false;  # conflicts with TLP
    upower.enable = true;
    fwupd.enable = true;

    # SSD
    fstrim = {
      enable = true;
      interval = "weekly";
    };
    smartd.enable = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
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

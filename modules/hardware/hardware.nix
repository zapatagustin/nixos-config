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
    libinput = {
      enable = true;
      mouse.accelProfile = "flat";
    };

    # ThinkPad power/thermal
    tlp.enable = true;
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
  };
}

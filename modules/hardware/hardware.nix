{ ... }: {
  imports = [
    ./bluetooth/bluetooth.nix
    #./kernel
    ./network/network.nix
    ./sound/sound.nix
    #./virtualization
  ];

    powerManagement = {
      enable = true;
    };

    services = {
      hardware.bolt.enable = true;
      timesyncd.enable = true;
      libinput.enable = true;
    };

    zramSwap.enable = true; # To not change upstream! It is managed by the installer
    hardware = {
      cpu.intel.updateMicrocode = true; # To not change upstream! It is managed by the installer
      bluetooth.enable = true;
      enableAllFirmware = true; # Need allowUnfree = true
      enableRedistributableFirmware = true;
      graphics = {
        enable = true;
      };
    };
}

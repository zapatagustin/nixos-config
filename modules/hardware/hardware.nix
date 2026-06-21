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
  };

  zramSwap.enable = true;
  hardware = {
    cpu.intel.updateMicrocode = true;
    enableAllFirmware = true;
    graphics.enable = true;
  };
}

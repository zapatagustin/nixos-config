_: {
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    # disabled until a device needs it: experimental BlueZ D-Bus API + kernel BT
    # features are less-audited code paths reachable over radio on a laptop that
    # joins public spaces. Re-enable naming the device that requires it (typical
    # case: headset battery reporting needs Experimental = true).
    # settings.General = {
    #   Experimental = true;
    #   KernelExperimental = true;
    # };
  };
}

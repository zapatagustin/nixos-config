{ lib, ... }:
{
  options.myDesktop.multiMonitor.enable = lib.mkEnableOption
    "dual-Samsung dock multimonitor daemon + TV HDR (docking host only)";
}

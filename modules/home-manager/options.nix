{ lib, ... }:
{
  options.myDesktop.multiMonitor.enable = lib.mkEnableOption
    "dual-Samsung dock multimonitor daemon + TV HDR (docking host only)";

  # Fractional scale for the internal (eDP-1) panel. Per host: the surface's
  # 2256x1504 13.5" panel needs ~1.3333; keep 1.0 elsewhere. Must yield integer
  # logical pixels for the panel's resolution or Hyprland snaps it.
  options.myDesktop.internalScale = lib.mkOption {
    type = lib.types.float;
    default = 1.0;
    description = "Scale factor for the eDP-1 internal display.";
  };
}

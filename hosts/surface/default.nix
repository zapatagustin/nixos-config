{ username, ... }:
{
  imports = [ ../../configuration.nix ];
  # surface docks to 2x Samsung LF27T35 → multimonitor daemon + TV HDR.
  # internalScale: 2256x1504 13.5" panel, 1.566667 → 1440x960 logical (exact).
  # Hyprland only accepts scales where 2256/scale and 1504/scale are integers on
  # the 1/120 grid; valid steps above 1.3333 (4/3) are 1.566667 and 1.6 only.
  home-manager.users.${username}.myDesktop = {
    multiMonitor.enable = true;
    internalScale = 1.566667;
  };

  # Surface is a work laptop — no LAN services, no gaming.
  services.pihole.enable = false; # LAN DNS sinkhole — off here AND on thinkpad (nobody serves it yet)
  services.gaming.enable = false; # Steam + GameMode + Wine
  hardware.trackpoint.enable = false; # no TrackPoint on Surface

  # DDC/CI so the brightness keys drive the docked monitors too (not just the
  # internal backlight). hardware.i2c loads i2c-dev + udev rules granting the
  # `i2c` group access to /dev/i2c-*; ddcutil (in the hyprland module) talks DDC.
  hardware.i2c.enable = true;
  users.users.${username}.extraGroups = [ "i2c" ];

  # swap UUID from this host's hardware-configuration.nix (nvme0n1p3) — resume target
  boot.resumeDevice = "/dev/disk/by-uuid/5ad9fdfe-3002-4f12-9857-6b6fa2aac5a0";
}

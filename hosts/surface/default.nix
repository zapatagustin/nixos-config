{ username, ... }:
{
  imports = [ ../../configuration.nix ];
  # surface docks to 2x Samsung LF27T35 → enable the multimonitor daemon + TV HDR
  home-manager.users.${username}.myDesktop.multiMonitor.enable = true;
}

{ ... }:
{
  imports = [ ../../configuration.nix ];
  # nomad laptop: never docks → multiMonitor stays at its default (false)

  # TODO: set this to this host's swap UUID (see swapDevices in
  # hardware-configuration.nix, or `blkid`) to enable hibernation resume.
  # Leave unset until then — a wrong/missing UUID with systemd-initrd hangs boot.
  # boot.resumeDevice = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
}

{ username, ... }:
{
  imports = [ ../../configuration.nix ];
  # nomad laptop: never docks → multiMonitor stays at its default (false)
  home-manager.users.${username}.myDesktop.panelResolution = {
    # ecomono: assumed 1920x1080 -- the real panel size is not in the repo; verify with
    # `hyprctl monitors` and correct here (dithered images are rendered 1:1 to it).
    width = 1920;
    height = 1080;
  };

  # TODO: set this to this host's swap UUID (see swapDevices in
  # hardware-configuration.nix, or `blkid`) to enable hibernation resume.
  # Leave unset until then — a wrong/missing UUID with systemd-initrd hangs boot.
  # boot.resumeDevice = "/dev/disk/by-uuid/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX";
}

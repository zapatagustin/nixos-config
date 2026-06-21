{ ... }:
{
  imports = [
    ./boot/systemd/systemd.nix
    ./dev/dev_dependencies.nix
    ./hardware/hardware.nix
    ./gaming/gaming.nix
    ./desktops/desktops.nix
  ];
}

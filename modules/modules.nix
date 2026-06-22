{ ... }:
{
  imports = [
    ./boot/systemd/systemd.nix
    ./dev/dev_dependencies.nix
    ./hardware/hardware.nix
    ./gaming/gaming.nix
    ./performance/performance.nix
  ];
}

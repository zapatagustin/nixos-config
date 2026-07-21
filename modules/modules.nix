{ ... }:
{
  imports = [
    ./boot/systemd/systemd.nix
    ./containers/containers.nix
    ./dev/dev_dependencies.nix
    ./hardware/hardware.nix
    ./gaming/gaming.nix
    ./performance/performance.nix
    ./theme/stylix.nix
    ./wm/hyprland.nix
    ./secrets/sops.nix
  ];
}

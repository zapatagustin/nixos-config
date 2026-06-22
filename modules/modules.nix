{ ... }:
{
  imports = [
    ./boot/systemd/systemd.nix
    ./containers/containers.nix
    ./dev/dev_dependencies.nix
    ./hardware/hardware.nix
    # ./gaming/gaming.nix         # disabled until DE/compositor is re-added
    ./performance/performance.nix
    ./theme/stylix.nix
    # ./secrets/sops.nix          # enable after creating secrets/secrets.yaml (see README)
  ];
}

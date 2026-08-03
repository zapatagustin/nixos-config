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
    # disabled until the hermes-agent flake input builds again: its vendored npm cache is
    # missing @nous-research/ui, so hermes-tui and hermes-web fail with npm ENOTCACHED.
    # Broke when flake.lock was still untracked and therefore floating: it got regenerated
    # and picked up NousResearch/hermes-agent 4b60979, pushed 23 min before the rebuild.
    # flake.lock is tracked now, so that revision is pinned and the break is reproducible
    # rather than a moving target — do NOT put flake.lock back in .gitignore. Re-enable
    # this import once `nix flake update hermes-agent` brings in a revision that builds.
    # ./ai/hermes.nix
  ];
}

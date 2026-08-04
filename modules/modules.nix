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
    # hermes-agent removed entirely (input, module and ./ai/hermes.nix) — it never
    # built here (vendored npm cache missing @nous-research/ui → hermes-tui and
    # hermes-web fail with npm ENOTCACHED) and its input dragged a second, staler
    # nixpkgs into the lockfile. Reinstate from git history when it's worth another
    # try. NOTE: flake.lock stays tracked — do NOT put it back in .gitignore, the
    # original break came from it floating untracked and silently re-resolving.
  ];
}

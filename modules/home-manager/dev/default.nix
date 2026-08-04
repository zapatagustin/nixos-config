{ pkgs, ... }:
{
  home.packages = with pkgs; [
    (google-cloud-sdk.withExtraComponents [
      google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
    kubectl

    # Linters for this flake, on PATH so scripts/hooks/pre-commit runs in
    # milliseconds. The same four are gated in `nix flake check`; the hook exists
    # to run them on staged files before the commit rather than after. Calling
    # them via `nix run nixpkgs#...` instead would pay an eval on every commit.
    nixpkgs-fmt
    statix
    deadnix
    shellcheck
  ];
}

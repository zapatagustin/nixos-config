{ pkgs, ... }:
{
  # stylix zed target is enabled in ../../stylix.nix (central HM instance); it
  # writes theme + fonts into programs.zed-editor below.
  programs.zed-editor = {
    enable = true;
    # Zed wrapped to read the Anthropic API key from sops-nix at launch, so the
    # secret never lands in the nix store or a global session var (only Zed sees
    # it). programs.zed-editor installs this package, so stylix can theme it while
    # the sops wrapper stays in place.
    package = pkgs.symlinkJoin {
      name = "zed-editor-sops";
      paths = [ pkgs.zed-editor ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/zeditor \
          --run 'export ANTHROPIC_API_KEY="$(cat /run/secrets/zed/anthropic-api-key 2>/dev/null)"'
      '';
    };
  };
}

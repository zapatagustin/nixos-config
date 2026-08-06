# AI agent stack. The Claude Code + opencode config, the shared skills, the
# gentle-ai binary, and the activation script that registers Claude Code plugins
# and user-scope MCP servers all come from the ecomono flake input, imported in
# ../home.nix. This module is only the packages that are not part of that config.
{ pkgs, osConfig, ... }:

{
  home.packages = with pkgs; [
    opencode
    opencode-desktop
  ];

  # Provider credentials, which the ecomono flake deliberately does NOT ship.
  #
  # It used to: every provider carried "apiKey": "{file:/run/secrets/...}". Those
  # paths exist only on a NixOS host running sops-nix, and ecomono's install.sh
  # links opencode.json verbatim instead of patching it the way it patches tui.json
  # -- so on Arch, Debian or a generic install the credentials pointed at files that
  # were never going to be there, and failed with nothing saying why. A flake that
  # installs on four platforms should not hardcode one platform's secret store, so
  # the paths moved HERE, where they are actually true.
  #
  # Note this is the OPPOSITE call from the opencode THEME collision, resolved with
  # a local mkForce in ../stylix.nix. The deciding question is not which repo is
  # more convenient to edit, it is whether the upstream value is right ANYWHERE
  # ELSE: "gruvbox" is a fine default on every other machine, so the override
  # belongs to the consumer; a sops path is wrong on every machine that is not this
  # one, so it belongs nowhere but the consumer.
  #
  # Merging works because programs.opencode.settings takes pkgs.formats.json's
  # type, which merges per key: ecomono keeps supplying baseURL and models for each
  # provider and only the apiKey leaf comes from here. Verified by evaluating the
  # merged attrset, not assumed.
  #
  # Paths come from osConfig rather than as literals -- home-manager runs as a NixOS
  # module here, so the sops declarations are reachable, and deriving them means the
  # name is written once. A renamed secret breaks at eval instead of resolving to a
  # file that is not there.
  programs.opencode.settings.provider =
    let
      fromSops = secret: {
        options.apiKey = "{file:${osConfig.sops.secrets.${secret}.path}}";
      };
    in
    {
      nvidia = fromSops "opencode/nvidia-api-key";
      groq = fromSops "opencode/groq-api-key";
      cerebras = fromSops "opencode/cerebras-api-key";
      openrouter = fromSops "opencode/openrouter-api-key";
      # Shared with the zed wrapper (../editors/zed), which reads the same file.
      anthropic = fromSops "zed/anthropic-api-key";
    };

  # ecomono-code and cavemem were removed once opencode reached compression
  # parity via the cave-compress plugin (shipped by the ecomono flake): its
  # tool-output/JSON/dedup/char-cap layers cover the same token savings, and
  # ecomono-memory already owns persistent memory. No npm-global tools remain,
  # so the ~/.npm-global prefix + sessionPath were dropped too.
}

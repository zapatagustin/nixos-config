# AI agent stack. The Claude Code + opencode config, the shared skills, the
# gentle-ai binary, and the activation script that registers Claude Code plugins
# and user-scope MCP servers all come from the ecomono flake input, imported in
# ../home.nix. This module is only the packages that are not part of that config.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    opencode
    opencode-desktop
  ];

  # ecomono-code and cavemem were removed once opencode reached compression
  # parity via the cave-compress plugin (shipped by the ecomono flake): its
  # tool-output/JSON/dedup/char-cap layers cover the same token savings, and
  # ecomono-memory already owns persistent memory. No npm-global tools remain,
  # so the ~/.npm-global prefix + sessionPath were dropped too.
}

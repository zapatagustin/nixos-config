# AI agent stack: opencode + gentle-ai + engram binaries, plus the Claude Code
# plugins (engram, ponytail, caveman). The plugins live as imperative state
# under ~/.claude/plugins — Nix can't manage them declaratively — so they're
# installed idempotently on HM activation instead: already-installed plugins
# are skipped, and failures (e.g. offline rebuild) warn without aborting.
{ pkgs, lib, ... }:

let
  gentle-ai = pkgs.callPackage ../../../pkgs/gentle-ai.nix { };
  engram = pkgs.callPackage ../../../pkgs/engram.nix { };
in
{
  home.packages = with pkgs; [
    opencode
    nodejs # ponytail/caveman plugin hooks expect node on PATH
    gentle-ai
    engram
  ];

  home.activation.aiAgentPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claude=${pkgs.claude-code}/bin/claude

    ensurePlugin() {
      local repo="$1" name="$2"
      if ! "$claude" plugin list 2>/dev/null | grep -q "$name"; then
        # Full https URL: the owner/repo shorthand clones over ssh, which
        # fails inside the HM activation service (no ssh-agent there).
        run "$claude" plugin marketplace add "https://github.com/$repo" || true
        run "$claude" plugin install "$name@$name" \
          || echo "warning: could not install claude plugin $name (retry: claude plugin install $name@$name)"
      fi
    }

    ensurePlugin Gentleman-Programming/engram engram
    ensurePlugin DietrichGebert/ponytail ponytail
    ensurePlugin JuliusBrussee/caveman caveman

    # engram <= 0.1.1 ships hook scripts with #!/bin/bash, which doesn't exist
    # on NixOS. Patch the plugin cache until upstream switches to /usr/bin/env;
    # idempotent, but a plugin auto-update between rebuilds reintroduces it
    # (hook fails non-blocking) until the next switch.
    find "$HOME/.claude/plugins/cache/engram" -name '*.sh' \
      -exec ${pkgs.gnused}/bin/sed -i '1s|^#!/bin/bash$|#!/usr/bin/env bash|' {} + 2>/dev/null || true

    # Hook engram's MCP server into opencode once; skipped if its config
    # already mentions engram so we never clobber manual edits.
    if ! grep -rqs engram "$HOME/.config/opencode"; then
      run ${engram}/bin/engram setup opencode \
        || echo "warning: engram setup opencode failed (retry: engram setup opencode)"
    fi
  '';
}

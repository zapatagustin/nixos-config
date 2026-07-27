# AI agent stack: opencode + gentle-ai, plus the Claude Code plugins and
# user-scope MCP servers. Those live as imperative state under ~/.claude —
# Nix can't manage them declaratively — so they're registered idempotently on
# HM activation instead: already-installed entries are skipped, and failures
# (e.g. offline rebuild) warn without aborting.
{ pkgs, lib, ... }:

let
  gentle-ai = pkgs.callPackage ../../../pkgs/gentle-ai.nix { };
in
{
  home.packages = with pkgs; [
    opencode
    opencode-desktop
    nodejs # skill-registry refresh script expects node on PATH
    bun # runs ecomono-memory: the opencode plugin and the MCP server bundle
    gentle-ai
  ];

  home.activation.aiAgentPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    claude=${pkgs.claude-code}/bin/claude

    # $3 is the marketplace name when it differs from the plugin name (the
    # marketplace.json "name" field); defaults to the plugin name otherwise.
    ensurePlugin() {
      local repo="$1" name="$2" market="''${3:-$2}"
      if ! "$claude" plugin list 2>/dev/null | grep -q "$name"; then
        # Full https URL: the owner/repo shorthand clones over ssh, which
        # fails inside the HM activation service (no ssh-agent there).
        run "$claude" plugin marketplace add "https://github.com/$repo" || true
        run "$claude" plugin install "$name@$market" \
          || echo "warning: could not install claude plugin $name (retry: claude plugin install $name@$market)"
      fi
    }

    # Retire the Gentleman-Programming engram plugin: ecomono-memory replaces it
    # with a native bun:sqlite implementation serving the same mem_* tools, so
    # leaving it installed means two memory stores answering at once. This also
    # clears "engram@engram" from ~/.claude/settings.json, which Nix can't own.
    # No data is lost — storage/db.ts imports ~/.engram/engram.db on first run.
    if "$claude" plugin list 2>/dev/null | grep -q engram; then
      run "$claude" plugin uninstall engram@engram || true
      run "$claude" plugin marketplace remove engram || true
    fi

    # User-scope MCP servers (~/.claude.json, runtime-managed by Claude Code
    # itself — Nix can't own that file).
    ensureMcp() {
      local name="$1"; shift
      if ! "$claude" mcp get "$name" >/dev/null 2>&1; then
        run "$claude" mcp add --scope user "$name" -- "$@" \
          || echo "warning: could not register mcp server $name (retry: claude mcp add --scope user $name -- $*)"
      fi
    }

    ensureMcp context7 npx -y --package=@upstash/context7-mcp@2.2.5 -- context7-mcp

    # ecomono-memory: persistent memory for Claude Code, the same store the
    # opencode plugin uses. Self-contained bundle — runs from the store with no
    # node_modules. The server name is the prefix Claude Code gives its tools,
    # so agents whitelist mcp__ecomono-memory__mem_*.
    if "$claude" mcp get engram >/dev/null 2>&1; then
      run "$claude" mcp remove engram || true
    fi
    ensureMcp ecomono-memory ${pkgs.bun}/bin/bun ${../opencode/config/plugins/storage/mcp-server.js}

  '';

  # ecomono-code and cavemem were removed once opencode reached compression
  # parity via the cave-compress plugin (modules/home-manager/opencode/config/
  # plugins): its tool-output/JSON/dedup/char-cap layers cover the same token
  # savings, and ecomono-memory already owns persistent memory. No npm-global tools
  # remain, so the ~/.npm-global prefix + sessionPath were dropped too.
}

{ config, ... }:
let
  homeDir = config.home.homeDirectory;

  # A handful of vendored files hardcode /home/agustin (the machine the config
  # was authored on). Rewrite it to the target host's home so the config works
  # for any username (surface / thinkpad).
  patch = builtins.replaceStrings [ "/home/agustin" ] [ homeDir ];

  # Load a vendored JSON config, patch home paths, and drop the $schema key
  # (programs.opencode injects the correct one itself).
  readSettings = f: builtins.removeAttrs (builtins.fromJSON (patch (builtins.readFile f))) [ "$schema" ];
in
{
  programs.opencode = {
    enable = true;

    # opencode.json — agents, mcp (context7 + engram over PATH), providers,
    # permissions, plugin refs, instructions. Rendered to opencode.json.
    settings = readSettings ./config/opencode.json;

    # tui.json — plugin list (patched cyndaquill.tsx path). Separate file since
    # opencode v1.2.15.
    tui = readSettings ./config/tui.json;

    context = ./config/AGENTS.md;
    commands = ./config/commands;
    skills = ./config/skills;
  };

  # Not covered by programs.opencode options: the local plugin sources, the
  # TUI plugin sources, and the plugin package.json. opencode auto-loads the
  # .ts files from plugins/ and installs node_modules alongside them at runtime,
  # so these are linked as individual entries (the dir stays writable).
  xdg.configFile = {
    "opencode/plugins/ecomono".source = ./config/plugins/ecomono;
    "opencode/plugins/cyndaquill".source = ./config/plugins/cyndaquill;
    "opencode/plugins/model-variants.ts".source = ./config/plugins/model-variants.ts;
    "opencode/plugins/skill-registry.ts".source = ./config/plugins/skill-registry.ts;
    # cave-compress.ts — tool-output token compression (ported from
    # ecomono-code, MIT). opencode auto-loads .ts files from plugins/.
    "opencode/plugins/cave-compress.ts".source = ./config/plugins/cave-compress.ts;
    # memory.ts — native bun:sqlite persistent memory, replacing the engram Go
    # binary and its HTTP bridge. No path patching needed: it resolves its data
    # dir from homedir() at runtime. storage/ holds the shared core (the same
    # tool registry backs the Claude Code MCP server) and stays a subdir so
    # opencode does not auto-load its modules as plugins.
    "opencode/plugins/memory.ts".source = ./config/plugins/memory.ts;
    "opencode/plugins/storage".source = ./config/plugins/storage;
    "opencode/tui-plugins".source = ./config/tui-plugins;
    "opencode/package.json".source = ./config/package.json;
  };

  # opencode.json `instructions` points at ~/.agents/skills/ecomono/SKILL.md.
  # This is a shared agent-skills dir, vendored and linked read-only.
  home.file.".agents/skills".source = ./agents-skills;
}

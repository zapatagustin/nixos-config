{ config, lib, pkgs, ... }:
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
    "opencode/plugins/caveman".source = ./config/plugins/caveman;
    "opencode/plugins/cyndaquill".source = ./config/plugins/cyndaquill;
    "opencode/plugins/model-variants.ts".source = ./config/plugins/model-variants.ts;
    "opencode/plugins/skill-registry.ts".source = ./config/plugins/skill-registry.ts;
    # engram.ts hardcodes /home/agustin as a last-resort binary fallback — patch it.
    "opencode/plugins/engram.ts".text = patch (builtins.readFile ./config/plugins/engram.ts);
    "opencode/tui-plugins".source = ./config/tui-plugins;
    "opencode/package.json".source = ./config/package.json;
  };

  # opencode.json `instructions` points at ~/.agents/skills/caveman/SKILL.md.
  # This is a shared agent-skills dir, vendored and linked read-only.
  home.file.".agents/skills".source = ./agents-skills;
}

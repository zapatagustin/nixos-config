{ config, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;

  # mcp/engram.json was authored on an Arch box: it hardcodes /home/agustin and
  # /usr/bin/node. Rewrite to the target host's home and to a PATH-resolved
  # `node` so the config works on any NixOS host.
  patch = builtins.replaceStrings [ "/home/agustin" "/usr/bin/node" ] [ homeDir "node" ];
in
{
  # Hook scripts (caveman/ponytail) are Node scripts invoked as `node ...`.
  home.packages = [ pkgs.nodejs ];

  programs.claude-code = {
    enable = true;
    # Manage config only; bring your own claude binary (avoids pinning pkgs.claude-code).
    package = null;
    # settings.json is intentionally NOT managed: Claude Code writes it at
    # runtime (theme, model, /config), which a read-only store symlink would
    # break. Kept manual — ./claude/settings.json is a reference template to
    # copy into ~/.claude on a fresh host.
    context = ./claude/CLAUDE.md;
  };

  # Dirs/files not covered by programs.claude-code options. All are clean of
  # host-specific paths except mcp/engram.json, which is patched.
  home.file = {
    ".claude/agents".source = ./claude/agents;
    ".claude/commands".source = ./claude/commands;
    ".claude/hooks".source = ./claude/hooks;
    ".claude/output-styles".source = ./claude/output-styles;
    ".claude/themes".source = ./claude/themes;
    ".claude/skills".source = ./claude/skills;
    ".claude/mcp/context7.json".source = ./claude/mcp/context7.json;
    ".claude/mcp/engram.json".text = patch (builtins.readFile ./claude/mcp/engram.json);
  };
}

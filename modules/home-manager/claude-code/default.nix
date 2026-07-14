{ config, lib, pkgs, ... }:
let
  homeDir = config.home.homeDirectory;

  # settings.json and mcp/engram.json were authored on an Arch box: they hardcode
  # /home/agustin and /usr/bin/node. Rewrite to the target host's home and to a
  # PATH-resolved `node` so the config works on any NixOS host.
  patch = builtins.replaceStrings [ "/home/agustin" "/usr/bin/node" ] [ homeDir "node" ];
  readSettings = f: builtins.fromJSON (patch (builtins.readFile f));
in
{
  # Hook scripts (caveman/ponytail) are Node scripts invoked as `node ...`.
  home.packages = [ pkgs.nodejs ];

  programs.claude-code = {
    enable = true;
    # Manage config only; bring your own claude binary (avoids pinning pkgs.claude-code).
    package = null;
    settings = readSettings ./claude/settings.json;
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

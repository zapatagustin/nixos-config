{ pkgs, ... }:
let
  # Claude Code skills = the real ./claude/skills tree PLUS the ecomono skills,
  # whose canonical source is ../opencode/agents-skills (shared with opencode).
  # Merged into ONE store dir so ~/.claude/skills is a single symlink whose
  # children are real content that resolves. The ecomono skills can't be
  # relative symlinks inside ./claude/skills (a "../../.agents/..." link escapes
  # the store and breaks), and they can't be per-child home.file entries either
  # (home-manager can't create a child inside the read-only store symlink that
  # .claude/skills becomes). Building the merged dir here sidesteps both.
  claudeSkills = pkgs.runCommand "claude-code-skills" { } ''
    mkdir -p $out
    cp -r ${./claude/skills}/. $out/
    for s in ecomono ecomono-commit ecomono-compress ecomono-help ecomono-review; do
      cp -r ${../opencode/agents-skills}/$s $out/$s
    done
  '';
in
{
  # Hook scripts (ecomono/ponytail) are Node scripts invoked as `node ...`.
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

  # Dirs/files not covered by programs.claude-code options.
  # MCP servers are NOT declared here: Claude Code doesn't read arbitrary
  # files under .claude/mcp/ (that was dead config). User-scope MCP servers
  # live in the runtime-managed ~/.claude.json, so they're registered
  # imperatively in ai/default.nix's activation script instead, the same way
  # plugins are.
  home.file = {
    ".claude/agents".source = ./claude/agents;
    ".claude/commands".source = ./claude/commands;
    ".claude/hooks".source = ./claude/hooks;
    ".claude/output-styles".source = ./claude/output-styles;
    ".claude/themes".source = ./claude/themes;
    ".claude/skills".source = claudeSkills;
  };
}

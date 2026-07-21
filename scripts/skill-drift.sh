#!/usr/bin/env bash
# Report drift between the claude and opencode copies of each shared skill.
#
# The two copies are hand-maintained and legitimately differ in places
# (opencode has an ORCHESTRATOR GATE preamble, different frontmatter, task()
# vs Task). This script does NOT try to tell intentional drift from accidental
# drift — it surfaces every divergence and its size so a human decides. Run it
# after editing any skill to confirm the edit landed in both copies.
#
# Usage:
#   scripts/skill-drift.sh            # summary: which skills drift, by how much
#   scripts/skill-drift.sh <name>     # full unified diff for one skill
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
claude_dir="$repo/modules/home-manager/claude-code/claude/skills"
opencode_dir="$repo/modules/home-manager/opencode/config/skills"

# Full diff for a single skill when a name is given.
if [ $# -ge 1 ]; then
  name="$1"
  cc="$claude_dir/$name/SKILL.md"
  oc="$opencode_dir/$name/SKILL.md"
  [ -f "$cc" ] || { echo "no claude skill: $name" >&2; exit 2; }
  [ -f "$oc" ] || { echo "no opencode skill: $name" >&2; exit 2; }
  diff -u --label "claude/$name" "$cc" --label "opencode/$name" "$oc" || true
  exit 0
fi

# Summary across all shared skills.
identical=0 drifted=0 only_claude=0
drift_lines=""
for d in "$claude_dir"/*/; do
  name="$(basename "$d")"
  cc="$d/SKILL.md"
  oc="$opencode_dir/$name/SKILL.md"
  [ -f "$cc" ] || continue
  if [ ! -f "$oc" ]; then
    only_claude=$((only_claude + 1))
    drift_lines+="  only-in-claude  $name"$'\n'
    continue
  fi
  if diff -q "$cc" "$oc" >/dev/null 2>&1; then
    identical=$((identical + 1))
  else
    drifted=$((drifted + 1))
    # count of differing lines (added + removed) as a rough drift size
    n=$(diff "$cc" "$oc" | rg -c '^[<>]' || true)
    drift_lines+=$(printf '  drift(%-4s)   %s\n' "$n" "$name")$'\n'
  fi
done

printf 'shared skills: identical=%d drifted=%d only-in-claude=%d\n\n' \
  "$identical" "$drifted" "$only_claude"
if [ -n "$drift_lines" ]; then
  printf '%s' "$drift_lines"
  printf '\nsee one: scripts/skill-drift.sh <name>\n'
fi

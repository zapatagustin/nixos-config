---
name: judgment-day
description: "Trigger: judgment day, dual review, adversarial review, juzgar. Run blind dual review, fix confirmed issues, then re-judge."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.4"
---

## Activation Contract

Load only when user explicitly requests Judgment Day, dual/adversarial review, or `juzgar`/`que lo juzguen`. Target: files, feature, PR, or architecture slice.

## Hard Rules

- Resolve skills before launching: read registry, match by target files/task, inject `Skills to load before work` into judge + fix prompts.
- Launch **two blind judges in parallel** — same target, same criteria. You never review code yourself.
- Wait for both judges before synthesis. No partial verdicts.
- `WARNING (real)` only if normal intended use triggers it. Otherwise → INFO as `WARNING (theoretical)`.
- Ask before Round 1 fixes.
- After fix agent runs → immediately re-judge both judges in parallel before commit/push/done/session-summary.
- Terminal states: only `JUDGMENT: APPROVED` or `JUDGMENT: ESCALATED`.
- After 2 fix iterations with remaining issues, ask user to continue or stop.

## Decision Gates

| Condition | Action |
|---|---|
| Target unclear | Ask scope. No judges. |
| No skill registry | Warn, proceed with generic criteria, record `Skill Resolution: none`. |
| Both judges find same CRITICAL/real WARNING | Confirmed. Ask/fix per round rules. |
| One judge finds issue | Suspect. Report + triage. No auto-fix. |
| Judges contradict | Escalate for manual decision. |
| Round 2+ only theoretical warnings/suggestions | Report as INFO. No re-judge. |

## Execution Steps

1. Confirm target + optional custom criteria.
2. Resolve skill paths from registry (or warn).
3. Start Judge A + Judge B concurrently via delegation.
4. Synthesize findings → confirmed, suspect, contradiction, INFO buckets.
5. Ask before Round 1 fixes. Delegate separate fix agent for confirmed approved fixes only.
6. Re-judge in parallel after fixes. Repeat until approved, escalated, or user stops.
7. Before terminal action: verify every active Judgment Day has terminal state.

## Output Contract

Return `## Judgment Day — {target}` with round number, verdict table, confirmed/suspect/contradiction counts, fixes applied, re-judgment result, `Skill Resolution`, and final `JUDGMENT: APPROVED ✅` or `JUDGMENT: ESCALATED ⚠️`.

**Output compression**: Compress narrative (descriptions, evidence, rationale, finding context). Keep structural fields (severity, file:line, verdict labels) EXACT. Code blocks/paths exact. Drop articles/filler/hedging in prose.

## References

- [references/prompts-and-formats.md](references/prompts-and-formats.md) — judge/fix prompts, warning rubric, verdict tables, and language snippets.

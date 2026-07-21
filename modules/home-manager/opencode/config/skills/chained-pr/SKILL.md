---
name: chained-pr
description: "Trigger: PRs over 400 lines, stacked PRs, review slices. Split oversized changes into chained PRs that protect review focus."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## Activation Contract

Load when PR may exceed **400 changed lines**, SDD forecasts `400-line budget risk: High` or `Chained PRs recommended: Yes`, or user asks for chained/stacked PRs, review slices, or reviewer-load control.

## Hard Rules

- Split PRs over **400 changed lines** unless maintainer explicitly accepts `size:exception`.
- Each PR reviewable ≤**60 minutes**.
- One deliverable work unit per PR. Tests/docs with their unit.
- Each chained PR: state start, end, prior dependencies, follow-up, out-of-scope.
- Every child PR: dependency diagram with current PR marked `📍`.
- Feature Branch Chain: draft/no-merge tracker PR. Child#1 targets tracker branch, later children target immediate parent.
- Polluted diff = base bug. Retarget/rebase until only current work unit shows.
- No mixing chain strategies after user chooses.

## Decision Gates

| Condition | Action |
|---|---|
| PR ≤400 lines, focused | Single PR. |
| PR >400, each slice independent | Stacked PRs to main. |
| PR >400, feature must integrate before main | Feature Branch Chain with tracker. |
| Generated/vendor/migration diff cannot split | Ask maintainer `size:exception`. |
| SDD provides `delivery_strategy` | Follow before apply/PR. |

## Execution Steps

1. Estimate changed lines, identify independent work units.
2. Ask for chain strategy when none cached and budget exceeded.
3. Create branches/PRs using chosen strategy only.
4. Add Chain Context to each PR (don't replace repo PR template).
5. Verify each PR independently: CI/tests/docs/manual, rollback scope, clean diff.
6. Keep tracker PR draft/no-merge until all child PRs reviewed + integrated.

## Output Contract

Return the chosen strategy, PR order, current PR boundary, dependency diagram, review budget (`additions + deletions`), verification plan, and any `size:exception` rationale.

**Output compression**: Compress narrative (descriptions, rationale, context). Keep structural fields (strategy, PR order, budget numbers) EXACT. Drop articles/filler in prose.

## References

- [references/chaining-details.md](references/chaining-details.md) — strategy diagrams, PR body section, branch commands, and reviewer guidance.

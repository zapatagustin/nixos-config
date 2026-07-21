---
name: work-unit-commits
description: "Plan commits as reviewable work units. Trigger: implementation, commit splitting, chained PRs, or keeping tests and docs with code."
license: Apache-2.0
metadata:
  author: gentleman-programming
  version: "1.0"
---

## When to Use

Load when deciding what belongs in each commit or PR.

Use for:
- Splitting feature into reviewable work
- Preparing commits before PR
- Turning large change into chained/stacked PRs
- Keeping reviewer load healthy
- Applying SDD tasks without exceeding 400 changed lines

## Critical Rules

| Rule | Requirement |
|------|-------------|
| Commit by work unit | A commit represents a deliverable behavior, fix, migration, or docs unit. |
| Do not commit by file type | Avoid `models`, then `services`, then `tests` if none works alone. |
| Keep tests with code | Tests belong in the same commit as the behavior they verify. |
| Keep docs with the user-visible change | Docs belong with the feature or workflow they explain. |
| Tell a story | A reviewer should understand why each commit exists from its diff and message. |
| Future PR-ready | Each commit should be a candidate chained PR when the change grows. |
| SDD workload guard | If SDD tasks forecast a >400-line change, group commits into chained PR slices before implementation. |

## Work Unit Checklist

Before committing, confirm:

- [ ] The commit has one clear purpose.
- [ ] The repo still makes sense after applying only this commit.
- [ ] Tests or docs for this unit are included when relevant.
- [ ] Rollback is reasonable without reverting unrelated work.
- [ ] The commit message explains the outcome, not the file list.

## Split Examples

| Weak split | Better work-unit split |
|------------|------------------------|
| `add models` | `feat(auth): add token validation domain model and tests` |
| `add services` | `feat(auth): wire token validation into login flow` |
| `add tests` | Tests included with each behavior commit |
| `update docs` | Docs included with the user-facing change they explain |

## PR Relationship

Work-unit commits = foundation for chained PRs:

1. Build smallest independent work unit.
2. Include verification.
3. Commit with Conventional Commit message.
4. PR approaches 400 lines? Promote commits/groups into chained PRs.

## Output Compression

Compress narrative in commit/PR planning output. Keep structural fields (file paths, commands, commit hashes, task IDs, line counts) EXACT. Drop articles/filler/hedging in explanations. Code blocks, commands, paths exact.

## SDD Relationship

When `sdd-tasks` produces Review Workload Forecast:

- Low risk: work-unit commits inside one PR.
- Medium risk: commit by unit, monitor changed lines before PR.
- High risk: follow `delivery_strategy` — ask on `ask-on-risk`, auto-slice on `auto-chain`, require `size:exception` on over-budget `single-pr`, record accepted on `exception-ok`.

Each SDD work unit maps to commit/PR with:

- clear start state
- clear finished state
- verification in same unit
- rollback that does not remove unrelated work

## Commands

```bash
# Review the story before committing
git diff --stat
git diff --cached --stat

# Check recent commit style
git log --oneline -5
```

# SDD Status and Instructions Contract

Shared contract for SDD commands and phase skills. Use before acting on change — no guessing state, paths, or edit scope.

## Purpose

Commands that select, continue, apply, verify, or archive an SDD change MUST produce or consume structured status. Status = handoff between orchestrator and phase executor.

## Change Selection

- Name provided? Confirm exists in artifact store, then use.
- No name? Infer only when unambiguous from session state or exactly one active change.
- Multiple/unclear? Ask user. No guessing.
- None active? Report, suggest `/sdd-new <change>`.

## Native Engine

- Store `openspec`/`hybrid` AND `gentle-ai` binary available? Prefer `gentle-ai sdd-status [change] --cwd <repo> --json --instructions` for status, `gentle-ai sdd-continue [change] --cwd <repo>` for dispatcher. Store `engram`? Do NOT invoke binary.
- Native engine reads only OpenSpec file artifacts, emits `artifactStore: openspec` — cannot observe Engram changes. Authoritative only when store is `openspec`/`hybrid`. Store `engram`? Resolve from Engram (`mem_search` + `mem_get_observation`). Disregard `blocked`, `Active OpenSpec change not found`, `nextRecommended: sdd-new` for an Engram change that exists.
- For `openspec`/`hybrid`: native JSON authoritative over prompt inference or manual state.
- `blockedReasons` non-empty? Do NOT proceed to terminal/archive/apply. Report, stop — unless `nextRecommended` is `verify` (may run only to remediate/refresh evidence). `nextRecommended` is `resolve-blockers`? Report, stop. Planning token (`propose`, `spec`, `design`, `tasks`)? Launch corresponding phase — missing artifacts = expected output, not blockers.
- `nextRecommended` = bounded machine token. Route only by it + dependency states. Human explanation goes in `blockedReasons`.
- Binary unavailable? Fall back to this contract + manual schema. Manual MUST stay shape-compatible with `gentle-ai.sdd-status` JSON.

## Status Schema

Return markdown with fields below, or equivalent JSON:

```yaml
schemaName: gentle-ai.sdd-status
schemaVersion: 1
changeName: <change-name-or-null>
artifactStore: openspec | engram | hybrid
planningHome:
  mode: repo-local
  path: <absolute path to openspec>
changeRoot: <absolute path to openspec/changes/<change> or null>
artifactPaths:
  proposal: [<absolute path>]
  specs: [<absolute paths>]
  design: [<absolute path>]
  tasks: [<absolute path>]
  applyProgress: [<absolute path>]
  verifyReport: [<absolute path>]
contextFiles:
  proposal: [<absolute readable files>]
  specs: [<absolute readable files>]
  design: [<absolute readable files>]
  tasks: [<absolute readable files>]
  verifyReport: [<absolute readable files>]
artifacts:
  proposal: missing | done | partial
  specs: missing | done | partial
  design: missing | done | partial
  tasks: missing | done | partial
  applyProgress: missing | done | partial
  verifyReport: missing | done | partial
taskProgress:
  total: 0
  completed: 0
  pending: 0
  allComplete: false
dependencies:
  proposal: blocked | ready | all_done
  specs: blocked | ready | all_done
  design: blocked | ready | all_done
  tasks: blocked | ready | all_done
  apply: blocked | ready | all_done
  verify: blocked | ready | all_done
  archive: blocked | ready | all_done
applyState: blocked | all_done | ready
actionContext:
  mode: repo-local
  workspaceRoot: <absolute path>
  allowedEditRoots: [<absolute paths>]
relationships:
  dependsOn: []
  supersedes: []
  amends: []
  conflictsWith: []
  sameDomainActiveChanges: []
phaseInstructions:
  apply: [<instruction strings>]
  verify: [<instruction strings>]
  archive: [<instruction strings>]
nextRecommended: propose | spec | design | tasks | apply | verify | archive | sdd-new | select-change | resolve-blockers
blockedReasons: []
```

`phaseInstructions` optional, appears only when requested. Carries only `apply`/`verify`/`archive` keys; planning tokens (`propose`, `spec`, `design`, `tasks`) surface in dispatcher markdown, NOT this map. Empty path fields = arrays, not null. `changeName`/`changeRoot` nullable. Native emits `artifactStore: openspec`; manual MUST set actual session store (`openspec`, `engram`, or `hybrid`).

## Apply State

- `blocked`: Required artifacts missing, task ambiguity, or unsafe edit context.
- `all_done`: Tasks exist, every task checked `[x]`.
- `ready`: Tasks exist, ≥1 unchecked, edit scope safe.

## Dependency States

- `proposal`, `specs`, `design`, `tasks`: report if prereqs blocked/ready/all_done.
- `apply` ready: specs + design + tasks available, progress not all_done.
- `verify` ready: tasks exist, and apply-progress exists OR tasks show all impl complete. Incomplete tasks block full verification.
- `archive` ready: verify-report exists, clearly passing, tasks complete. Passing = explicit PASS/SUCCESS, no FAIL/FAILURE/BLOCKED/CRITICAL/PENDING/TODO/verification-blockers/`not passed`/`pass: no`. CRITICAL: no override. Exceptions: non-critical partial archives or stale-checkbox reconciliation when apply-progress/verify-report prove completion.

## Action Context Guard

Orchestrator MUST carry `actionContext` into any phase launch.

- Manual context cannot prove ownership/allowed roots? Stop.
- `allowedEditRoots` present? Edit only within those roots.
- Cannot prove file inside workspace/allowed roots? Stop, ask.

## Status Output

Every command acting on a change MUST show status before executor/archive:

- Active change + resolution method.
- Artifact statuses + paths/topics.
- Task progress + unchecked list.
- Next recommended action.
- `blockedReasons` (when not `verify`) + edit-root blockers.

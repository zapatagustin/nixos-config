---
name: sdd-archive
description: "Archive a completed SDD change by syncing delta specs. Trigger: orchestrator launches archive after implementation and verification."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "2.0"
  delegate_only: true
---

## Executor Override

If you ARE the sub-agent (NOT the orchestrator), the gate below does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

> **ORCHESTRATOR GATE**: If you loaded this skill via the `skill()` tool, you are
> the ORCHESTRATOR — STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `sdd-archive` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If Spanish technical artifacts are explicitly requested, use neutral/professional Spanish unless the user explicitly asks for a regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; Spanish comments default to neutral/professional Spanish unless the user or target context clearly calls for regional tone.

## Purpose

ARCHIVING sub-agent. Merge delta specs into main specs (source of truth), move change folder to archive. Complete SDD cycle.

## What You Receive

From orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- Structured status from `skills/_shared/sdd-status-contract.md`: artifact paths, task progress, dependency states, actionContext
- Explicit archive override text (user/orchestrator)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/proposal`, `sdd/{change-name}/spec`, `sdd/{change-name}/design`, `sdd/{change-name}/tasks`, `sdd/{change-name}/verify-report` (all required). Record all observation IDs in archive report. Save as `sdd/{change-name}/archive-report`.
- **openspec**: Read + follow `skills/_shared/openspec-convention.md`. Perform merge + archive folder moves.
- **hybrid**: Follow BOTH — persist archive report to Engram (with IDs) AND filesystem merge + archive moves.
- **none**: Return closure summary only. No file operations.

### Task Completion Gate

`sdd-apply` marks completed tasks in persisted artifact. `sdd-archive` validates final state before closing cycle.

Before syncing specs or moving archive, inspect tasks artifact:

- **engram**: read full `sdd/{change-name}/tasks` observation.
- **openspec/hybrid**: read `openspec/changes/{change-name}/tasks.md`.

Unchecked impl task (`- [ ]`)?

1. STOP, return `blocked`. No sync, move, or completion claim.
2. Report: `sdd-apply` must rerun or correct so persisted task artifact marks completion.
3. Only proceed if orchestrator explicitly instructs stale-checkbox reconciliation AND `apply-progress`/`verify-report` prove completion. Record exact reason in archive report.

Archived audit trail MUST NOT contain stale unchecked tasks. Internal todo ≠ evidence. Persisted SDD task artifact = source of truth.

### Strict-vs-OpenSpec Archive Policy

OpenSpec permits archiving with incomplete artifacts after user confirmation. gentle-ai is stricter:

- Incomplete impl tasks block archive unless stale checkboxes with apply-progress/verify-report proof.
- CRITICAL verify-report issues always block archive. No override.
- `sdd-archive` does not own normal task completion. `sdd-apply` owns checkboxes. Archive only does exceptional mechanical reconciliation with proof.
- Missing proposal/spec/design artifacts: report. Continue only when user explicitly chooses intentional partial archive + archive report records what was missing.

### Action Context Guard

- `actionContext.mode: workspace-planning` → STOP. No workspace-to-local archive moves or linked-repo edits.
- `allowedEditRoots` present → archive ops stay inside those roots.

## What to Do

### Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Sync Delta Specs to Main Specs

Do NOT start until **Task Completion Gate** passes.

**IF mode is `engram`:** Skip filesystem sync — artifacts in Engram only. Archive report (Step 5) records all IDs.

**IF mode is `none`:** Skip — no artifacts.

**IF mode is `openspec` or `hybrid`:** For each delta spec in `openspec/changes/{change-name}/specs/`:

#### If Main Spec Exists (`openspec/specs/{domain}/spec.md`)

Read main spec, apply delta:

```
FOR EACH delta section:
├── ADDED → Append to main spec's Requirements
├── MODIFIED → Replace matching requirement in main spec
├── REMOVED → Delete from main spec (keep Reason/Migration)
└── RENAMED → Rename requirement, preserve scenarios unless delta modifies them
```

**Merge rules:**
- Match by requirement name (`### Requirement: Name`)
- Preserve requirements NOT in delta
- Maintain markdown formatting + heading hierarchy
- REMOVED: need `(Reason: ...)` + `(Migration: ...)` in delta before deleting
- RENAMED: old + new names must be explicit in delta

#### If Main Spec Does NOT Exist

Delta spec IS a full spec. Copy directly:

```bash
openspec/changes/{change-name}/specs/{domain}/spec.md → openspec/specs/{domain}/spec.md
```

### Step 3: Move to Archive

**IF mode is `engram`:** Skip. Archive report in Engram = audit trail.

**IF mode is `none`:** Skip.

**IF mode is `openspec` or `hybrid`:** Move entire change folder to archive:

```
openspec/changes/{change-name}/ → openspec/changes/archive/YYYY-MM-DD-{change-name}/
```

Use today's ISO date (e.g., `2026-02-16`).

### Step 4: Verify Archive

**IF mode is `openspec` or `hybrid`:** Confirm:
- [ ] Main specs updated correctly
- [ ] Change folder moved to archive
- [ ] Archive has all artifacts (proposal, specs, design, tasks)
- [ ] Archived `tasks.md` has no unchecked impl tasks (unless orchestrator approved stale-checkbox reconciliation with apply-progress/verify-report proof)
- [ ] Active changes dir no longer has this change

**IF mode is `engram`:** Confirm all observation IDs recorded in archive report + tasks observation has no unchecked impl tasks (unless orchestrator approved reconcilation with proof).

**IF mode is `none`:** Skip — no persisted artifacts.

### Step 5: Persist Archive Report

**MANDATORY — do NOT skip.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `archive-report`
- topic_key: `sdd/{change-name}/archive-report`
- type: `architecture`

### Step 6: Return Summary

Return to orchestrator:

```markdown
## Change Archived

**Change**: {change-name}
**Archived to**: `openspec/changes/archive/{YYYY-MM-DD}-{change-name}/` (openspec/hybrid) | Engram archive report (engram) | inline (none)

### Specs Synced
| Domain | Action | Details |
|--------|--------|---------|
| {domain} | Created/Updated | {N added, M modified, K removed} |

### Archive Contents
- proposal.md ✅
- specs/ ✅
- design.md ✅
- tasks.md ✅ ({N}/{N} tasks complete)

### Source of Truth Updated
- `openspec/specs/{domain}/spec.md`

### SDD Cycle Complete
Planned → implemented → verified → archived. Ready for next change.
```

## Rules

- NEVER archive with CRITICAL verification issues
- User approves non-critical partial archive or stale-checkbox reconciliation? Record exact reason in archive report, mark as intentional-with-warnings
- NEVER archive while `tasks.md`/tasks observation has stale unchecked impl tasks
- ALWAYS sync delta specs BEFORE moving to archive
- Merging into existing specs: PRESERVE requirements not in delta
- Archive folder prefix: ISO date (YYYY-MM-DD)
- Destructive merge (removing large sections)? WARN orchestrator, ask confirmation
- Archive = AUDIT TRAIL. Never delete or modify.
- `openspec/changes/archive/` missing? Create it.
- Apply `rules.archive` from `openspec/config.yaml`
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.

---
name: sdd-apply
description: "Implement SDD tasks from specs and design. Trigger: orchestrator launches apply for one or more change tasks."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "3.0"
  delegate_only: true
---

## Executor Override

If you ARE the sub-agent (NOT the orchestrator), the gate below does NOT apply to you. Continue with the phase work below. Do NOT delegate. Do NOT call the Skill tool. You are the executor — execute.

> **ORCHESTRATOR GATE**: If you loaded this skill via the `skill()` tool, you are
> the ORCHESTRATOR — STOP. Do NOT execute these instructions inline. Delegate to
> the dedicated `sdd-apply` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If Spanish technical artifacts are explicitly requested, use neutral/professional Spanish unless the user explicitly asks for a regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; Spanish comments default to neutral/professional Spanish unless the user or target context clearly calls for regional tone.

## Purpose

IMPLEMENTATION sub-agent. Receive specific tasks from tasks/artifacts. Write code. Follow specs and design strictly.

## What You Receive

From orchestrator:
- Change name
- Task(s) to implement (e.g., "Phase 1, tasks 1.1-1.3")
- Artifact store mode (`engram | openspec | hybrid | none`)
- Structured status from `skills/_shared/sdd-status-contract.md`: `schemaName`, `planningHome`, `changeRoot`, `artifactPaths`, `contextFiles`, `applyState`, task progress, dependency states, `actionContext`
- Delivery strategy + resolved workload decision (`ask-on-risk | auto-chain | single-pr | exception-ok`, plus PR slice or `size:exception`)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/proposal`, `sdd/{change-name}/spec`, `sdd/{change-name}/design`, `sdd/{change-name}/tasks` (all required, keep tasks ID for updates). Mark tasks complete via `mem_update(id: {tasks-observation-id}, content: "...")`. Save progress as `sdd/{change-name}/apply-progress`.
- **openspec**: Read + follow `skills/_shared/openspec-convention.md`. Update `tasks.md` with `[x]`.
- **hybrid**: Follow BOTH — persist to Engram (`mem_update` tasks) AND update `tasks.md` on filesystem.
- **none**: Return progress only. No project artifact updates.

## Status and Workspace Guard

Before reading or writing code, consume structured status (from orchestrator or built from artifacts).

- `applyState: blocked` → STOP, return `blocked` with missing artifacts/unsafe context.
- `applyState: all_done` → no edits. Return `success`, `next_recommended: sdd-verify` or `sdd-archive`.
- `applyState: ready` → proceed on assigned pending tasks only.
- Read context from `contextFiles`/`artifactPaths` — not fixed filenames.
- `actionContext.mode: workspace-planning` AND `allowedEditRoots` empty → STOP. Linked repos/folders = read-only planning context.
- `allowedEditRoots` present → edit only under those roots. Edit outside → STOP, report unsafe path.

## What to Do

### Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Read Context

Before writing code:
1. Read structured status, confirm `applyState: ready`
2. Read all applicable artifact paths/topics in `contextFiles`
3. Read specs — WHAT code must do
4. Read design — HOW to structure code
5. Read existing code in affected files — current patterns
6. Check project coding conventions from `config.yaml`

#### Step 2a: Enforce Review Workload Decision

Before implementing, inspect tasks artifact for `Review Workload Forecast`.

Forecast says any of:
- `400-line budget risk: High`
- `Chained PRs recommended: Yes`
- `Decision needed before apply: Yes`

→ MUST confirm orchestrator/user provided resolved delivery path:

1. **`auto-chain` or chosen chained/stacked PR mode**: implement only assigned work-unit slice. Keep scope autonomous. Report PR boundary. Follow `Chain strategy` from tasks artifact (`stacked-to-main` or `feature-branch-chain`).
2. **`exception-ok` or single PR with exception**: continue only if prompt explicitly says maintainer accepts `size:exception`.
3. **`single-pr` above budget**: continue only after prompt explicitly records `size:exception`.

Also check `Chain strategy` in tasks artifact. Present and not `pending`? Follow consistently:
- `stacked-to-main`: each PR targets previous PR's branch (or `main` after previous merges).
- `feature-branch-chain`: PR#1 targets tracker branch, later PRs target previous PR branch. Tracker PR aggregates to `main`. Child PR diffs stay focused on current work unit, never target `main` directly.

No delivery decision or chain strategy present? STOP before writing code. Return `blocked` with: `Workload decision required before apply: estimated work may exceed 400 changed lines. Ask the user which chain strategy to use (stacked-to-main, feature-branch-chain, or size-exception).`

#### Step 2b: Read Previous Apply-Progress (if exists)

Before starting, check for existing apply-progress:

1. `mem_search(query: "sdd/{change-name}/apply-progress", project: "{project}")`
2. Found? `mem_get_observation(id)` → full content
3. Parse completed tasks
4. Skip them — start from first incomplete
5. In Step 6, MERGE: previously completed + newly completed in single artifact

**CRITICAL**: Orchestrator says previous progress exists → MUST read it. Overwrite without reading = permanent loss of prior completed work.

### Step 3: Read Testing Capabilities and Resolve Mode

Read the cached testing capabilities to determine implementation mode:

```
Read testing capabilities from:
├── engram: mem_search("sdd/{project}/testing-capabilities") → mem_get_observation(id)
├── openspec: openspec/config.yaml → strict_tdd + testing section
└── Fallback: check project files directly (package.json, go.mod, etc.)

Resolve mode:
├── IF strict_tdd: true AND test runner exists
│   └── STRICT TDD MODE → Load and follow strict-tdd.md module
│       (read the file: skills/sdd-apply/strict-tdd.md)
│
├── IF strict_tdd: false OR no test runner
│   └── STANDARD MODE → use Step 4 below (no TDD module loaded)
│
└── Cache the resolved mode for the return summary
```

**Key principle**: Strict TDD not active → ZERO TDD instructions loaded. `strict-tdd.md` never read, never processed, zero tokens.

#### Hard Gate (Strict TDD Only)

Strict TDD active (orchestrator injection or self-discovery):
- MUST produce **TDD Cycle Evidence** table in apply-progress artifact
- Each task row: RED (test first) → GREEN (passes) → REFACTOR columns
- Complete task without tests first → mark FAILED in evidence table
- Verify phase REJECTS work if TDD Evidence table missing/incomplete

**No silent fallback.** Strict TDD resolved as active → follow it or report failure. No quiet switch to Standard Mode.

### Step 4: Implement Tasks (Standard Workflow)

Use when Strict TDD Mode is NOT active:

```
FOR EACH TASK:
├── Read task description
├── Read relevant spec scenarios (acceptance criteria)
├── Read design decisions (constrain approach)
├── Read existing code patterns (match project style)
├── Write code
├── Mark task [x] in persisted tasks artifact immediately
└── Note issues/deviations
```

### Step 5: Mark Tasks Complete

Update `tasks.md` — `- [ ]` → `- [x]` for completed tasks:

```markdown
## Phase 1: Foundation

- [x] 1.1 Create `internal/auth/middleware.go` with JWT validation
- [x] 1.2 Add `AuthConfig` struct to `internal/config/config.go`
- [ ] 1.3 Add auth routes to `internal/server/server.go`  ← still pending
```

### Step 6: Persist Progress

**MANDATORY — do NOT skip.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `apply-progress`
- topic_key: `sdd/{change-name}/apply-progress`
- type: `architecture`
- Also update tasks artifact with `[x]` via `mem_update` (engram) or file edit (openspec/hybrid).

#### Merge Protocol

Saving apply-progress after Step 2b read:
1. Artifact MUST include ALL previously completed tasks (status + evidence) PLUS new completions
2. Final artifact = cumulative state across ALL batches
3. Same structure, no completed task lost from prior batches

### Step 7: Return Summary

Before returning, re-read persisted tasks artifact. Every completed task must be `[x]` there. Artifact shows `- [ ]` for completed work? Fix checkbox before returning. Do NOT report `Ready for verify` when work only reflected in internal todos or apply-progress.

Return to the orchestrator:

```markdown
## Implementation Progress

**Change**: {change-name}
**Mode**: {Strict TDD | Standard}

### Completed Tasks
- [x] {task 1.1 description}
- [x] {task 1.2 description}

### Files Changed
| File | Action | What Was Done |
|------|--------|---------------|
| `path/to/file.ext` | Created | {brief description} |
| `path/to/other.ext` | Modified | {brief description} |

{IF Strict TDD Mode → include TDD Cycle Evidence table from strict-tdd.md}

### Deviations from Design
{List any places where the implementation deviated from design.md and why.
If none, say "None — implementation matches design."}

### Issues Found
{List any problems discovered during implementation.
If none, say "None."}

### Remaining Tasks
- [ ] {next task}
- [ ] {next task}

### Workload / PR Boundary
- Mode: {single PR | chained PR slice | stacked PR slice | size:exception}
- Current work unit: {unit name or "N/A"}
- Boundary: {what this apply batch starts from and ends with}
- Estimated review budget impact: {brief note}

### Status
{N}/{total} tasks complete. {Ready for next batch / Ready for verify / Blocked by X}
```

## Rules

- Read specs before implementing (acceptance criteria)
- Follow design decisions — no freelancing
- Match existing code patterns and conventions
- Consume/produce structured status before impl. No inference from conversation
- STOP on `applyState: blocked`. STOP on unsafe `actionContext`/edit roots
- `openspec` mode: mark tasks `[x]` AS you go, not end
- Before return: re-read tasks artifact. Completed must be `[x]`. Internal todos ≠ evidence
- Design wrong/incomplete? NOTE in return summary — no silent deviation
- Task blocked? STOP, report back
- Workload forecast needs decision and none provided? STOP before writing code
- Chained/stacked PR slice: autonomous batch, verification included, clear rollback
- `size:exception`: state explicitly in apply-progress + return summary
- NEVER implement unassigned tasks
- Step 1 handles skill loading — follow loaded skills strictly
- Apply `rules.apply` from `openspec/config.yaml`
- Strict TDD active (Step 3): load `strict-tdd.md`, follow its cycle INSTEAD of Step 4
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.

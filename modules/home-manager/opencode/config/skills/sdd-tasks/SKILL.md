---
name: sdd-tasks
description: "Break an SDD change into implementation tasks. Trigger: orchestrator launches task planning for a change."
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
> the dedicated `sdd-tasks` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If Spanish technical artifacts are explicitly requested, use neutral/professional Spanish unless the user explicitly asks for a regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; Spanish comments default to neutral/professional Spanish unless the user or target context clearly calls for regional tone.

## Purpose

TASK BREAKDOWN sub-agent. Take proposal, specs, design → produce `tasks.md` with concrete, actionable steps by phase.

## What You Receive

From orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)
- Delivery strategy (`ask-on-risk | auto-chain | single-pr | exception-ok`)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/proposal` (required), `sdd/{change-name}/spec` (required), `sdd/{change-name}/design` (required). Save as `sdd/{change-name}/tasks`.
- **openspec**: Read + follow `skills/_shared/openspec-convention.md`.
- **hybrid**: Follow BOTH — persist to Engram AND write `tasks.md`. Retrieve deps from Engram (primary), filesystem fallback.
- **none**: Return result only. No files.

## What to Do

### Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Analyze the Design

From design, identify:
- Files to create/modify/delete
- Dependency order
- Testing requirements per component

### Step 3: Write tasks.md

**IF mode is `openspec` or `hybrid`:** Create the task file:

```
openspec/changes/{change-name}/
├── proposal.md
├── specs/
├── design.md
└── tasks.md               ← You create this
```

**IF mode is `engram` or `none`:** Do NOT create any `openspec/` directories or files. Compose the tasks content in memory — you will persist it in Step 4.

#### Task File Format

```markdown
# Tasks: {Change Title}

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | <rough estimate or range> |
| 400-line budget risk | Low / Medium / High |
| Chained PRs recommended | Yes / No |
| Suggested split | <single PR or PR 1 → PR 2 → PR 3> |
| Delivery strategy | <ask-on-risk / auto-chain / single-pr / exception-ok> |
| Chain strategy | <stacked-to-main / feature-branch-chain / size-exception / pending> |

Decision needed before apply: <Yes|No>
Chained PRs recommended: <Yes|No>
Chain strategy: <stacked-to-main|feature-branch-chain|size-exception|pending>
400-line budget risk: <Low|Medium|High>

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | <standalone deliverable> | PR 1 | <base branch; tests/docs included> |
| 2 | <standalone deliverable> | PR 2 | <immediate parent/base branch boundary; depends on PR 1 or independent> |

## Phase 1: {Phase Name} (e.g., Infrastructure / Foundation)

- [ ] 1.1 {Concrete action — what file, what change}
- [ ] 1.2 {Concrete action}
- [ ] 1.3 {Concrete action}

## Phase 2: {Phase Name} (e.g., Core Implementation)

- [ ] 2.1 {Concrete action}
- [ ] 2.2 {Concrete action}
- [ ] 2.3 {Concrete action}
- [ ] 2.4 {Concrete action}

## Phase 3: {Phase Name} (e.g., Testing / Verification)

- [ ] 3.1 {Write tests for ...}
- [ ] 3.2 {Write tests for ...}
- [ ] 3.3 {Verify integration between ...}

## Phase 4: {Phase Name} (e.g., Cleanup / Documentation)

- [ ] 4.1 {Update docs/comments}
- [ ] 4.2 {Remove temporary code}
```

### Task Writing Rules

Each task MUST be:

| Criteria | Example ✅ | Anti-example ❌ |
|----------|-----------|----------------|
| **Specific** | "Create `internal/auth/middleware.go` with JWT validation" | "Add auth" |
| **Actionable** | "Add `ValidateToken()` method to `AuthService`" | "Handle tokens" |
| **Verifiable** | "Test: `POST /login` returns 401 without token" | "Make sure it works" |
| **Small** | One file or one logical unit of work | "Implement the feature" |

### Review Workload Forecast Rules

Before finalizing tasks, estimate if implementation may exceed **400 changed-line budget** (`additions + deletions`). Planning guard, not exact diff.

Signals: file count, phases, integration points, tests, docs, generated artifacts, migrations, cross-cutting concerns.

Estimate **High** or >400 lines:

1. Mark `Chained PRs recommended: Yes`.
2. Split tasks into **work units** for chained/stacked PRs.
3. Each suggested PR: clear start, finish, verification, autonomous scope.
4. **Ask user chain strategy** (team decision):
   - **Stacked PRs to main** — each PR merges to main in order. Speed-first, independent slices.
   - **Feature Branch Chain** — tracker branch accumulates integration. PR#1 targets tracker, later PRs target previous PR branch. Only tracker merges to main. Rollback control + coordinated releases.
   - **size:exception** — single PR with maintainer approval. Generated code/migrations/vendor diffs.
5. Set `Decision needed before apply` from delivery strategy:
   - `ask-on-risk`: `Yes`
   - `auto-chain`: `No`
   - `single-pr`: `Yes` — must require `size:exception` before apply
   - `exception-ok`: `No` — maintainer accepted `size:exception`

Forecast near top of tasks artifact (not buried in prose).

MUST include plain-text guard lines for downstream literal matching:

```text
Decision needed before apply: Yes|No
Chained PRs recommended: Yes|No
Chain strategy: stacked-to-main|feature-branch-chain|size-exception|pending
400-line budget risk: Low|Medium|High
```

Table OK for readability, but plain-text lines = guard contract.

For `feature-branch-chain`: suggested work units SHOULD name base boundary (PR#1 base = tracker, PR#2 base = PR#1, etc.). Child PR shows previous changes? Wrong base — retarget/rebase before review.

### Phase Organization

```
Phase 1: Foundation / Infrastructure — types, interfaces, DB, config. Things other tasks depend on.
Phase 2: Core Implementation — main logic, business rules, core behavior.
Phase 3: Integration / Wiring — connect components, routes, UI. Make everything work.
Phase 4: Testing — unit, integration, e2e. Verify against spec scenarios.
Phase 5: Cleanup (if needed) — docs, remove dead code, polish.
```

### Step 4: Persist Artifact

**This step is MANDATORY — do NOT skip it.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `tasks`
- topic_key: `sdd/{change-name}/tasks`
- type: `architecture`

### Step 5: Return Summary

Return to the orchestrator:

```markdown
## Tasks Created

**Change**: {change-name}
**Location**: `openspec/changes/{change-name}/tasks.md` (openspec/hybrid) | Engram `sdd/{change-name}/tasks` (engram) | inline (none)

### Breakdown
| Phase | Tasks | Focus |
|-------|-------|-------|
| Phase 1 | {N} | {Phase name} |
| Phase 2 | {N} | {Phase name} |
| Phase 3 | {N} | {Phase name} |
| Total | {N} | |

### Implementation Order
{Brief description of the recommended order and why}

### Review Workload Forecast
- Estimated changed lines: {estimate or range}
- 400-line budget risk: {Low | Medium | High}
- Chained PRs recommended: {Yes | No}
- Delivery strategy: {ask-on-risk | auto-chain | single-pr | exception-ok}
- Decision needed before apply: {Yes | No}
- Suggested work-unit PR split: {brief list or "Not needed"}

### Next Step
{Ready for implementation (sdd-apply) OR ask the user whether to use chained PRs before sdd-apply.}
```

## Rules

- Concrete file paths in every task
- Ordered by dependency — Phase 1 must not depend on Phase 2
- Testing tasks reference specific spec scenarios
- One session per task. Too big? Split.
- Hierarchical numbering: 1.1, 1.2, 2.1, 2.2...
- No vague tasks ("implement feature", "add tests")
- Apply `rules.tasks` from `openspec/config.yaml`
- TDD project: test-first tasks → RED (failing test) → GREEN (pass) → REFACTOR (clean)
- **Size budget**: Tasks ≤ 530 words. Each task 1-2 lines. Checklist format, no paragraphs.
- **Review workload guard**: ALWAYS include Review Workload Forecast. >400 lines? Recommend chained PRs, honor delivery strategy.
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.

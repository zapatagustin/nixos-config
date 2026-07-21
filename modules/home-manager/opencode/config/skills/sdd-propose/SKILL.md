---
name: sdd-propose
description: "Create an SDD change proposal with intent, scope, and approach. Trigger: orchestrator launches proposal work for a change."
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
> the dedicated `sdd-propose` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If Spanish technical artifacts are explicitly requested, use neutral/professional Spanish unless the user explicitly asks for a regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; Spanish comments default to neutral/professional Spanish unless the user or target context clearly calls for regional tone.

## Purpose

PROPOSAL sub-agent. Take exploration analysis (or direct input), produce structured `proposal.md` inside change folder.

## What You Receive

From orchestrator:
- Change name (e.g., "add-dark-mode")
- Exploration (from sdd-explore) OR direct user description
- Artifact store mode (`engram | openspec | hybrid | none`)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/explore` (optional), `sdd-init/{project}` (optional). Save as `sdd/{change-name}/proposal`.
- **openspec**: Read + follow `skills/_shared/openspec-convention.md`.
- **hybrid**: Follow BOTH — persist to Engram AND filesystem. Retrieve deps from Engram (primary), filesystem fallback.
- **none**: Return result only. No files.
- Never force `openspec/` unless user requested file-based persistence or mode is `hybrid`.

## What to Do

### Step 0: Shape Proposal in Interactive Mode

- Interactive mode: do NOT let executor silently decide proposal is "clear enough". Offer proposal question round before finalizing. Questions improve PRD/proposal — uncover business rules, implications, impact, edge cases, tradeoffs. Let user answer, skip, correct framing, or request second round.
- Focus on business/product/PRD understanding, not harness mechanics. Cover smallest useful subset of:
   1. Business problem — pain, opportunity, cost making change worth doing now
   2. Target users/situations — who affected, when, urgency
   3. Business rules — policies, permissions, thresholds, compliance/security invariants
   4. Product outcome — what should feel/work/be possible after change
   5. Current-state gap — what is wrong/inconsistent/missing/ad hoc today
   6. Implications/impact — teams, workflows, UX, support, ops affected
   7. Edge cases — empty states, partial data, failures, permissions, migrations, conflicting needs
   8. Decision gaps — unknowns making proposal ambiguous/risky/easy to overbuild
   9. Scope boundaries/non-goals — first slice, later refinement, related but unchanged
   10. Business risk/tradeoff — downside if wrong direction chosen
- Prefer 3-5 questions per round. After first answers, summarize assumptions, ask if user wants correction or second round. Do NOT ask about test commands, PR shape, budget, or harness decisions unless user explicitly asks. Blocked from direct asking? Write `## Proposal question round` in proposal result with questions + assumptions needing review.

### Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Create Change Directory

**IF mode is `openspec` or `hybrid`:** create change folder:

```
openspec/changes/{change-name}/
└── proposal.md
```

**IF mode is `engram` or `none`:** No `openspec/` dirs. Skip.

### Step 3: Read Existing Specs

**IF mode is `openspec` or `hybrid`:** `openspec/specs/` has relevant specs? Read them to understand current behavior.

**IF mode is `engram`:** Context already retrieved from Engram in Persistence Contract. Skip filesystem reads.

**IF mode is `none`:** Skip — no existing specs.

### Step 4: Write proposal.md

```markdown
# Proposal: {Change Title}

## Intent

{What problem are we solving? Why does this change need to happen?
Be specific about the user need or technical debt being addressed.}

## Scope

### In Scope
- {Concrete deliverable 1}
- {Concrete deliverable 2}
- {Concrete deliverable 3}

### Out of Scope
- {What we're explicitly NOT doing}
- {Future work that's related but deferred}

## Capabilities

> This section is the CONTRACT between proposal and specs phases.
> The sdd-spec agent reads this to know exactly which spec files to create or update.
> Research `openspec/specs/` before filling this in.

### New Capabilities
<!-- Capabilities being introduced. Each becomes a new `openspec/specs/<name>/spec.md`.
     Use kebab-case names (e.g., user-auth, data-export, api-rate-limiting).
     Leave empty if no new capabilities. -->
- `<capability-name>`: <brief description of what this capability covers>

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing (not just implementation).
     Only list here if spec-level behavior changes. Each needs a delta spec.
     Use existing spec names from openspec/specs/. Leave empty if none. -->
- `<existing-capability-name>`: <what requirement is changing>

## Approach

{High-level technical approach. How will we solve this?
Reference the recommended approach from exploration if available.}

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `path/to/area` | New/Modified/Removed | {What changes} |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| {Risk description} | Low/Med/High | {How we mitigate} |

## Rollback Plan

{How to revert if something goes wrong. Be specific.}

## Dependencies

- {External dependency or prerequisite, if any}

## Success Criteria

- [ ] {How do we know this change succeeded?}
- [ ] {Measurable outcome}
```

### Step 5: Persist Artifact

**This step is MANDATORY — do NOT skip it.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `proposal`
- topic_key: `sdd/{change-name}/proposal`
- type: `architecture`

### Step 6: Return Summary

Return to the orchestrator:

```markdown
## Proposal Created

**Change**: {change-name}
**Location**: `openspec/changes/{change-name}/proposal.md` (openspec/hybrid) | Engram `sdd/{change-name}/proposal` (engram) | inline (none)

### Summary
- **Intent**: {one-line summary}
- **Scope**: {N deliverables in, M items deferred}
- **Approach**: {one-line approach}
- **Risk Level**: {Low/Medium/High}

### Next Step
Ready for specs (sdd-spec) or design (sdd-design).
```

## Rules

- `openspec` mode: ALWAYS create `proposal.md`
- Change dir exists with proposal? READ first, then UPDATE
- Proposal CONCISE — thinking tool, not novel
- Every proposal needs rollback plan + success criteria
- Concrete file paths in "Affected Areas" when possible
- Apply `rules.proposal` from `openspec/config.yaml`
- **ALWAYS fill Capabilities section** — contract with sdd-spec. Research `openspec/specs/` first for correct capability names.
- New Capabilities → `openspec/specs/<name>/spec.md` (new full spec)
- Modified Capabilities → delta spec in change folder
- Nothing changes at spec level (refactor/config)? Write "None" under both sub-sections — no template placeholders
- **Size budget**: Proposal ≤ 450 words. Bullets + tables over prose. Headers organize, not explain.
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.

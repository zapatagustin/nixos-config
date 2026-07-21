---
name: sdd-explore
description: "Explore SDD ideas before committing to a change. Trigger: orchestrator launches exploration or requirement clarification."
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
> the dedicated `sdd-explore` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If Spanish technical artifacts are explicitly requested, use neutral/professional Spanish unless the user explicitly asks for a regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; Spanish comments default to neutral/professional Spanish unless the user or target context clearly calls for regional tone.

## Purpose

EXPLORATION sub-agent. Investigate codebase, compare approaches, return structured analysis. Default: research + report only. Create `exploration.md` only when tied to a named change.

## What You Receive

From orchestrator:
- Topic/feature to explore
- Artifact store mode (`engram | openspec | hybrid | none`)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Optionally read `sdd-init/{project}` for context. Save as `sdd/{change-name}/explore` (or `sdd/explore/{topic-slug}` standalone).
- **openspec**: Read + follow `skills/_shared/openspec-convention.md`.
- **hybrid**: Follow BOTH — persist to Engram AND filesystem.
- **none**: Return result only.

### Retrieving Context

> Follow **Section B** from `skills/_shared/sdd-phase-common.md`.

- **engram**: Search `sdd-init/{project}` (project context), optionally `sdd/` (existing artifacts).
- **openspec**: Read `openspec/config.yaml` and `openspec/specs/`.
- **none**: Use context from orchestrator prompt.

## What to Do

### Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Understand the Request

Parse exploration goal:
- New feature? Bug fix? Refactor?
- Domain?

### Step 2.5: Recall Prior Learnings (compounding step)

Before reading code, mine what was already learned so you do not re-solve solved problems or
repeat a known dead end:
- `mem_search` for prior bugfixes, decisions, and patterns in the affected area (use the
  feature/module/domain keywords from Step 2).
- Pull full content with `mem_get_observation` for relevant hits.
- Fold the recalled root causes, gotchas, and rejected approaches into the analysis, and cite
  them explicitly in the Step 6 output.

If Engram is unavailable, skip this step (do not fail the phase).

### Step 3: Investigate the Codebase

Read relevant code:
- Current architecture, patterns
- Affected files/modules
- Existing behavior
- Constraints/risks

```
INVESTIGATE:
├── Read entry points and key files
├── Search for related functionality
├── Check existing tests (if any)
├── Look for patterns already in use
└── Identify dependencies and coupling
```

### Step 4: Analyze Options

Multiple approaches? Compare:

| Approach | Pros | Cons | Complexity |
|----------|------|------|------------|
| Option A | ... | ... | Low/Med/High |
| Option B | ... | ... | Low/Med/High |

### Step 5: Persist Artifact

**MANDATORY when tied to named change — do NOT skip.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `explore`
- topic_key: `sdd/{change-name}/explore` (or `sdd/explore/{topic-slug}` standalone)
- type: `architecture`

### Step 6: Return Structured Analysis

Return EXACTLY this format to orchestrator (write same to `exploration.md` if saving):

```markdown
## Exploration: {topic}

### Current State
{How system works today relevant to topic}

### Affected Areas
- `path/to/file.ext` — {why affected}
- `path/to/other.ext` — {why affected}

### Approaches
1. **{Name}** — {brief description}
   - Pros: {list}
   - Cons: {list}
   - Effort: {Low/Medium/High}

2. **{Name}** — {brief description}
   - Pros: {list}
   - Cons: {list}
   - Effort: {Low/Medium/High}

### Recommendation
{Recommended approach + why}

### Risks
- {Risk 1}
- {Risk 2}

### Ready for Proposal
{Yes/No + what orchestrator should tell user}
```

## Rules

- ONLY file MAY create: `exploration.md` inside change folder (if change name provided)
- DO NOT modify existing code or files
- Read real code — no guessing
- Analysis CONCISE — orchestrator needs summary, not novel
- Not enough info? Say so clearly
- Too vague? Say what clarification needed
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.

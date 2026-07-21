---
name: sdd-spec
description: "Write SDD delta specs with requirements and scenarios. Trigger: orchestrator launches spec work for a change."
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
> the dedicated `sdd-spec` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If Spanish technical artifacts are explicitly requested, use neutral/professional Spanish unless the user explicitly asks for a regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; Spanish comments default to neutral/professional Spanish unless the user or target context clearly calls for regional tone.

## Purpose

SPECIFICATION sub-agent. Take proposal, produce delta specs — structured requirements + scenarios for ADDED, MODIFIED, REMOVED, or RENAMED behavior.

## What You Receive

From orchestrator:
- Change name
- Artifact store mode (`engram | openspec | hybrid | none`)

## Execution and Persistence Contract

> Follow **Section B** (retrieval) and **Section C** (persistence) from `skills/_shared/sdd-phase-common.md`.

- **engram**: Read `sdd/{change-name}/proposal` (required). Multiple domains? Concatenate into single artifact with domain headers. Save as `sdd/{change-name}/spec`.
- **openspec**: Read + follow `skills/_shared/openspec-convention.md`.
- **hybrid**: Follow BOTH — persist to Engram (single concatenated) AND write domain files to filesystem.
- **none**: Return result only. No files.

## What to Do

### Step 1: Load Skills
Follow **Section A** from `skills/_shared/sdd-phase-common.md`.

### Step 2: Identify Affected Domains

Read proposal's **Capabilities section** — primary contract:

```
FOR EACH "New Capabilities" entry:
├── NEW full spec: openspec/specs/<capability-name>/spec.md
└── Complete spec (not delta) — no existing behavior to reference

FOR EACH "Modified Capabilities" entry:
├── DELTA spec: openspec/changes/{change-name}/specs/<capability-name>/spec.md
└── Read existing openspec/specs/<capability-name>/spec.md first — delta modifies it
```

No Capabilities section (older format)? Fall back to inferring from "Affected Areas". Prefer explicit Capabilities mapping when present.

### Step 3: Read Existing Specs

**IF mode is `openspec` or `hybrid`:** `openspec/specs/{domain}/spec.md` exists? Read it for CURRENT behavior. Delta specs describe CHANGES.

**IF mode is `engram`:** Specs already retrieved from Engram in Persistence Contract. Skip filesystem reads.

**IF mode is `none`:** Skip — no existing specs.

### Step 4: Write Delta Specs

**IF mode is `openspec` or `hybrid`:** Create specs inside change folder:

```
openspec/changes/{change-name}/
├── proposal.md              ← (already exists)
└── specs/
    └── {domain}/
        └── spec.md          ← Delta spec
```

**IF mode is `engram` or `none`:** No `openspec/` dirs or files. Compose spec content in memory — persist in Step 5.

#### MODIFIED Requirements Workflow (CRITICAL — read before writing deltas)

When writing `## MODIFIED Requirements`:

```
1. Locate requirement in openspec/specs/{domain}/spec.md
2. COPY ENTIRE requirement block — from `### Requirement:` through ALL scenarios
3. PASTE under `## MODIFIED Requirements`
4. EDIT copy for new behavior
5. Add "(Previously: {one-line summary of change})" under requirement text

Why copy-full-then-edit?
→ Archive REPLACES requirement in main specs with MODIFIED block
→ Partial block → archive loses scenarios you didn't copy
→ Common pitfall: only writing changed scenario, losing rest
→ Adding NEW behavior without changing existing? Use ADDED instead
```

#### Delta Spec Format

```markdown
# Delta for {Domain}

## ADDED Requirements

### Requirement: {Requirement Name}

{Description using RFC 2119 keywords: MUST, SHALL, SHOULD, MAY}

The system {MUST/SHALL/SHOULD} {do something specific}.

#### Scenario: {Happy path scenario}

- GIVEN {precondition}
- WHEN {action}
- THEN {expected outcome}
- AND {additional outcome, if any}

#### Scenario: {Edge case scenario}

- GIVEN {precondition}
- WHEN {action}
- THEN {expected outcome}

## MODIFIED Requirements

### Requirement: {Existing Requirement Name}

{Full updated requirement text — replaces the existing one entirely}
(Previously: {what it was before, in one line})

#### Scenario: {Unchanged scenario — keep if still valid}

- GIVEN {precondition}
- WHEN {action}
- THEN {outcome}

#### Scenario: {Updated or new scenario}

- GIVEN {updated precondition}
- WHEN {updated action}
- THEN {updated outcome}

## REMOVED Requirements

### Requirement: {Requirement Being Removed}

(Reason: {why this requirement is being deprecated/removed})
(Migration: {what replaces it, or "None" if no migration is needed})

## RENAMED Requirements

### Requirement: {Old Requirement Name} → {New Requirement Name}

(Reason: {why the requirement is being renamed})
(Migration: {how references/tests/docs should update, or "None" if no migration is needed})
```

#### For NEW Specs (No Existing Spec)

If this is a completely new domain, create a FULL spec (not a delta):

```markdown
# {Domain} Specification

## Purpose

{High-level description of this spec's domain.}

## Requirements

### Requirement: {Name}

The system {MUST/SHALL/SHOULD} {behavior}.

#### Scenario: {Name}

- GIVEN {precondition}
- WHEN {action}
- THEN {outcome}
```

### Step 5: Persist Artifact

**MANDATORY — do NOT skip.**

Follow **Section C** from `skills/_shared/sdd-phase-common.md`.
- artifact: `spec`
- topic_key: `sdd/{change-name}/spec`
- type: `architecture`

### Step 6: Return Summary

Return to orchestrator:

```markdown
## Specs Created

**Change**: {change-name}

### Specs Written
| Domain | Type | Requirements | Scenarios |
|--------|------|-------------|-----------|
| {domain} | Delta/New | {N added, M modified, K removed} | {total} |

### Coverage
- Happy paths: {covered/missing}
- Edge cases: {covered/missing}
- Error states: {covered/missing}

### Next Step
Ready for design (sdd-design). Design exists? Ready for tasks (sdd-tasks).
```

## Rules

- Scenarios: Given/When/Then format
- Requirement strength: RFC 2119 keywords (MUST/SHALL/SHOULD/MAY)
- Read proposal **Capabilities section** first — tells exact spec files to create
- Existing specs exist? Write DELTA specs (ADDED/MODIFIED/REMOVED)
- No existing specs for domain? Write FULL spec
- Every requirement ≥ 1 scenario
- Happy path + edge cases both required
- Scenarios TESTABLE — each must support automated test
- No implementation details in specs. Specs = WHAT, not HOW
- **MODIFIED = FULL block** — copy entire requirement + all scenarios from main spec, then edit. Partial MODIFIED loses content at archive
- New behavior, no change to existing → use ADDED, not MODIFIED
- REMOVED: MUST include Reason, SHOULD include Migration when consumers/docs/tests affected
- RENAMED: MUST state old + new names, SHOULD include Migration guidance
- Apply `rules.specs` from `openspec/config.yaml`
- **Size budget**: Spec ≤ 650 words. Requirement tables over narrative. Each scenario: 3-5 lines max.
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.

## RFC 2119 Keywords Quick Reference

| Keyword | Meaning |
|---------|---------|
| **MUST / SHALL** | Absolute requirement |
| **MUST NOT / SHALL NOT** | Absolute prohibition |
| **SHOULD** | Recommended, but exceptions may exist with justification |
| **SHOULD NOT** | Not recommended, but may be acceptable with justification |
| **MAY** | Optional |

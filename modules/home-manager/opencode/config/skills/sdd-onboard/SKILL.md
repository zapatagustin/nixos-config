---
name: sdd-onboard
description: "Walk users through the SDD workflow on the real codebase. Trigger: orchestrator launches onboarding for the full SDD cycle."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "1.0"
  delegate_only: false
---

> **ORCHESTRATOR NOTE**: Execute INLINE by orchestrator. Interactive walkthrough — no sub-agent delegation.

## Executor Override

`sdd-onboard` sub-agent? Gate above doesn't apply. Execute. Don't delegate. Don't call Skill tool.

## Language Domain Contract

Generated artifacts default to English. Don't inherit user's conversational language or persona voice unless explicitly requested.

Spanish requested? Use neutral/professional Spanish unless user asks for regional variant.

Public comments follow target context language. User overrides win. Spanish defaults neutral/professional.

## Purpose

You're a sub-agent for ONBOARDING. Guide user through complete SDD cycle (explore→archive) using their actual codebase. Real change, real artifacts. Teach by doing.

## What You Receive

From orchestrator:
- Artifact store mode (`engram | openspec | hybrid | none`)
- Optional: suggested improvement area

## What to Do

### Phase 1: Welcome + Codebase Analysis

Greet, explain, scan for improvement opportunity.

Criteria:
- Small scope — one session (30-60 min)
- Low risk — no breaking changes, no data migrations
- Real value — genuinely useful
- Spec-worthy — ≥1 requirement + 2 scenarios
- Examples: missing validation, inconsistent errors, extractable utility, missing loading state, clear TODO

Present 2-3 options. Let user choose or suggest.

### Phase 2-9: Narrated SDD cycle

For each phase, narrate briefly (1-3 sentences), then execute phase behavior:

| Phase | Narration | Action |
|-------|-----------|--------|
| 2 Explore | "Step 1: Explore — investigate before commit." | Inline sdd-explore |
| 3 Propose | "Step 2: Propose — WHAT + WHY, contract for everything after." | Write proposal.md, let user review |
| 4 Specs | "Step 3: Specs — WHAT system does, testable terms." | Write delta specs |
| 5 Design | "Step 4: Design — HOW, decisions, rationale." | Write design.md |
| 6 Tasks | "Step 5: Tasks — concrete checkable steps." | Write tasks.md |
| 7 Apply | "Step 6: Apply — code guided by tasks+specs." | Implement tasks. If TDD: explain RED→GREEN→REFACTOR. |
| 8 Verify | "Step 7: Verify — check matches specs." | Inline sdd-verify |
| 9 Archive | "Step 8: Archive — merge deltas into main specs, close." | Inline sdd-archive |

Always ask before continuing past Phase 3.

### Phase 10: Summary

Recap: change name, artifacts, code changed, SDD cycle one-liner, when to use SDD, next steps.

## Rules

- REAL change, not demo. Production-quality artifacts + code.
- Keep narration SHORT (1-3 sentences). Teach, don't lecture.
- Ask before continuing past Phase 3.
- User picks own improvement? Validate fits "small + safe" criteria.
- Blocked? STOP and explain.
- Adapt tone to user experience.
- Follow format rules from individual skills.
- Return envelope per **Section D** from `skills/_shared/sdd-phase-common.md`.

---
name: sdd-verify
description: "Trigger: SDD verification phase, verify change. Execute tests and prove implementation matches specs, design, and tasks."
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
> the dedicated `sdd-verify` sub-agent using your platform's delegation primitive
> (e.g., `task(...)`, sub-agent invocation, etc.). This skill is for EXECUTORS
> only.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If Spanish technical artifacts are explicitly requested, use neutral/professional Spanish unless the user explicitly asks for a regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; Spanish comments default to neutral/professional Spanish unless the user or target context clearly calls for regional tone.

## Activation Contract

Run when orchestrator launches verification for SDD change. Quality gate: prove completion via source inspection + execution evidence.

Orchestrator provides structured status from `skills/_shared/sdd-status-contract.md`. Use `schemaName`, `planningHome`, `changeRoot`, `artifactPaths`, `contextFiles`, task progress, dependency states, `actionContext`.

## Hard Rules

- Read all `contextFiles` before judging. Full verification reads proposal, specs, design, tasks. Partial sets degrade as described.
- Execute tests. Static analysis alone ≠ verification.
- Spec scenario compliant only when covering test passed at runtime.
- Compare: specs first, design second, task completion third.
- Do NOT fix issues. Report for orchestrator/user.
- Persist `verify-report` per mode: Engram, openspec file, hybrid both, inline-only for `none`.
- Strict TDD active? Load `strict-tdd-verify.md`. Inactive? Never load.
- Return Section D envelope from `../_shared/sdd-phase-common.md`.

## Decision Gates

| Condition | Action |
|---|---|
| Orchestrator says `STRICT TDD MODE IS ACTIVE` | Treat as authoritative. |
| Cached/config `strict_tdd: true` and runner exists | Strict TDD verify; load module. |
| Strict TDD false or no runner | Standard verify; skip TDD checks. |
| `actionContext.mode: workspace-planning` | STOP. Full workspace verification not supported in this slice. |
| Only tasks artifact exists | Verify task completion only. Skip spec/design correctness. Record skipped. |
| Tasks + specs exist | Verify completeness + correctness. Skip design coherence. Record skipped. |
| Proposal/specs/design/tasks exist | Verify all dimensions. |
| Task incomplete | CRITICAL (core), WARNING (cleanup). |
| Test command exits non-zero | CRITICAL. |
| Spec scenario has no passing test | CRITICAL `UNTESTED` or `FAILING`. |
| Design deviation exists | WARNING unless it breaks a spec. |

## Execution Steps

1. Load skills via shared Section A.
2. Retrieve artifacts via Section B (persistence mode) or read `contextFiles` from structured status.
3. Resolve testing/TDD mode from cached capabilities/config/project files.
4. Count completed/incomplete tasks. Unchecked implementation task = CRITICAL, blocks archive.
5. Specs exist? Map each requirement/scenario to evidence + tests.
6. Design exists? Check decisions against changed code. Missing? Skip, record why.
7. Run test, build/type-check, coverage commands when available. Source inspection alone ≠ spec compliance.
8. Build behavioral compliance matrix from actual test results when specs/scenarios exist.
9. Persist + return verification report, including skipped dimensions for missing artifacts.

## Output Contract

Return `## Verification Report` with change, mode, completeness table, build/tests/coverage evidence, spec compliance matrix, correctness table, design coherence table, issues (CRITICAL/WARNING/SUGGESTION), final verdict `PASS`, `PASS WITH WARNINGS`, or `FAIL`.

## Graceful Artifact Handling

- **Tasks only**: verify objective task completion. No spec correctness or design coherence claims. All tasks checked, no runtime evidence → verdict `PASS WITH WARNINGS` (task completion only).
- **Tasks + specs**: verify task completeness + requirement/scenario correctness. Runtime test evidence required for full spec compliance. Missing covering tests = CRITICAL for required scenarios unless project config allows manual verification.
- **Full artifacts**: verify completeness, correctness, coherence.
- **Unchecked tasks**: always CRITICAL, even when other artifacts missing or warnings-only.

## References

- [references/report-format.md](references/report-format.md) — full report template, compliance statuses, and command evidence fields.
- [strict-tdd-verify.md](strict-tdd-verify.md) — load only when Strict TDD is active.
- `../_shared/sdd-phase-common.md` — skill loading, retrieval, persistence, and return envelope.

# Persistence Contract (shared across all SDD skills)

## Mode Resolution

Orchestrator passes `artifact_store.mode`: `engram | openspec | hybrid | none`.

Orchestrator ASKs user on first `/sdd-new`, `/sdd-ff`, or `/sdd-continue` per session. Choice cached.

Default: Engram available → `engram`. Otherwise → `none`.

## Mode Roles

- **`engram`**: Working memory between sessions. Upserts overwrite. No iteration history. Local only.
- **`openspec`**: Source of truth. Files in repo, git history, team-shareable, full audit trail.
- **`hybrid`**: Both. Files for team + engram for recovery. Higher token cost.
- **`none`**: Ephemeral. Lost when conversation ends.

### Mode Comparison

| Capability | `engram` | `openspec` | `hybrid` | `none` |
|------------|----------|------------|----------|--------|
| Cross-session recovery | ✅ | ❌ (needs git) | ✅ | ❌ |
| Compaction survival | ✅ | ❌ | ✅ | ❌ |
| Shareable with team | ❌ (local DB) | ✅ (files) | ✅ (files) | ❌ |
| Full iteration history | ❌ (upsert) | ✅ (git) | ✅ (files+git) | ❌ |
| Audit trail (archive) | Partial (report) | ✅ (folder) | ✅ (both) | ❌ |
| Project files created | Never | Yes | Yes | Never |

### `engram` mode limitation

Engram uses `topic_key`-based upserts. Re-running same phase for same change **overwrites** previous version — no revision history. Archive saves summary report, not full folder. For iteration history or team collab, use `openspec` or `hybrid`.

## Behavior Per Mode

| Mode | Read from | Write to | Project files |
|------|-----------|----------|---------------|
| `engram` | Engram | Engram | Never |
| `openspec` | Filesystem | Filesystem | Yes |
| `hybrid` | Engram (primary) + Filesystem (fallback) | Both | Yes |
| `none` | Orchestrator prompt context | Nowhere | Never |

### Hybrid Mode

Persists every artifact to BOTH Engram + OpenSpec:
- Engram: recovery, compaction survival, deterministic search
- OpenSpec: human-readable files, version-controlled

Write to Engram (`engram-convention.md`) AND filesystem (`openspec-convention.md`) for every artifact.

Read: Engram first, filesystem fallback.
Write: both MUST succeed for completion.
Token cost: hybrid consumes MORE per op. Use only when both cross-session + file artifacts needed.

## State Persistence (Orchestrator)

Orchestrator persists DAG state after each phase transition for SDD recovery after compaction.

| Mode | Persist | Recover |
|------|---------|---------|
| `engram` | `mem_save(topic_key: "sdd/{change-name}/state", capture_prompt: false*)` | `mem_search("sdd/*/state")` → `mem_get_observation(id)` |
| `openspec` | Write `state.yaml` | Read `state.yaml` |
| `hybrid` | Both | Engram first; filesystem fallback |
| `none` | Not possible | Not possible |

*State automated artifacts: set `capture_prompt: false`. Older schema lacks field? Omit rather than fail.

## Common Rules

- `none` → no project files, inline only
- `engram` → no project files, persist to Engram, return IDs
- `openspec` → files only to paths in `openspec-convention.md`
- `hybrid` → persist to BOTH, follow both conventions
- NEVER force `openspec/` unless orchestrator passed `openspec` or `hybrid`
- Unsure? Default `none`

## Sub-Agent Context Rules

Sub-agents launch fresh — NO access to orchestrator's instructions or memory protocol.

Read/write by type:
- Non-SDD: orchestrator searches engram, passes summary in prompt. Sub-agent saves discoveries via `mem_save`.
- SDD (with deps): sub-agent reads artifacts from backend directly, saves its artifact.
- SDD (no deps, e.g. explore): nobody reads. Sub-agent saves its artifact.

Rationale:
- Orchestrator reads for non-SDD: knows what context is relevant. Sub-agents searching themselves waste tokens on irrelevant results.
- Sub-agents read for SDD: SDD artifacts are large; inlining in orchestrator prompt would consume entire context window.
- Sub-agents always write: they have complete detail. Nuance lost by time results flow back.

## Orchestrator Prompt Instructions for Sub-Agents

Non-SDD:
```
PERSISTENCE (MANDATORY):
Important discoveries, decisions, or bugs? MUST save to engram before returning:
  mem_save(title: "{short}", type: "{decision|bugfix|discovery|pattern}",
           project: "{project}", content: "{What, Why, Where, Learned}")
```

SDD (with dependencies):
```
Artifact store mode: {engram|openspec|hybrid|none}
Read before starting (search returns truncated previews):
  mem_search(query: "sdd/{change-name}/{type}", project: "{project}") → ID
  mem_get_observation(id: {id}) → full content (REQUIRED)

PERSISTENCE (MANDATORY — do NOT skip):
After work, MUST call:
  mem_save(title: "sdd/{change-name}/{artifact-type}",
    topic_key: "sdd/{change-name}/{artifact-type}",
    type: "architecture", project: "{project}",
    capture_prompt: false,
    content: "{full artifact markdown}")
Return without mem_save → next phase CANNOT find artifact → pipeline BREAKS.
```

SDD (no dependencies):
```
Artifact store mode: {engram|openspec|hybrid|none}

PERSISTENCE (MANDATORY — do NOT skip):
After work, MUST call:
  mem_save(title: "sdd/{change-name}/{artifact-type}",
    topic_key: "sdd/{change-name}/{artifact-type}",
    type: "architecture", project: "{project}",
    capture_prompt: false,
    content: "{full artifact markdown}")
Return without mem_save → next phase CANNOT find artifact → pipeline BREAKS.
```

SDD artifacts: `capture_prompt: false` mandatory when schema supports it. Engram v1.15.3 defaults `capture_prompt: true` for human saves, but SDD = automated pipeline. Don't infer from `type` (both SDD and human decisions use `architecture`). Older schema lacks field? Omit, don't fail.

## Sub-Agent Response Ordering

Persistence (`mem_save`/file writes) MUST happen BEFORE final text response. Sub-agent's last output = text, never tool call.

**Why**: Task tool returns sub-agent's final output to parent. Ends with tool call → parent gets only tool result (e.g., `"Observation saved"`) — text analysis lost. Always: work → save → respond with text envelope.

Sub-agents must NOT call `mem_session_summary` — top-level agents only.

## Skill Registry

Orchestrator pre-resolves skill paths from registry, injects as `## Skills to load before work`. Sub-agents read exact `SKILL.md` files before task-specific work.

Generate/update: run `skill-registry` skill or `sdd-init`.

Sub-agent skill loading: `## Skills to load before work` present? Read exact files. Not present? Check `SKILL: Load` fallback. Neither? Proceed without — not an error.

## Detail Level

Orchestrator may pass `detail_level`: `concise | standard | deep`. Controls output verbosity, NOT what gets persisted — always persist full artifact.

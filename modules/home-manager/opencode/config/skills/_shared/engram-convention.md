# Engram Artifact Convention (reference documentation)

NOTE: Critical engram calls (`mem_search`, `mem_save`, `mem_get_observation`) inlined in each SKILL.md. This doc is supplementary — sub-agents don't need it to function.

## Naming Rules

ALL SDD artifacts persisted to Engram MUST follow deterministic naming:

```
title:     sdd/{change-name}/{artifact-type}
topic_key: sdd/{change-name}/{artifact-type}
type:      architecture
project:   {detected or current project name}
scope:     project
capture_prompt: false
```

Set `capture_prompt: false` when schema supports it. Older schema lacks field? Omit, don't fail.

### Artifact Types

| Type | Produced By | Description |
|------|-------------|-------------|
| `explore` | sdd-explore | Exploration analysis |
| `proposal` | sdd-propose | Change proposal |
| `spec` | sdd-spec | Delta specs (all domains concatenated) |
| `design` | sdd-design | Technical design |
| `tasks` | sdd-tasks | Task breakdown |
| `apply-progress` | sdd-apply | Impl progress (one per batch) |
| `verify-report` | sdd-verify | Verification report |
| `archive-report` | sdd-archive | Archive closure with lineage |
| `state` | orchestrator | DAG state for compaction recovery |

### State Artifact

```
mem_save(
  title: "sdd/{change-name}/state",
  topic_key: "sdd/{change-name}/state",
  type: "architecture",
  project: "{project}",
  capture_prompt: false,
  content: "change: {change-name}\nphase: {last-phase}\nartifact_store: engram\nartifacts:\n  proposal: true\n  specs: true\n  design: false\n  tasks: false\ntasks_progress:\n  completed: []\n  pending: []\nlast_updated: {ISO date}"
)
```

Recovery: `mem_search("sdd/{change-name}/state")` → `mem_get_observation(id)` → parse YAML → restore.

## Recovery Protocol (2 steps)

Lifecycle (when Engram exposes metadata/tooling):
- At session start or before arch-sensitive work: `mem_review(action: "list")` for current project.
- `mem_review` unavailable? Don't fail. Continue with `mem_context`/`mem_search`. Apply lifecycle metadata from returned observations when present.
- `active` memories: use normally.
- `needs_review` memories: stale context. Surface, verify against current evidence before relying.
- Do NOT auto-call `mark_reviewed`. Only after explicit user confirmation or via dedicated memory maintenance command.

```
Step 1: mem_search(query: "sdd/{change-name}/{artifact-type}", project: "{project}") → preview + ID
Step 2: mem_get_observation(id: {observation-id}) → complete content
```

For multiple artifacts, group all searches, then all retrievals:

```
STEP A — SEARCH (get IDs):
  mem_search(query: "sdd/{change-name}/proposal") → ID
  mem_search(query: "sdd/{change-name}/spec") → ID
  mem_search(query: "sdd/{change-name}/design") → ID

STEP B — RETRIEVE (mandatory):
  mem_get_observation(id: {proposal_id})
  mem_get_observation(id: {spec_id})
  mem_get_observation(id: {design_id})
```

Loading project context:
```
mem_search(query: "sdd-init/{project}", project: "{project}") → ID
mem_get_observation(id) → full context
```

## Writing Artifacts

Standard write:
```
mem_save(
  title: "sdd/{change-name}/{artifact-type}",
  topic_key: "sdd/{change-name}/{artifact-type}",
  type: "architecture",
  project: "{project}",
  capture_prompt: false,
  content: "{full markdown content}"
)
```

Example — saving proposal for `add-dark-mode`:
```
mem_save(
  title: "sdd/add-dark-mode/proposal",
  topic_key: "sdd/add-dark-mode/proposal",
  type: "architecture",
  project: "my-app",
  capture_prompt: false,
  content: "## Proposal\n\nAdd dark mode toggle..."
)
```

`capture_prompt: false` REQUIRED for SDD artifacts when schema supports it. Engram v1.15.3 captures prompts by default for human saves, but SDD = automated pipeline. Don't infer from `type` (both SDD and human decisions use `architecture`). Older schema lacks field? Omit, don't fail.

Update existing (when you have observation ID):
```
mem_update(id: {observation-id}, content: "{updated content}")
```

Use `mem_update` with exact ID. Use `mem_save` with same `topic_key` for upsert.

### Browsing All Artifacts for a Change

```
mem_search(query: "sdd/{change-name}/", project: "{project}")
→ Returns all artifacts for that change
```

## Project Name Resolution (engram v1.11.0+)

Engram auto-detects from git remote at MCP startup. `--project` flag and `ENGRAM_PROJECT` env var override. All names normalized to lowercase + trimmed.

Name mismatch? engram warns. Use `mem_merge_projects` (MCP) or `engram projects consolidate` (CLI) to merge variants.

## Upsert Behavior

Same `topic_key` + `project` + `scope` → UPDATE (overwrite), not INSERT. Previous content lost — `revision_count` increments but old content NOT saved. By design: engram = working memory, not audit trail. For iteration history or team collab, use `openspec` or `hybrid` mode.

## Why This Convention

- Deterministic titles → recovery works by exact match
- `topic_key` → upserts without duplicates
- `sdd/` prefix → namespaces all SDD artifacts
- Two-step recovery → search previews truncated; `mem_get_observation` is only way to full content
- Lineage → archive-report includes all observation IDs for complete traceability

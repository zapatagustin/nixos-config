# Skill Resolver — Universal Protocol

Any agent that **delegates to sub-agents** MUST use this protocol to resolve relevant skills and pass them safely.

## Why This Exists

Sub-agents start with no project skill context. Registry gives delegators a cheap index without rewriting or summarizing skills.

## When to Apply

Before every sub-agent launch that involves reading, writing, reviewing, testing, documenting, or creating artifacts. Skip only mechanical commands.

## The Protocol

### Step 1: Obtain the Skill Registry

Registry = **index** of skill names, triggers, scopes, exact `SKILL.md` paths. Not a compact-rules bundle.

Resolution order:
1. Session cache (if present).
2. `mem_search(query: "skill-registry", project: "{project}")` → `mem_get_observation(id)`.
3. Fallback: read `.atl/skill-registry.md` from project root.
4. No registry found → proceed without, warn user to run `gentle-ai skill-registry refresh`.

### Step 2: Match Relevant Skills

Two dimensions:

| Context | Match against |
| --- | --- |
| Code/files | Registry trigger/description mentions language, framework, tool, or path |
| Task/action | Registry trigger/description mentions PR, review, docs, tests, Jira, comments, release |

Prefer smallest useful set. >5 skills match? Keep 5 most relevant, prioritize code over task context.

### Step 3: Pass Skill Paths

Inject paths, not summaries:

```markdown
## Skills to load before work

Read these exact files before reading, writing, reviewing, testing, or creating artifacts:

- /absolute/path/to/skills/go-testing/SKILL.md
- /absolute/path/to/skills/typescript/SKILL.md
```

Sub-agent MUST read those files before task-specific work. `SKILL.md` = runtime contract + source of truth.

### Step 4: Report Resolution

Sub-agents MUST report `skill_resolution`:

- `paths-injected`: received exact paths from delegator, loaded them.
- `fallback-registry`: no paths received, self-loaded from registry.
- `fallback-path`: loaded explicit fallback path outside registry.
- `none`: no skills loaded.

Report anything other than `paths-injected`? Orchestrator MUST re-read registry before next delegation.

## Compaction Safety

- Registry persists in Engram + `.atl/skill-registry.md`.
- Delegators recover selected paths after compaction by re-reading registry.
- Sub-agents receive exact files — meaning not degraded by generated summaries.

## Integration Points

- **ATL Orchestrator**: resolves for all SDD + non-SDD delegations.
- **judgment-day**: resolves before Judge A, B, Fix Agent.
- **pr-review + future delegators**: use this protocol when launching sub-agents.

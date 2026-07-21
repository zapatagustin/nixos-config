# SDD Phase — Common Protocol

Standard protocol across all SDD phases. Sub-agents MUST load this alongside their phase-specific SKILL.md.

Executor boundary: SDD phase agent = EXECUTOR, not orchestrator. Do phase work yourself. Do NOT launch sub-agents, call `delegate`/`task`, or bounce work unless phase skill explicitly says stop-and-report.

## A. Skill Loading

1. Orchestrator injected `## Skills to load before work` block? Read those `SKILL.md` files before task work.
2. No skills block? Check for `SKILL: Load` instructions. Load exact skill files.
3. Neither? Fallback to skill registry:
   a. `mem_search(query: "skill-registry", project: "{project}")` → found? `mem_get_observation(id)`
   b. Fallback: read `.atl/skill-registry.md` from project root
   c. Match registry triggers to task, read listed `SKILL.md` paths.
4. No registry? Proceed with phase skill only.

NOTE: preferred path = (1) — exact paths from orchestrator. (2)/(3) fallbacks. Registry search = SKILL loading, not delegation. `## Skills to load before work` present → IGNORE redundant `SKILL: Load`.

## B. Artifact Retrieval (Engram Mode)

**CRITICAL**: `mem_search` returns 300-char PREVIEWS, not full content. MUST call `mem_get_observation(id)` for EVERY artifact. **Skipping = wrong output.**

**Run all searches in parallel** — NOT sequential.

```
mem_search(query: "sdd/{change-name}/{artifact-type}", project: "{project}") → save ID
```

Then **run all retrievals in parallel**:

```
mem_get_observation(id: {saved_id}) → full content (REQUIRED)
```

Do NOT use search previews as source.

## C. Artifact Persistence

Every phase producing an artifact MUST persist it. Skipping BREAKS pipeline — downstream phases cannot find output.

### Engram mode

```
mem_save(
  title: "sdd/{change-name}/{artifact-type}",
  topic_key: "sdd/{change-name}/{artifact-type}",
  type: "architecture",
  project: "{project}",
  capture_prompt: false,
  content: "{your full artifact markdown}"
)
```

`topic_key` enables upserts — re-save updates, not duplicates.
`capture_prompt: false` mandatory for SDD artifacts (automated pipeline, not human saves). Set when Engram schema supports it; omit field if older schema rejects it.

### OpenSpec mode

File already written during phase main step. No additional action.

### Hybrid mode

Do BOTH: write file AND `mem_save` as above.

### None mode

Return inline only. No files, no `mem_save`.

## D. Return Envelope — with Output Compression

> **CRITICAL — Response ordering**: FINAL output MUST be text (return envelope), NOT a tool call. Save to Engram (`mem_save`) BEFORE final text response. Do NOT call `mem_session_summary` — top-level agents only. **Why**: sub-agent's last action = tool call → parent gets only tool result, text response (analysis) is lost.

### Output Compression (Active)

**Compress**: narrative prose only — `executive_summary`, descriptions, explanations, rationale, evidence, analysis text, finding descriptions, free-text commentary.

**Do NOT compress** (write exactly):
- Structural: `status`, `artifacts`, `next_recommended`, `skill_resolution`, `severity`, `file:line`
- Code blocks, file paths, commands, inline symbols, quoted error messages
- Tables, checklists, structured risk rows, severity labels
- Persisted artifacts (design.md, tasks.md, spec, etc.) → Engram/filesystem, write normal prose

**Compression rules (narrative output only)**:
- Drop articles (a/an/the), filler (just/really/basically/actually), hedging (might/could/perhaps)
- Fragments OK. Short synonyms (use over extensive, fix over implement a solution for)
- Preserve ALL technical meaning, domain terms, numbers, proper nouns exactly
- One line per finding/risk/summary item when possible
- Orchestrator reads structural fields + compressed narrative only — does NOT parse narrative prose. Compression saves orchestrator token context without signal loss.

**Anti-pattern**: Do NOT compress artifact content (design, spec, tasks, code). Only compress return text sent back to orchestrator.

### Return Envelope Format

Every phase MUST return structured envelope to orchestrator:

- `status`: `success`, `partial`, or `blocked`
- `executive_summary`: 1-3 sentence summary
- `detailed_report`: (optional) full output, or omit if inline
- `artifacts`: artifact keys/paths written
- `next_recommended`: next SDD phase, or "none"
- `risks`: risks or "None"
- `skill_resolution`: how skills loaded — `paths-injected` (orchestrator provided exact paths), `fallback-registry` (self-loaded from registry), `fallback-path` (via SKILL: Load path), or `none`

Example:

```markdown
**Status**: success
**Summary**: Proposal created for `{change-name}`. Defined scope, approach, and rollback plan.
**Artifacts**: Engram `sdd/{change-name}/proposal` | `openspec/changes/{change-name}/proposal.md`
**Next**: sdd-spec or sdd-design
**Risks**: None
**Skill Resolution**: paths-injected — 3 skills (react-19, typescript, tailwind-4)
(other values: `fallback-registry`, `fallback-path`, or `none — no registry found`)
```

## E. Review Workload Guard

SDD protects reviewer cognitive load, not only task generation.

- Default PR review budget: **400 changed lines** (`additions + deletions`).
- Orchestrator MUST cache delivery strategy at session start: `ask-on-risk` (default), `auto-chain`, `single-pr`, `exception-ok`.
- Orchestrator MUST pass `delivery_strategy` to `sdd-tasks` + resolved decision to `sdd-apply`.
- `sdd-tasks` MUST forecast if work may exceed budget.
- Forecast MUST include plain-text guard lines: `Decision needed before apply: Yes|No`, `Chained PRs recommended: Yes|No`, `400-line budget risk: Low|Medium|High`.
- Forecast high? `sdd-tasks` MUST recommend chained/stacked PRs via deliverable work units.
- `sdd-apply` MUST NOT start oversized work unless delivery strategy resolves to chained/stacked PR slices or accepted `size:exception`.
- Each chained PR slice: clear start, clear finish, autonomous scope, verification, rollback.
- Feature Branch Chain: PR #1 targets tracker branch, child PRs target previous PR branch. GitHub shows previous slices in child diff → retarget/rebase until clean.

Guard reduces reviewer burnout. Not optional process noise.

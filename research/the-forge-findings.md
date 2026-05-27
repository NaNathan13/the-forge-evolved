# The Forge — Complete Inventory & "Off the Rails" Analysis

> Research source: `/Users/nathanwilson/Documents/Nathan/Projects/The-Forge` (read-only)
> Produced for: The Forge Evolved (2.0 redesign)

---

## 1. Overview — What The Forge Is

The Forge is a **markdown- and bash-driven pipeline** for running Claude Code projects end-to-end: from fuzzy idea to merged, CI-green code. It is not an application — no runtime, no server, no compiled artifact. It is a collection of:

- **18 skill files** (`.claude/skills/*/SKILL.md`) — markdown instruction files Claude Code loads as prompts
- **6 hook scripts** (`.claude/hooks/`) — deterministic bash triggered on Claude Code lifecycle events
- **3 support agent role definitions** (`.claude/agents/`) — subagent roles workers can dispatch
- **1 path-scoped rule** (`.claude/rules/bash-conventions.md`) — auto-loaded for shell files
- **5 validation scripts** (`test/validate-*.sh`) + **11+ test suite files** (`test/*.test.sh`)
- **5 resilience/pipeline scripts** (`scripts/`) — the external relaunch loop, watchdog, continuation helper
- **3 setup scripts** (`.claude/scripts/`) — kanban, workflow setup
- **1 statusline script** (`.claude/statusline/budget-mirror.sh`) — context gauge
- **An extensive doc system** (`docs/`, `CLAUDE.md`, `CONTEXT.md`, `WORKFLOW.md`, `MISSION-CONTROL.md`, `README.md`)
- **A resilience substrate** (`.forge/`) with config, continuation file chain, heartbeat, launchd agents
- **Template mirror** (`templates/`) — placeholder versions of all root docs for new-project bootstrap
- **1 bootstrap script** (`light-the-forge.sh`)

**The core promise:** "Ponder → Forge → Temper → Seal — four phases, one operator command each." GitHub issues, PRs, labels, and CI are the pipeline's state machine. The system is GitHub-native by design.

**README's stated differentiator:** "18 skills, zero project-specific code."

---

## 2. The Facet Inventory

### 2a. Explicit "Facets" List Found

`docs/the-forge-at-a-glance.md` and `docs/how-the-forge-works.md` enumerate **13 facets** (called "sections" in the at-a-glance doc, mirroring 13 numbered sections in the full walkthrough). The at-a-glance doc also references **11 audit facets** (from a now-deleted `docs/audit/` directory, cleaned up in ADR-0007). The 13 sections from `docs/the-forge-at-a-glance.md` (path: `docs/the-forge-at-a-glance.md`) are:

1. What The Forge is
2. The core pipeline: ponder → forge → temper → seal
3. Triage — the issue state machine
4. The standalone skills
5. The hooks
6. The support agents
7. The scripts
8. The `.forge/` resilience substrate
9. `templates/` — the placeholder mirror
10. `light-the-forge.sh` — the bootstrap
11. CI and the test harness
12. The supporting docs and the knowledge loop
13. The audit — the eleven audit facets (now deleted per ADR-0007)

The at-a-glance doc lists the former 11 audit facets verbatim: *"phased pipeline, subagent orchestration, sentinel protocol, context & session discipline, crash resilience, skills-as-prompts, GitHub-as-state, self-healing knowledge loop, planning discipline, ubiquitous language, and mission control."*

### 2b. Skills (18 total)

**Pipeline core:**

| Skill | Purpose |
|-------|---------|
| `/ponder` | Planning phase entry point — orchestrates `grill-me` + `inscribe` + `triage` |
| `/forge` | Forge-phase orchestrator — dispatches `/forge-worker <N>` per slice, watches `FORGE:RESULT` sentinels |
| `/forge-worker <N>` | Build one slice: branch → implement → test → PR → CI green, emit `FORGE:RESULT` |
| `/temper` | Temper-phase orchestrator — dispatches `/temper-worker <PR>` per PR, watches `TEMPER:RESULT` sentinels |
| `/temper-worker <PR>` | Review one PR: reviewer agent + inline intent-match + strict friction rule, emit `TEMPER:RESULT` |
| `/seal` | Closer: approve + squash-merge `ready-for-seal` PRs, reconcile `MISSION-CONTROL.md`, clean up |

**Sub-skills of `/ponder`:**

| Skill | Purpose |
|-------|---------|
| `/grill-me` | Interview user relentlessly on a design, resolves every decision branch |
| `/inscribe` | Write PRD, file issues, triage all slices |
| `/triage` | Move issues through the state machine, assign `slice:*` labels |

**Standalone helpers:**

| Skill | Purpose |
|-------|---------|
| `/prototype` | Fast-mode: skip ceremony, file issues directly for work scoped in 2 minutes |
| `/diagnose` | Disciplined debugging loop (reproduce → minimise → hypothesise → fix → regression-test) |
| `/tinker` | Throwaway exploration branch, no pipeline, deletes after |
| `/scrub` | Clean orphaned worktrees, stale continuation files, temp artifacts |
| `/examine` | Detect existing codebase stack, fill `CLAUDE.md` placeholders, write path-scoped rules |
| `/sharpen` | Turn a rough idea into a precise prompt |

**Manual-only (high-stakes or outside normal flow):**

| Skill | Purpose |
|-------|---------|
| `/light-the-forge` | First-run bootstrap Q&A — fill `CLAUDE.md`, `MISSION-CONTROL.md`, `CONTEXT.md`, init git, create GitHub repo |
| `/rollback <PR>` | Revert a shipped slice — creates revert PR, reopens original issue, reverses MC state |
| `/write-a-skill` | Author a new skill with proper structure and progressive disclosure |

**Skill sizes (lines of SKILL.md):**
- `/forge`: 647 lines
- `/light-the-forge`: 422 lines
- `/forge-worker`: 370 lines
- `/inscribe`: 363 lines
- `/temper`: 353 lines
- `/temper-worker`: 298 lines
- Total across all 18: 4,436 lines

### 2c. Hooks (6 in `.claude/hooks/`)

| Hook | Event | Purpose |
|------|-------|---------|
| `overseer-session-start.sh` | `SessionStart` | Re-injects `.forge/continuation/<slug>/latest` as opening context; stamps generation baseline for Stop hook enforcement |
| `overseer-stop-handoff.sh` | `Stop` | Touches heartbeat file; blocks stop if loop-managed session didn't write a continuation file this generation |
| `mission-control-drift.sh` | `SessionStart` | Checks `mc:open=N,N` row markers against GitHub issue state; warns about closed issues still in MC |
| `instructions-loaded.sh` | `InstructionsLoaded` | Appends JSONL record to `.claude/instructions-loaded.jsonl` on every rule/CLAUDE.md load |
| `read-human-only-guard.sh` | `PreToolUse(Read)` | Scans target file line 1 for `> **Audience:** humans only` banner; returns `permissionDecision: "ask"` on match |
| `example-block-bad-command.sh` | — | Disabled template example |

### 2d. Support Agents (3 in `.claude/agents/`)

| Agent | Purpose |
|-------|---------|
| `researcher.md` | Read-only exploration subagent; offloads investigation from worker context |
| `reviewer.md` | Code review on a diff; required in `tdd` mode pre-PR, always used by `/temper-worker` |
| `builder.md` | Parallel implementation of independent sub-tasks |

Workers are capped at **2 concurrent support agents**.

### 2e. Rules (`.claude/rules/`)

| Rule | Trigger |
|------|---------|
| `bash-conventions.md` | `**/*.sh`, `**/*.bash` — shebang, strict mode, `[[`, quoting, `local` in functions |

Plus a `README.md` explaining how to add more rules.

### 2f. Scripts

**Resilience / pipeline (`scripts/`):**

| Script | Purpose |
|--------|---------|
| `relaunch-loop.sh` | External relaunch loop — relaunches `claude -p` after each clean `OVERSEER_CONTINUE` handoff; budget gate, thrash circuit breaker, crash breaker |
| `continuation.sh` | Continuation helper — slug derivation, dir creation, gen-NNN.md write/prune/read |
| `liveness-watchdog.sh` | Reads heartbeat timestamp; kills hung `claude` process when stale past `FORGE_HEARTBEAT_TIMEOUT_SECONDS` (900s default) |
| `reconcile-mc.sh` | Sole writer for MISSION-CONTROL.md close-out — removes shipped rows, recomputes Recommended next prompt |
| `validate-prd-terms.sh` | Validates PRD `## Terms used` section against `CONTEXT.md` (callable helper, not CI gate) |

**Per-project setup (`.claude/scripts/`):**

| Script | Purpose |
|--------|---------|
| `kanban-move.sh` | Move a GitHub Projects (v2) card to a column; exits 78 when not configured (pipeline ignores gracefully) |
| `setup-kanban.sh` | One-time setup to populate `REPLACE_ME` project IDs in `kanban-move.sh` |
| `workflow-setup.sh` | Additional workflow setup helper |

### 2g. Statusline

| File | Purpose |
|------|---------|
| `.claude/statusline/budget-mirror.sh` | Reads `context_window.used_percentage` from Claude Code's statusline JSON stdin; renders `ctx 42% ▸ warn 40 / hard 50` — display only, no control flow |

### 2h. Test Suite (`test/`)

15 test files covering: `continuation.test.sh`, `forge-loop.test.sh`, `forge-preflight-approval.test.sh`, `harness.test.sh`, `hooks.test.sh`, `liveness-watchdog.test.sh`, `mission-control-drift.test.sh`, `reconcile-mc.test.sh`, `relaunch-loop.test.sh`, `statusline.test.sh`, `temper-continuation.test.sh`, plus 5 validator test files. Bash-only, no framework, uses `test/stubs/claude` stub.

### 2i. Doc System

| Document | Size | Purpose |
|----------|------|---------|
| `CLAUDE.md` | 72 lines | Always-loaded harness contract: stack, check command, dev mode, context-loading rules, rule table |
| `CONTEXT.md` | 174 lines | Canonical glossary (single source of truth); anchor-linked from all living docs |
| `WORKFLOW.md` | 132 lines | Pipeline reference — phase-by-phase, context discipline, slice labels, kanban, sentinels, friction |
| `MISSION-CONTROL.md` | 64 lines | Session-state ledger — flat-bucket tables, ADR index, "Recommended next prompt" |
| `README.md` | 97 lines | Public-facing pipeline overview + quickstart |
| `docs/workflow/README.md` | ~69 lines | How it works narrative + skill table + operator cheatsheet |
| `docs/workflow/reference.md` | — | Full skill reference |
| `docs/workflow/relaunch-loop-operations.md` | — | launchd install, log reading, circuit-breaker recovery |
| `docs/shared/pipeline.md` | — | Sentinel protocol schema, sentinel examples, invariants |
| `docs/adr/0001–0008` | 8 ADRs | Architectural decisions (phase isolation, concurrency cap, context defense, temper boundary, pipeline structure, naming discipline, v1 cleanup, operator naming) |
| `docs/the-forge-at-a-glance.md` | 245 lines | **Human-only** condensed orientation, 13 sections |
| `docs/how-the-forge-works.md` | 590 lines | **Human-only** full from-scratch narrative walkthrough |
| `docs/vision/the-forge.md` | **Human-only** | Current vision: shipped today + autonomy spectrum (4 levels) + dev-mode redesign plans |
| `docs/vision/autonomous-forge.md` | **Human-only** | Historical north-star doc (roadmap superseded) |
| `docs/vision/discord-control-plane.md` | **Human-only** | Pre-build design notes for Discord integration (level 3 of autonomy spectrum) |
| `docs/vision/tier0-sudo-orchestrator.md` | **Human-only** | Stub design for cross-project fleet orchestrator (level 4, "built last if at all") |
| `docs/whj/README.md` | — | "Weenie Hut Junior mode is not yet implemented. See `docs/future/modes.md`." (that path doesn't exist) |
| `docs/dev/setup.md` | — | Manual setup walkthrough |
| `.claude/lessons.md` | 27 lines | Append-only one-line index of learned patterns (currently 2 entries) |
| `.claude/knowledge/` | 2 files | Full detail files: `worktree-absolute-path-pinning.md`, `subshell-orphaned-background-pid.md` |
| `.claude/token-usage.jsonl` | — | Per-worker token log: `{ts, issue, pr, branch, num_turns, total_tokens}` |
| `.claude/instructions-loaded.jsonl` | — | JSONL log of every CLAUDE.md / rules load and read-denied events |

### 2j. `.forge/` Resilience Substrate

| File/Dir | Purpose |
|----------|---------|
| `resilience.config` | Bash-sourceable KEY=value thresholds (committed) |
| `continuation/<slug>/gen-NNN.md` | Immutable per-generation handoff files (gitignored runtime) |
| `continuation/<slug>/latest` | Symlink to newest gen-NNN.md |
| `heartbeat/<slug>` | Timestamp touched by Stop hook on every fire |
| `heartbeat/<slug>.genbaseline` | Generation number at session start (for Stop hook enforcement) |
| `install-manifest.json` | Forge SHA + install timestamp + skills list (written by `light-the-forge.sh`) |
| `templates/launchd/com.forge.project.plist` | launchd keep-alive agent template for macOS |
| `templates/launchd/com.forge.project.watchdog.plist` | launchd liveness-watchdog agent template for macOS |

### 2k. GitHub Integration

- **Single CI workflow** (`.github/workflows/validate-mc.yml`): runs `test/validate-mc.sh` on every PR and push to `main`.
- **GitHub Projects (v2) kanban**: optional board, 5-column lifecycle (`Backlog → Ready → In Progress → In Review → Done`), driven by `kanban-move.sh`. Pipeline no-ops gracefully (exit code 78) when not configured.
- **GitHub issues as the queue**: `ready-for-agent`, `needs-rework`, `friction`, `needs-human`, `ready-for-seal` labels are the pipeline state machine.
- **No GitHub Actions for the pipeline itself** — the pipeline runs via Claude Code skills, not Actions.

---

## 3. The Lifecycle / Workflow

The intended end-to-end flow (from `WORKFLOW.md`, `MISSION-CONTROL.md`, `light-the-forge.sh`):

### Bootstrap (once per project)
```
curl -fsSL .../light-the-forge.sh | bash
  → checks prerequisites (gh, git, jq, claude)
  → copies kit files into target directory
  → launches /light-the-forge skill (Q&A ~10 questions)
  → fills CLAUDE.md, CONTEXT.md, MISSION-CONTROL.md
  → git init, creates GitHub repo
  → writes .forge/install-manifest.json
```

### Normal Development Cycle

**Phase 1 — Ponder** (interactive, one session):
```
/ponder
  → grill-me: relentless Q&A to resolve all design branches
  → inscribe: write PRD under docs/prds/, file GitHub issues, validate Terms used
    against CONTEXT.md (hard gate), triage to ready-for-agent + slice:* labels
  → kanban-move.sh <N> ready for each triaged issue
```

**Phase 2 — Forge phase** (autonomous, loop-managed):
```
scripts/relaunch-loop.sh --role orchestrator
  → [each generation] /forge dispatches one /forge-worker <N>
    → create branch feat/#N-slug
    → implement, test (per dev mode), run check command
    → open PR, wait for CI (Monitor tool — zero cost)
    → emit FORGE:RESULT {"v":1,"status":"success",...}
  → /forge writes OVERSEER_CONTINUE, loop relaunches fresh
  → repeat until queue drained, /forge writes OVERSEER_COMPLETE
```

**Phase 3 — Temper phase** (autonomous, loop-managed):
```
scripts/relaunch-loop.sh --role orchestrator
  → [each generation] /temper dispatches one /temper-worker <PR>
    → dispatch reviewer agent on gh pr diff <PR>
    → inline intent-match (issue acceptance criteria vs diff)
    → strict friction rule: any reviewer HIGH OR intent-match fail → friction
    → else → ready-for-seal label
    → emit TEMPER:RESULT {"v":1,"status":"success",...}
  → /temper writes OVERSEER_CONTINUE, loop relaunches fresh
```

**Phase 4 — Seal** (one operator command):
```
/seal
  → lists open ready-for-seal PRs (skip friction / needs-human / non-green CI)
  → approve + squash-merge each
  → reconcile MISSION-CONTROL.md (scripts/reconcile-mc.sh)
  → delete continuation files for shipped slices
```

**No auto-chain between phases** — operator inspects state between each one per ADR-0005.

### Dev Modes

Three modes declared in `CLAUDE.md`:
- `fast`: skip tests, check command advisory, no pre-PR reviewer
- `balanced` (default): write tests, check command hard gate, no pre-PR reviewer
- `tdd`: write tests first (red→green→refactor), check command hard gate, pre-PR reviewer agent dispatch

---

## 4. GitHub Integration

From `README.md`: "The Forge is **GitHub-native**. Issues, PRs, labels, and CI checks are the pipeline's state machine — they aren't a soft dependency, they're the substrate."

**What uses GitHub:**
- Issues for work queue (`ready-for-agent`, `needs-rework` labels)
- PR labels for state (`friction`, `needs-human`, `ready-for-seal`)
- CI checks as the green-gate for `/seal`
- GitHub Projects (v2) for kanban (optional, graceful no-op)
- `gh` CLI for all GitHub operations

**CI workflow** (`.github/workflows/validate-mc.yml`): only validates `MISSION-CONTROL.md` row markers. The rest of the validation suite (`validate-sentinel.sh`, `validate-skills.sh`, etc.) is documented as running in CI but only the MC validator has a workflow file.

**Autonomous loop via GitHub**: The GitHub issue labels are what make the autonomous loop work — `/forge` polls `gh issue list --label ready-for-agent`, `/seal` polls `gh pr list --label ready-for-seal`. The state machine is fully externalized to GitHub.

**From `docs/vision/the-forge.md` on GitHub integration:**
> "The base pipeline (level 1 autonomy) is a drop-in for anyone."
> Future level 3 (Discord): "One Discord channel per project ↔ one Tier-1 orchestrator session."

---

## 5. Context Discipline Mechanisms

This is documented across `WORKFLOW.md`, `resilience.config`, `budget-mirror.sh`, `relaunch-loop.sh`, and multiple skill files.

### 5a. Context-Window (Per-Session Token Budget)

From `resilience.config` (committed config, canonical numbers):
```bash
FORGE_ORCH_WARN_PCT=40     # orchestrator warn threshold
FORGE_ORCH_HARD_PCT=50     # orchestrator hard-stop threshold
FORGE_WORKER_WARN_PCT=50   # worker warn threshold
FORGE_WORKER_HARD_PCT=60   # worker hard-stop threshold
FORGE_CONTEXT_WINDOW_TOKENS=200000  # denominator for % calculation
```

From `WORKFLOW.md` §"Context discipline":
- Workers: "40% = warning (wrap up current phase), 50% = hard stop (write continuation, hand off)"
- But `resilience.config` says worker warn=50/hard=60 — **there is an inconsistency in the docs**
- Overseers: "structural one-worker-per-generation exit; never self-measure context %"
- No bulk-loading of lessons.md at startup — reactive only
- CI failure fixes get a fresh subagent with just the failure log

From `docs/vision/the-forge.md` §"Design principles":
> "Hand off proactively at 40-60% of the window, not at the platform's auto-compact cliff. Continuation file beats lossy in-flight compaction. The Forge is *more* conservative than Claude Code's own ~83.5% auto-compact trigger — deliberately."

### 5b. Session Rate-Limit (5-Hour Rolling Account Budget)

From `WORKFLOW.md`:
> "The active overseer polls ccusage; 90% = warning (finish in-flight, don't dispatch new); 95% = hard-stop, ScheduleWakeup to resume in ~30 min"
> "Workers at >90% finish the current step then emit their `*:RESULT` with `"status":"continue"` so the overseer can pause the queue"

Tool used: `npx ccusage@latest session --json`

### 5c. Statusline Token Tracking

`.claude/statusline/budget-mirror.sh` renders a per-session gauge:
```
ctx 42% ▸ warn 40 / hard 50
```
Reads `context_window.used_percentage` from Claude Code's statusline JSON stdin. Adds `^` marker at warn, `!` marker at hard. **Display only — writes no files, sets no exit codes, influences no control flow.**

Registered in `.claude/settings.json`:
```json
{ "statusLine": { "type": "command", "command": ".claude/statusline/budget-mirror.sh" } }
```

### 5d. Relaunch Loop Budget Gate

`scripts/relaunch-loop.sh` runs the real enforcement:
- After each `OVERSEER_CONTINUE` handoff, reads `.usage` from `claude -p --output-format json`
- Computes `input_tokens * 100 / FORGE_CONTEXT_WINDOW_TOKENS`
- `< warn` → relaunch normally, clear handoff-signal file
- `warn ≤ used < hard` → relaunch, write `handoff-signal` file (read by SessionStart hook, appended to next generation's injected context)
- `≥ hard` → exit 3 (budget hard-stop, no further generation)

### 5e. Handoff Enforcement (Stop Hook)

`overseer-stop-handoff.sh` blocks a session from exiting without writing its continuation file (only for `OVERSEER_LOOP_MANAGED=1` sessions, i.e. loop-managed, not interactive).

### 5f. Context-Loading Discipline

From `CLAUDE.md` §"Context loading":
- Always loaded: `CLAUDE.md`, auto-memory index
- Session-state: `MISSION-CONTROL.md` — once at session start
- Glossary: `CONTEXT.md` — reactively only
- Path-scoped: `.claude/rules/<rule>.md` — auto-injected by harness on glob match
- Skill: `.claude/skills/<name>/SKILL.md` — when matching `/command` invoked
- Knowledge: `.claude/lessons.md` (index) → `.claude/knowledge/<slug>.md` — reactively when error matches
- Task-relevant docs — reactively only

**Hard-blocked from Claude context:**
- `docs/how-the-forge-works.md` — `permissions.ask` + `read-human-only-guard.sh` hook
- `docs/audit/**` — `permissions.ask` block (directory deleted per ADR-0007 anyway)
- `docs/vision/**` — `permissions.ask` block

### 5g. Observability

`.claude/instructions-loaded.jsonl` — append-only JSONL log of:
- Every `instructions_loaded` event (CLAUDE.md / rules loads)
- Every `read_denied` or `read_ask_prompted` event from the banner-scan hook

`.claude/token-usage.jsonl` — append-only JSONL per worker: `{ts, issue, pr, branch, num_turns, total_tokens}`

### 5h. Resilience Circuit Breakers (from `resilience.config`)

```bash
FORGE_THROTTLE_SECONDS=10          # min seconds between relaunches
FORGE_THRASH_MAX_GENERATIONS=5     # max clean handoffs within window
FORGE_THRASH_WINDOW_SECONDS=300    # 5-minute window for thrash detection
FORGE_CRASH_MAX_RESPINS=5          # max crashes within window (persistent across loop processes)
FORGE_CRASH_WINDOW_SECONDS=300     # 5-minute window for crash detection
FORGE_HEARTBEAT_TIMEOUT_SECONDS=900  # 15 minutes before watchdog kills hung process
FORGE_RETENTION_CAP=20             # max gen-NNN.md files kept per session slug
```

---

## 6. Knowledge Preservation

### 6a. The Knowledge Loop

Two-tier reactive system:

1. **`.claude/lessons.md`** — append-only one-line index of "wall hit and overcome" patterns.
   - Currently 2 entries: `worktree-absolute-path-pinning` and `subshell-orphaned-background-pid`
   - Cap of 50 entries; oldest-by-`Last seen` pruned on next append
   - Read reactively only when a worker hits an error, not bulk-loaded at startup

2. **`.claude/knowledge/<slug>.md`** — full detail file per entry.
   - Format: `## Error signature / ## Why this happens / ## The fix / ## Rule`
   - Max 80 lines per file
   - Loaded only when a worker's error matches the index line

**Write-back**: `/forge-worker`, `/temper-worker`, and `/diagnose` append new entries when they overcome a wall. Human curation fallback documented for cases where agent-written entries are poorly shaped.

### 6b. ADRs

8 ADRs under `docs/adr/` covering major architectural decisions. Template at `docs/adr/0000-template.md`. Writing an ADR requires all three: hard to reverse, surprising without context, result of a real trade-off.

### 6c. CONTEXT.md as Living Glossary

`CONTEXT.md` (174 lines) is the canonical glossary. Every living doc anchors to `CONTEXT.md#term`. `/inscribe`'s hard gate validates every new PRD's `## Terms used` section against it before filing issues.

### 6d. MISSION-CONTROL.md as Session-State Ledger

Read once at session start (not every turn). Updated by `/inscribe` (adds rows), `/forge` (advances status), `/seal` (removes shipped rows). `mc:open=N,N` row markers are machine-readable by `mission-control-drift.sh` and `reconcile-mc.sh`.

### 6e. Continuation Files

`.forge/continuation/<slug>/gen-NNN.md` — five hardened sections: Hard constraints / Execution frontier / Conversation summary / Next concrete action / Notes. Immutable, zero-padded monotonic. Up to `FORGE_RETENTION_CAP` (20) kept per slug for audit/recovery.

---

## 7. Autonomous / Continuous Loop

### 7a. Shipped Autonomy (Level 1)

Within a batch, the pipeline is **fully autonomous** after the user approves the build queue:
1. `/ponder` → user approves PRD + slices
2. `scripts/relaunch-loop.sh` drives `/forge` through all slices without user interaction
3. Each `/forge` generation dispatches one worker, waits for `FORGE:RESULT`, writes `OVERSEER_CONTINUE`, exits
4. Loop relaunches fresh; SessionStart hook re-injects continuation
5. Repeat until queue drained → `OVERSEER_COMPLETE`
6. Same for `/temper`
7. User runs `/seal` to merge

**The "one approval at `here's the build queue`" promise**: after the operator sees the queue and approves, the forge phase runs worker-by-worker autonomously until complete.

### 7b. Future Autonomy (Level 2 — Not Built)

From `docs/vision/the-forge.md`:
> "After `/seal`, the orchestrator looks at `MISSION-CONTROL.md`, decides what's next, surfaces clarifying questions if needed, and starts the next `/ponder` → `/forge` → `/temper` → `/seal` cycle on its own."

**This does not exist today.** The operator must manually run each phase.

### 7c. Level 3 — Discord Control Plane (Not Built)

Design notes in `docs/vision/discord-control-plane.md`. Would use Claude Code's first-party Channels/Discord plugin. Status: pre-build research doc.

### 7d. Level 4 — Tier-0 Sudo Orchestrator (Stub Only)

`docs/vision/tier0-sudo-orchestrator.md` — a trajectory marker, not a spec. "Built last, only if a flat fleet of Tier-1 orchestrators proves unmanageable."

---

## 8. WHERE IT WENT OFF THE RAILS

This section documents the honest assessment of complexity, redundancy, ceremony, and sprawl. These are the signals that The Forge "went off the rails."

### 8.1. The Naming Churn Has Its Own ADR

The project spent a non-trivial amount of engineering effort on renaming things — and then documenting the history of what they used to be called. ADR-0008 exists solely to record that `/forge-overseer` → `/forge` and `/temper-overseer` → `/temper`. ADR-0006 had to explicitly retire `/forgemaster` and "reserve the name for a future use." `CONTEXT.md` dedicates multiple paragraphs to **retired/superseded names** like `/forge-overseer`, `/temper-overseer`, and `/forgemaster`, so readers know not to use them. The glossary has become partially a history of what things used to be called.

**The signal:** When you have an ADR about naming, a glossary with retired-name entries, and a lessons.md header warning about "pre-rename role names in historical entries" — the naming has been revised so many times it requires active documentation to not confuse contributors.

### 8.2. The Doc System Has Four Overlapping "How It Works" Documents

There are at least four documents that describe what The Forge is and how it works:

1. `README.md` — public overview + quickstart (97 lines)
2. `WORKFLOW.md` — pipeline reference (132 lines)
3. `docs/the-forge-at-a-glance.md` — "condensed orientation" (245 lines, human-only)
4. `docs/how-the-forge-works.md` — "full from-scratch walkthrough" (590 lines, human-only)

Plus `docs/workflow/README.md` (another "how it works" overview), `docs/shared/pipeline.md` (sentinel protocol, but also re-explains phases), and `CONTEXT.md` (glossary, but also explains relationships and includes a full ASCII pipeline diagram).

**The signal:** The at-a-glance doc itself has a table saying "when to read which doc" — which is meta-documentation explaining how to navigate the documentation. When your docs need a guide to navigate the docs, you have too many docs.

### 8.3. The Resilience Substrate Is Production-Grade Infrastructure for a Solo Dev Tool

The `.forge/` resilience substrate includes:
- A `relaunch-loop.sh` with thrash circuit breakers, crash circuit breakers, budget gate, PID file management, and OVERSEER signal protocol (524 lines)
- Two separate circuit breakers (handoff thrash vs crash respawn) with independent state files and window logic
- macOS `launchd` keep-alive agent + liveness watchdog agent (plist templates)
- `liveness-watchdog.sh` that reads tmux scrollback, captures diagnostics, kills hung processes
- `continuation.sh` with 7 subcommands and a retention-cap pruning system
- A `heartbeat/` directory that gets touched on every session Stop event
- A dedicated `overseer-stop-handoff.sh` hook that enforces continuation-file writing using a genbaseline comparison mechanism involving two separate files

This level of infrastructure complexity is appropriate for a 24/7 production system. For a developer workflow that runs for a few hours at a time, it is massive overhead. The `docs/the-forge-at-a-glance.md` §8 admits the crash layer is "skippable — a solo drop-in user who never installs the agents loses nothing."

**The signal:** The launchd agents, the liveness watchdog, the two-tier circuit breaker system, the PID file — none of these are needed for the common use case. They exist for a "runs unattended overnight" scenario that is aspirational, not shipped.

### 8.4. The "Weenie Hut Junior" Section Is a Dead End

`docs/whj/README.md` contains exactly: "Weenie Hut Junior mode is not yet implemented. See `docs/future/modes.md` for the design." The path `docs/future/modes.md` **does not exist**. A directory with a README pointing to a missing file is pure overhead — it creates confusion without delivering anything.

### 8.5. The Vision Directory Contains Three Documents for Future Features That Aren't Started

`docs/vision/` has:
- `the-forge.md` — current vision (level 1 shipped, levels 2-4 future)
- `autonomous-forge.md` — "historical, roadmap superseded" but retained as "historical context"
- `discord-control-plane.md` — "pre-build helper doc" for a Discord integration that isn't started
- `tier0-sudo-orchestrator.md` — "stub design doc" for a Tier-0 orchestrator that is "built last, only if..."

Three of the four are for features not yet built. One is explicitly "historical." All four are marked `> **Audience:** humans only` and blocked from Claude. They add context weight to the repo without contributing to the running system.

### 8.6. The CONTEXT.md Glossary Has Become Overbuilt

`CONTEXT.md` at 174 lines defines: pipeline shape terms, phase terms, slash command terms, slice labels, sentinel names, friction, ready-for-agent, ready-for-seal, needs-rework, needs-human, MC row statuses, document types, dev mode, process terms (the `/inscribe` hard gate mechanism), worker mechanics (subagent, support agent, continuation file, kanban, ccusage, intent-match, ScheduleWakeup), and the knowledge library.

Every term has an `_Avoid_:` section listing rejected synonyms, often with historical context about why they were rejected. The glossary has grown to document **process mechanics and rejected vocabulary** rather than just canonical definitions. It includes a full ASCII relationship diagram and example dialogues.

**The signal:** A glossary that includes "Example dialogue" and `_Avoid_:` lists for every term has evolved into a mini-manual, not a glossary.

### 8.7. The InstructionsLoaded Observability System Was Built for a Deferred Audit

`CLAUDE.md` §"Observability" and the `instructions-loaded.sh` hook exist to produce data for a "token-waste audit" that is explicitly deferred:

From `MISSION-CONTROL.md` §"Deferred":
> "Token-waste audit — Needs ≥3 real sessions of post-context-hardening log data; revisit after first product project."

The hook fires on every session start, appends JSONL records, accumulates indefinitely ("has no rotation yet — accumulates until consumed"). An instrumentation system was built before the audit it serves was ready to run.

### 8.8. Multiple Overlapping Permission/Guard Systems for the Same Human-Only Files

For "don't let Claude read the human-only docs," there are **two independent enforcement mechanisms** (ADR-0003 calls this "defense in depth"):
1. `permissions.ask` in `.claude/settings.json` for three hardcoded paths
2. `read-human-only-guard.sh` PreToolUse hook for any file with the banner on line 1

Plus `CLAUDE.md` §"Context loading" spends a full paragraph documenting the asymmetry between the two mechanisms, the edge cases (auto mode vs default mode, interactive vs autonomous), and the fact that they may behave differently.

From `CLAUDE.md`:
> "**Known consequence of `auto` mode:** in `auto` permission mode... the classifier may silently approve without the operator ever seeing the prompt... The two ask surfaces remain asymmetric: `permissions.ask` prompts use the harness's native prompt surface (we do not control its text), while hook prompts use a custom reason string... Asymmetry is documented, not papered over."

**The signal:** When the defense-in-depth has documented asymmetries, known failure modes under specific permission modes, and a "papered over" vs "not papered over" framing, the mechanism has outgrown its problem.

### 8.9. The Test Suite Tests The Infrastructure That Supports The Infrastructure

The 15 test files in `test/` primarily test the resilience substrate (continuation.sh, relaunch-loop.sh, liveness-watchdog.sh, hooks, statusline) — not the pipeline skills themselves. The `README.md` in `test/` explicitly says "No application tests" and notes the pipeline is exercised by dogfooding. So you have:
- A test suite for the crash-recovery loop that wraps the pipeline
- No tests for the pipeline skills themselves (dogfooding only)

This is an inversion: the infrastructure supporting the pipeline has more automated test coverage than the pipeline itself.

### 8.10. The "One Worker Per Generation" Architecture Adds Structural Complexity Without the Stated Benefit Being Realized

The entire relaunch loop, continuation file chain, SessionStart re-injection, genbaseline stamping, Stop hook enforcement, `OVERSEER_LOOP_MANAGED` environment variable, and `OVERSEER_CONTINUE` / `OVERSEER_COMPLETE` sentinel protocol exist to implement "one worker per generation, then hand off to a fresh session" — the stated goal being to prevent context bloat.

But Claude Code now has built-in auto-compaction at ~83.5% context usage. The Forge's elaborate hand-roll is trying to solve a problem the platform partially solves natively. The `docs/vision/the-forge.md` acknowledges this: "The Forge is *more* conservative than Claude Code's own ~83.5% auto-compact trigger — deliberately." More conservative, but also 524 lines of loop logic, 198 lines of hook code, and a full continuation file chain system.

### 8.11. The `prototype` vs `tinker` vs `forge-worker` Separation Is Fine-Grained

Three skills handle "start some work":
- `/tinker` — throwaway exploration, no pipeline, deletes after
- `/prototype` — fast-mode, skip ceremony, file issues directly
- `/forge-worker <N>` — full build worker for the pipeline

The distinction between `/tinker` and `/prototype` is subtle enough that `prototype`'s SKILL.md has to explicitly say "For throwaway exploration you plan to discard, use `/tinker` instead" and `tinker`'s SKILL.md says "For scoped work you want to keep and ship, use `/prototype` instead." This cross-referencing between closely related skills is a code smell.

### 8.12. MISSION-CONTROL.md Has a "Legend" Section That Explains Its Own Row Markers

The last 12 lines of `MISSION-CONTROL.md` are a `## Legend` section explaining what `<!-- mc:none -->` and `<!-- mc:open=N,N -->` mean, how the flat-ledger works, what in-flight statuses exist, and who updates the file. This is meta-documentation embedded in the operational state document. It means every time `MISSION-CONTROL.md` is loaded into context, the Legend comes along for the ride even though it's only relevant the first time someone encounters the file.

---

## Summary Table: What Each Layer Adds vs. The Minimal Core

| Layer | Minimal Core Equivalent | What Was Added |
|-------|------------------------|----------------|
| 4 pipeline skills | Just the 4 skills | `/grill-me`, `/inscribe`, `/triage` as sub-skills |
| 14 standalone skills | 0 standalone | `/diagnose`, `/tinker`, `/prototype`, `/scrub`, `/examine`, `/sharpen`, `/rollback`, `/write-a-skill`, `/light-the-forge` |
| 6 hooks | 0 hooks | Session start, Stop handoff, MC drift, instructions log, human-only guard, example template |
| Resilience substrate | 0 resilience | relaunch-loop, continuation chain, launchd agents, watchdog, heartbeat, circuit breakers |
| Doc system | CLAUDE.md | CONTEXT.md, WORKFLOW.md, MISSION-CONTROL.md, docs/workflow/, docs/shared/, docs/adr/, docs/vision/ |
| Test suite | 0 tests | 15 test files testing the resilience layer, not the skills |
| Knowledge library | 0 knowledge | lessons.md + knowledge/ (2 entries total) |
| Glossary discipline | 0 glossary | CONTEXT.md with hard gate in /inscribe, anchor-link discipline, _Avoid: lists |
| Naming discipline | 0 naming | ADR-0006, ADR-0008, deprecated entries in CONTEXT.md |
| Vision docs | 0 vision | docs/vision/ (4 docs, 3 for unbuilt features) |

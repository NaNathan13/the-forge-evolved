# Findings — The Forge Core vs. The Forge

> Synthesis of the research done on 2026-05-27. Raw, detailed inventories live in
> [`research/forge-core-findings.md`](research/forge-core-findings.md) and
> [`research/the-forge-findings.md`](research/the-forge-findings.md). This file is the
> distilled comparison: what each system is, the facet inventories, and an honest read on
> where The Forge drifted from its own core.

---

## 1. The two systems at a glance

| Dimension | **The Forge Core** (minimal foundation) | **The Forge** (current primary workflow) |
|---|---|---|
| Mental model | 4 phases + a few utilities | 4 phases wrapped in GitHub + resilience + observability + docs |
| Skill count | ~11 skills | 18 skills + 6 hooks + 3 agents + ~8 scripts |
| State store | plain markdown plan files (`.claude/plans/`) | GitHub issues / PRs / labels = the state machine |
| Subagents | **read-only** — gather (`/research`) or judge (`/temper cold`), never act | builder workers **act** autonomously inside a batch |
| Context discipline | lazy-loading only; almost no runtime state to manage | explicit thresholds + statusline gauge + token logs |
| Autonomy | none — user triggers every step | autonomous **within** a batch; manual **between** batches |
| Knowledge | none (by design) | `lessons.md` index → `knowledge/<slug>.md`, ADRs, glossary |
| Docs | CLAUDE.md + CONTEXT.md + 1 how-to | 5+ overlapping "how it works" docs |

**One-line takeaway:** The Core is a clean four-stroke engine. The Forge bolted a GitHub-native
state machine, a production crash-recovery substrate, and a documentation bureaucracy onto that
engine — some of it valuable, much of it ceremony that never paid for itself.

---

## 2. The Forge Core — facet inventory

The irreducible spine is four phases plus utilities. Nothing auto-chains; the user triggers each step.

```
/ponder → /inscribe → /forge → /temper → /seal
  think      write      build    review    finish
```

**Phase skills**
- `/ponder` — turn a fuzzy idea into shared understanding. Writes no code or files.
- `/inscribe` — record the ponder understanding as a single sliced plan file.
- `/forge` — build the entire plan inline on the current branch, ticking off slices as they complete.
- `/temper` — review and harden; un-tick slices that don't meet their intent (loops back to `/forge`).
- `/seal` — confirm all slices done, archive the plan to `done/`.

**Utility skills**
- `/research` — gather info. Light = inline lookup; deep = parallel subagent fan-out (confirm first).
- `/diagnose` — disciplined 6-phase debugging loop.
- `/scrub` — tidy plan-state drift, safe-fix only; never auto-seals or auto-commits.
- `/sharpen` — turn a rough idea into a precise, paste-ready prompt (also used for session handoffs).
- `/grill-me` — relentless one-question-at-a-time interview until no decision branch is unresolved.
- `/light-the-core` — bootstrap installer; asks 3 setup questions, fills template placeholders.

**What makes the Core "the Core" (must-preserve essence)**
- Four-phase spine with **no auto-chaining** — the human is the orchestrator.
- All state in **plain markdown**, tick-as-you-go, always resumable by a fresh session.
- **Layered lazy loading**: only `CLAUDE.md` loads every session; `CONTEXT.md`, plan files, and skill
  files load reactively. This *is* the Core's context discipline.
- Subagents are **read-only** — they gather or judge, never act.
- Research findings are **distilled, not transcript dumps**.

---

## 3. The Forge — facet inventory (what it adds)

**18 skills:** `/ponder`, `/forge`, `/forge-worker`, `/temper`, `/temper-worker`, `/seal`, `/grill-me`,
`/inscribe`, `/triage`, `/prototype`, `/diagnose`, `/tinker`, `/scrub`, `/examine`, `/sharpen`,
`/rollback`, `/write-a-skill`, `/light-the-forge`.

**6 hooks:** session-start re-injection, stop-handoff enforcement, mission-control drift check,
instructions-loaded logger, human-only read guard, one disabled example.

**3 agents:** researcher, reviewer, builder.

**Scripts/substrate:** external relaunch loop, continuation chain, launchd crash recovery, liveness
watchdog, mission-control reconcile, PRD-term validator, kanban-move, kanban-setup, workflow-setup.

**Observability:** `token-usage.jsonl`, `instructions-loaded.jsonl`, a statusline budget gauge.

**Docs:** README, WORKFLOW.md, the-forge-at-a-glance.md, how-the-forge-works.md (590 lines),
workflow/README.md, an 8-ADR log, `docs/vision/` (Levels 2–4, unbuilt).

### GitHub integration (the genuinely valuable part)
- Issues labeled `ready-for-agent` / `needs-rework` form the **build queue**.
- `ready-for-seal` / `friction` / `needs-human` labels form the **review/merge gate**.
- All state transitions are driven via the `gh` CLI.
- **Autonomy is real within a batch** (one approval before `/forge`, then workers run unattended) but
  **manual between batches** — the operator still runs each phase command. Continuous multi-batch
  autonomy (Levels 2–4) is *documented but not built*.

### Context-discipline mechanisms (exact numbers found)
- Orchestrator: **warn 40% / hard 50%** of a 200,000-token window.
- Worker: **warn 50% / hard 60%**.
- Session rate-limit (ccusage): 90% warn / 95% hard-stop + ~30 min `ScheduleWakeup`.
- Heartbeat timeout 900s; thrash breaker = 5 handoffs / 300s; crash breaker = 5 crashes / 300s.
- Statusline renders `ctx 42% ▸ warn 40 / hard 50` — **display only, no control flow**.

### Knowledge preservation
- Two-tier reactive: `lessons.md` one-line index (cap 50) → lazy-loads `knowledge/<slug>.md` (≤80 lines).
- Workers write back when they overcome a wall.
- `CONTEXT.md` glossary (174 lines) with a hard-gate validating each new PRD's `## Terms used`.
- Continuation files (`gen-NNN.md`, 5 sections, retain 20) carry per-session memory across relaunches.
- ADRs preserve architectural decisions.

---

## 4. Where The Forge went off the rails

These are the patterns Evolved must *not* repeat. (Details + paths in the raw research file.)

1. **Naming churn earned its own ADR.** ADR-0008 exists solely to document renaming
   `/forge-overseer` → `/forge`. `CONTEXT.md` carries `_Avoid_:` sections listing retired names.
   The glossary became partly a graveyard of obsolete vocabulary.
2. **Four+ overlapping "how it works" docs.** README, WORKFLOW.md, at-a-glance (245 ln),
   how-the-forge-works (590 ln), workflow/README — plus a table explaining *which doc to read when*.
   Meta-documentation for the documentation.
3. **Production-grade crash recovery for a solo dev tool.** launchd agents, liveness watchdog, PID
   files, two-tier circuit breakers, `OVERSEER_LOOP_MANAGED` env var — for an "unattended overnight"
   scenario that's aspirational. The docs *admit* this layer is "skippable."
4. **Dead-end stubs.** `docs/whj/README.md` points at `docs/future/modes.md`, which doesn't exist.
5. **Instrumentation built before its consumer.** `instructions-loaded.jsonl` + its hook feed a
   "token-waste audit" that was explicitly *deferred*. The log grows unrotated, unread.
6. **Two mechanisms guarding the same thing.** `permissions.ask` + a `read-human-only-guard.sh` hook
   protect the same files; CLAUDE.md spends a paragraph documenting their asymmetry.
7. **Tests cover the scaffolding, not the pipeline.** 15 bash tests for the relaunch/hook/continuation
   substrate; zero automated tests for the 18 skills (pipeline "tested by dogfooding").
8. **Redundant near-twin skills.** `/tinker` vs `/prototype` are so similar each cross-references the
   other — decision overhead with no payoff.

**The throughline:** The Forge optimized for an autonomous, unattended, multi-day operation that it
never actually reached, and paid for that ambition in ceremony, redundancy, and context bloat — the
opposite of the Core's discipline.

---

## 5. Implications for The Forge Evolved

- **Keep the Core's spine and its lazy-loading discipline.** That is the foundation, untouched in spirit.
- **Adopt the genuinely valuable Forge additions, curated:** GitHub issues/Kanban as state, a real
  autonomous loop, *enforced* (not display-only) context thresholds.
- **Refuse the ceremony:** one canonical doc, stable names, no crash-recovery substrate until a real
  unattended use case exists, no instrumentation without a consumer, no near-twin skills.
- **Decide deliberately on knowledge preservation** (the user flagged it as "iffy / on the table").

See [`vision.md`](vision.md) for the target definition of Evolved.

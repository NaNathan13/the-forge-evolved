# CONTEXT — {{PROJECT_NAME}}

> Decisions + glossary. Loaded on demand, not every session. This is the **sole home for decisions**
> (CLAUDE.md is the always-loaded frame and is never a decision log). The Forge vocabulary is pre-seeded
> below — leave it alone unless you genuinely diverge. Add your project's own terms under ## Project terms.

## Layout terms

**The repo (one)**: A single git repo holds the code, the `.claude/` kit, and the `.forge/` state. No
split outer/app folder; nothing on GitHub. `git` runs bare at the repo root.

**`.forge/`**: All build state, and the **source of truth**. `config` (deploy + PM-hub coords), `seed.md`
(original idea), `tasks/NNN-slug.md` (the queue), `research/`, `continue.md` (continuity journal),
`needs-human.md` (escalations). Committed except the ephemeral run-state (`run-state`, `.ctx`,
`envision.md`, `hook-probe.log` — gitignored).

**Forge config** (`.forge/config`): Written by `light-the-forge`. Holds `DEPLOY_TYPE`, `STACK_DIR`,
`CONTAINER_PORT`, `PM_SLUG`, `PM_HUB_DIR` — the deploy + projection coordinates `/forge` reads.

## Workflow terms

**Task**: One file `.forge/tasks/NNN-slug.md` — the unit of work (was a GitHub issue). Frontmatter carries
`id`, `title`, `thread`, `seq`, `status`, `verify`, and (only when stuck) `escalation`. The body holds the
scope, machine-checkable acceptance criteria, and the constraining decisions threaded in from this file.
**The queue is the set of these files** (order derived from `seq` — there is no separate queue file).

**Task status — three resting states**: `ready` | `done` | `needs-human`. These are the *only* values
persisted to a task file. `forging`/`in-review` are transient run-state (cursor + attempt phase), never
written to the task — so a mid-run interruption can never leave a task lying about its state. Recover a
`needs-human` task by fixing the blocker, setting `status: ready`, and re-running `/forge`.

**Thread**: A vertical slice of the build. `thread: 0` is the **walking skeleton** — the thinnest
end-to-end path that proves the whole stack wires together. `1, 2, …` are feature threads, each ordered
logic-then-UI. `/ponder` sequences thread-order (not layer-order); the **thread is the deploy unit**.

**Walking skeleton**: The first thread — prove end-to-end before any feature work. Its whole purpose is
early runtime validation, so it deploys first.

**Batch**: The set of `ready` tasks `/forge` proposes to work in one run, in `seq` order. You approve (and
may trim) it — **this is the one and only human gate**; autonomy begins at "go". One run drains one batch,
then stops and reports.

**Verification method** (`verify:`): Set per task by `/inscribe`. `test` (new behavior → builder adds
tests; tests/types/lint gate it) | `visual` (UI → reviewer checks a render/screenshot) | `check`
(behavior-preserving refactor/config/docs/chore → no-regression gates on existing test/type/lint, **no
new-test obligation**, adversarial diff review still applies).

**Hard gate**: Objective checks that run before any AI review opinion counts — tests + type-check + lint
(`verify:test`/`check`) or a render (`verify:visual`), **plus a supply-chain check when the diff touches a
dependency manifest** (verify each newly-added package is real, not typosquatted). A failed hard gate is an
automatic FAIL; a builder touching test files to pass is an automatic FAIL + escalation.

**Adversarial reviewer**: A single fresh, read-only, citation-required, bias-to-reject reviewer running a
**different, ≥-capable model** than the builder (Opus reviews Sonnet). That model diversity is the gate's
whole value. No cross-vendor reviewer.

**Per-thread deploy + UAT smoke**: When the cursor crosses a thread boundary (or the batch ends), `/forge`
deploys that thread (`docker compose up` in `STACK_DIR` + health-check on `CONTAINER_PORT`) and runs a
**UAT smoke** exercising the thread's real end-to-end path. Fail → roll back to the **pre-thread** image
and escalate; pass → auto-continue (hands-off).

**Escalation**: A task that can't pass (3 failed rounds, diff >~2× expected scope, touched test/CI config,
`TOO_LARGE`, post-merge revert, or a failed deploy/smoke) is set `status: needs-human` + an `escalation:`
reason, skipped, and appended to `.forge/needs-human.md`. Never blocks the run; bad code never auto-merges.

**Projection (PM hub)**: A one-way, gated, coarse write **up** to the projects.greenfyre.dev hub — gated on
`PM_HUB_DIR` being set and the dir existing, with a clean local-files fallback otherwise. Carries
`deployed_url` + `updated`, the research docs, the needs-human items, and a coarse progress strip. Fine
churn never flows down into the curated roadmap.

**Continuity journal** (`.forge/continue.md`): The single `Now` / `Next` / `Friction` journal, agent-
authored at meaningful boundaries. `Friction` is the staging area for soft "this approach kept failing"
memory; a note that proves durable is **promoted** to `.knowledge/lessons.md`, then dropped.

**Prospect**: The pre-ponder warm-up (`/prospect`, phase 0). Reads the seed (gated by its `status:` flag),
proposes + runs prior-art research on approval, refines the vision, then writes `.forge/research/intake.md`
— the warm hand-off `/ponder` opens from. Writes only local docs (flips the seed flag `todo`→`done`, never
deletes it); nothing outward.

## Project terms

<!-- Add project-specific terms here as you find ambiguity. -->

(none yet — add as you find them)

## Decisions

> Hard-to-reverse, surprising-without-context, genuine-trade-off calls — the ones a future builder would
> otherwise re-litigate. `/ponder` appends them here as they're settled (decision · why · what it rules
> out); `/inscribe` threads the relevant one into the body of any task it constrains, so the builder gets
> it where it works. Skip the routine: only decisions meeting all three criteria earn an entry.

(none yet — add as you settle them)

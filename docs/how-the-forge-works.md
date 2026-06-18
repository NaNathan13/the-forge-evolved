# How The Forge works

The Forge is a per-project, **GitHub-free** Claude Code workflow. You take a fuzzy idea, plan it into local
**task files**, then turn Claude loose to drain an approved batch of them — build, review, squash-merge, and
deploy each — while context stays under a hard ceiling and bad code never reaches `main`. It all lives in
**one git repo**; the local `.forge/` files are the source of truth.

The spine is four commands run in sequence:

```
/prospect  →  /ponder  →  /inscribe  →  /forge
 scout         think        record        build
```

This doc is the one narrative for the whole thing. For the exact mechanics of any command, read its skill
under `.claude/skills/`; this explains how the pieces fit and why.

## The four commands

- **`/prospect`** — the pre-ponder warm-up (phase 0). Reads the kickoff seed (or a fresh idea), proposes
  prior-art research and runs it **on your approval** (a read-only `forge-researcher` subagent), refines the
  vision in conversation, then writes `.forge/research/intake.md` — the findings `/ponder` opens from — and
  recommends you run `/ponder`. Reusable before any new idea; writes only local docs, nothing outward.

- **`/ponder`** — grill a fuzzy idea into shared understanding, one question at a time, researching unknowns
  on demand. It slices the work into **vertical threads** — the thinnest end-to-end *walking skeleton* first
  (`thread: 0`, proving the whole stack wires together), then feature threads, each ordered logic-before-UI.
  It pins terms and decisions to `CONTEXT.md` as it goes, ends by proposing the task breakdown (title, thread,
  scope, verify method, machine-checkable acceptance criteria per slice), and waits for a one-word approval.

- **`/inscribe`** — on that approval, it writes one **task file** per slice into `.forge/tasks/NNN-slug.md` —
  frontmatter (`status: ready`, exactly one `verify: test|visual|check`, `thread`, `seq`) plus acceptance
  criteria in the body — in thread order, and threads ponder's already-recorded decisions (pinned in
  `CONTEXT.md`) into the tasks they bind, since a builder reads its task file, not the glossary. **The queue
  is just the set of these files** — order is derived from `seq`, so there's no separate queue file to drift.

- **`/forge`** — self-heals its state, reads the `status: ready` task files, proposes them as a **batch**, and
  waits. Batch approval is the one human gate — the moment autonomy begins. After "go" it works each task to
  merge or escalation, deploys each completed thread, then **stops and reports**. It never auto-chains.

Run them in order. Don't `/forge` an empty queue — `/prospect` → `/ponder` → `/inscribe` fill it first.

## The forge loop

`/forge` is a **thin orchestrator**. It holds only three distilled things: the batch list, a one-line status
per task (`#007 merged`, `#008 round 2`, `#009 RESLICE`), and the run-state (cursor + attempt + phase). It
never accumulates a builder's or reviewer's transcript — it dispatches a subagent, keeps only the distilled
return, acts, and moves on. That flatness is what makes context discipline structural rather than a fight.

**Step 0 — self-healing reconcile.** On every start it runs three cheap in-repo checks and auto-fixes the safe
ones: advance the cursor past tasks already `done`, mark a `ready` task whose work is already in `main` as
`done`, and surface orphan `forge/task-*` branches (deleting only on confirmation, never force-dropping
unmerged work). This is the old `/scrub`, folded in.

Then, for each task in the approved batch (sequentially — one at a time):

1. **Branch** off a clean, up-to-date `main` as `forge/task-<id>` (retries get `-r2`, `-r3`; the resolved name
   is recorded in run-state and reused everywhere). Set `phase=forging` in run-state — **never** in the task
   file. The task file only ever rests at `ready`, `done`, or `needs-human`; `forging`/`in-review` are
   transient, so a mid-run interruption can't leave a task lying about its state.
2. **A fresh `forge-builder`** (a Sonnet subagent) implements the task on that branch, given only the
   acceptance criteria + constraining decisions, the verify method, and the relevant lines of
   `.knowledge/lessons.md`. It stays in scope, commits its work, and returns a distilled `DONE` / `TOO_LARGE`
   / `BLOCKED`.
3. **Hard gates run first, before any review opinion counts.** For `verify:test` that's the project's test +
   type-check + lint; for `verify:check` the same gates must keep passing **unchanged** (no new tests — the
   change is behavior-preserving); for `verify:visual` it's a render/screenshot capture. **Plus a
   supply-chain check** whenever the diff touches a dependency manifest — each newly-added package must really
   exist (no invented/typosquatted names). A failed gate, or any test/CI-file tampering, is an automatic FAIL.
4. **A fresh, read-only `forge-reviewer`** (an Opus subagent — deliberately a *different, ≥-capable model*
   than the builder, with no Edit/Write/Bash so it structurally cannot make the code pass) gets only the
   acceptance criteria, the git diff (computed for it), the verify method, and the same lessons. It returns an
   adversarial **per-criterion PASS/FAIL with cited diff lines** and a final APPROVE/REJECT. That model
   diversity is the gate's whole value — there's deliberately no cross-vendor reviewer.
5. On **REJECT** with rounds remaining, a fresh builder retries against the cited failures — and on a retry it
   may not edit test files at all. **At most 3 builder→reviewer rounds.**
6. On **APPROVE**, **squash-merge into `main` locally** (no PR, no remote — GitHub is gone), capture the
   squash SHA, and run the test suite **post-merge**. Pass → flip the task to `status: done` and commit the
   state change. Fail → **revert the squash** and escalate; a reverted change is not done.

Every task ends one of two ways: merged, or escalated. There is no partial merge.

## Per-thread deploy + UAT smoke

The **thread is the deploy unit.** When the cursor crosses a thread boundary (the next task's `thread` differs,
or the batch ends), `/forge` deploys the thread that just completed: `docker compose up --build` in
`STACK_DIR`, a health-check on `CONTAINER_PORT`, then a **UAT smoke** that exercises the thread's *real
end-to-end path* — not just a health curl. The walking skeleton deploying first gives early runtime proof that
the whole stack wires together; each feature thread gets incremental runtime validation.

Deploy or smoke **fails** → roll back to the **pre-thread image** (revert the thread's commits, redeploy) and
escalate — a natural stop. **Passes** → project to the PM hub (if configured) and auto-continue, hands-off.

## Task files — the state machine

The task files *are* the state machine; there's no board.

- **`status:`** rests at exactly one of three states — `ready` → `done`, or `ready` → `needs-human`. The
  transient `forging`/`in-review` phases live only in `.forge/run-state`, never in the file.
- **`verify:`** is set once at inscribe time: `test` (new behavior — builder adds tests, tests/types/lint gate
  it), `visual` (UI — judged on a render/screenshot), or `check` (behavior-preserving refactor/config/docs/
  chore — no new tests, existing gates must keep passing).
- **`thread` / `seq`** carry the vertical-slice grouping (the deploy unit) and the global build order.
- **`escalation:`** is set only when a task goes `needs-human`, with the one-line reason.

## Context discipline

The workflow treats the context window as a hard resource, not a soft suggestion.

- **Warn at 40%, hard-stop at 50%** of the window. The statusline shows a gauge; a `ctx-gate` PreToolUse hook
  *enforces* the backstop — it denies tool calls at ≥50%. The 40% warn is visual-only, so the checkpoint write
  it asks for is never blocked by the gate.
- **Resume is `/clear` + re-run the command.** It works because state of record lives outside the session —
  in the **`.forge/` files + git** — so a re-run reads the task files + `run-state`, self-heals (step 0), and
  picks up at the cursor. The interactive phases checkpoint to `.forge/research/intake.md` (prospect) and
  `.forge/continue.md` (ponder/the continuity journal).
- The orchestrator rarely hits the ceiling because it stays thin; the in-loop pressure valve is the builder's
  `TOO_LARGE` signal. Interactive skills self-checkpoint at the 40% warn, before they can get blocked mid-action.

## Continuity

`.forge/continue.md` is a single agent-authored journal — `Now` / `Next` / `Friction` — that carries the
in-flight thread and a rolling soft "this approach kept failing" memory across sessions. A friction note that
proves durable is **promoted** to `.knowledge/lessons.md`, then dropped. SessionStart auto-inject and
PreCompact/Stop auto-commit of this file are wired by default — a one-time hook-firing probe confirmed the
web harness fires SessionStart and Stop (2026-06-18). PreCompact is wired too but untested (it only fires on a
compaction the 40/50 rule avoids). The agent also maintains the journal directly, so even where a hook doesn't
fire, nothing breaks. (`_probe.sh` ships as an optional diagnostic that logs events to `.forge/hook-probe.log`.)

## Escalation — never block, never auto-merge bad code

Escalation is the safety valve, and it never means "wait for a human mid-run." Anything that can't pass
cleanly is set to `status: needs-human` plus an `escalation:` reason, appended to `.forge/needs-human.md`,
skipped, and surfaced in the end-of-batch report — the loop keeps going. Triggers:

- **3 failed builder→reviewer rounds** → `review-failed`.
- **Too large for one fresh context** (the builder's `TOO_LARGE`) or a diff exceeding ~2× expected scope →
  `needs-reslice` (a *human* reslice — auto-reslice would fight the one-gate philosophy).
- **Test/CI-file tampering** → automatic FAIL and escalation.
- **A supply-chain miss** (invented/typosquatted dependency) → automatic FAIL.
- **Post-merge tests fail** → the squash is reverted and the task escalated.
- **A thread's deploy/UAT smoke fails** → roll back to the pre-thread image and escalate.

The invariant: a failing task escalates rather than merging. Bad code never lands on `main`. The recovery path
is yours — fix the blocker, set the task's `status` back to `ready`, and re-run `/forge`.

When the batch is drained, `/forge` **stops and reports** — per task, the outcome (merged / escalated-with-
reason / remaining) plus round count and builder/reviewer context%. The next run is a deliberate human
inflection point.

## Knowledge — where things live

Five files, each with one job (sharp boundaries on purpose):

- **`CLAUDE.md`** — the always-loaded frame only: scope, "done", conventions, verify commands, pointers.
  **Never a decision log.**
- **`CONTEXT.md`** — the **sole** home for decisions + glossary (load-on-demand).
- **`.knowledge/lessons.md`** — durable, promoted codebase facts (high bar; most runs add nothing). At
  dispatch the orchestrator feeds the *relevant lines* to the fresh builder and reviewer.
- **`.forge/continue.md`** — the continuity journal; its `Friction` section is the staging area for lessons.
- **`.forge/research/`** — research findings (also projected to the PM hub `documents/` if present).

## The PM hub — an optional projection

The source of truth is always the local `.forge/` files. If a PM hub is configured (`PM_HUB_DIR` set and the
dir exists, plus `PM_SLUG`), `/forge` **projects up** to it after a thread deploys: it writes `deployed_url` +
a coarse progress strip to the hub's `meta.yml`, copies research into `documents/`, renders the needs-human
items into `actions.yml`, and commits in the hub repo with a `content: <slug> …` subject (which feeds the
activity feed). The projection is one-way, gated, and coarse — fine churn never flows down into the curated
roadmap. Absent a hub, the same information sits in local markdown and nothing breaks.

## Install — `/light-the-forge`

You run `light-the-forge.sh` from a new, empty **project folder**; it `git init`s **one repo** there and
installs everything into it — the kit (`.claude/`: skills, agents, hooks, statusline, settings.json), the
`.forge/` state tree (config, seed.md, tasks/, research/, continue.md, needs-human.md), `.knowledge/`, and
CLAUDE.md / CONTEXT.md starters. There is no GitHub side to set up.

Run **`/light-the-forge`** (a thin wrapper around the script, also runnable directly, or via the `curl … |
bash` one-liner in the README). It asks for the project name, description, deploy type (`public`/`internal`),
and an optional initial-research note, shows a confirm step, then scaffolds and commits on `main`. It aborts
rather than clobber an already-forged folder.

After install, fill `STACK_DIR`/`CONTAINER_PORT` in `.forge/config` once the app's stack exists, then open the
project folder in Claude Code and run `/prospect` (it reads the seed the installer left, then sends you into
`/ponder`). The continuity hooks are wired by default (the hook-firing probe passed 2026-06-18). See
`.claude/skills/light-the-forge/SKILL.md`.

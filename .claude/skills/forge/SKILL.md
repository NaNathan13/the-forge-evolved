---
name: forge
description: Phase 3 of the workflow — autonomously drain an approved batch of status:ready task files, one fresh subagent per task (build → hard-gate → adversarial review → squash-merge → post-merge test), self-healing its state on start, then stop and report. The one human gate is batch approval. Triggered by /forge, "run the batch", "forge the ready tasks".
---

# /forge — drain the batch

`/forge` reads the `status: ready` task files in `.forge/tasks/`, proposes a **batch**, and — once you
approve it — works each task to merge or escalation by dispatching a **fresh subagent per task**. Approval is
the one human gate; after that the loop runs hands-off until the batch is drained, then stops and reports.

```
prospect → ponder → inscribe → forge      (forge drains the ready queue)
```

## One repo — read the config first

There is **no GitHub, no board, no split outer/app folder**. Everything is one git repo: `git` runs **bare at
the repo root** (no `-C`). The queue is the set of files in `.forge/tasks/`. The installer wrote the deploy +
projection coordinates to `.forge/config`:

```bash
cat .forge/config    # DEPLOY_TYPE, STACK_DIR, CONTAINER_PORT, PM_SLUG, PM_HUB_DIR
```

`source .forge/config` at the start of any Bash block that uses those vars (env doesn't persist between Bash
calls). All `.forge/` paths are plain repo-relative.

## You are a THIN orchestrator

You hold ONLY three things, all distilled:

- the **batch list** (task ids, in `seq` order),
- a **one-line status** per task (e.g. `#007 merged`, `#008 round 2`, `#009 RESLICE`),
- the **run-state** (cursor + per-task attempt + phase).

You **never** accumulate builder or reviewer transcripts. You dispatch a fresh subagent, keep only its
**distilled return**, act on it, and move on. This flat context is what makes the 40/50 rule *structural*:
the work happens in subagents whose context dies with them, while yours stays nearly empty. If you ever feel
yourself holding a full diff or a builder's reasoning, you're doing it wrong — pass it down, keep the verdict.

State of record lives outside your head: **the task files + git + `.forge/run-state`**.

### `.forge/run-state` (the only ephemeral build state — GITIGNORED)

```
batch=001,002,003          # approved subset for this run
cursor=002                 # task currently being worked
attempt=2                  # builder→reviewer round count for the cursor task
work-branch=forge/task-002-r2   # resolved branch (may carry -r2/-r3)
phase=in-review            # forging | in-review  (TRANSIENT — never written to the task file)
thread=0                   # thread of the cursor task
pre-thread=<sha>           # main SHA when the current thread opened — rollback target for its deploy
```

Keep it current after every step so an interrupted run resumes cleanly. `phase` lives **only** here — a task
file never carries `forging`/`in-review`, so a mid-run interruption can never leave a task lying about its
state. Resume = re-read this + the task files.

## 0. Self-healing reconcile (folded-in /scrub — every start, before anything)

On every invocation, after sourcing config, run three cheap in-repo checks and auto-fix the safe ones,
prompting only on the destructive/ambiguous case:

1. **Stale cursor** — advance the cursor in `run-state` past any task already `status: done`. (A run that
   merged a task but died before advancing.) Safe; auto-fix.
2. **Ready-but-already-merged** — a `status: ready` task whose work is already in `main` (the squash commit
   subject carries `(#<id>)`):
   ```bash
   git log main --grep "(#<id>)" --oneline | head -1   # non-empty => already merged
   ```
   If found, flip that task's frontmatter `status: ready → done`. Safe; auto-fix.
3. **Orphan branch** — a `forge/task-*` branch whose `<id>` has no matching file in `.forge/tasks/`:
   ```bash
   git branch --list 'forge/task-*'
   ```
   **Surface** it; delete **only on explicit confirmation**, and never force-delete an unmerged branch
   (`git branch -d` not `-D` — let git refuse to drop unmerged work).

Then continue. If there's a live `run-state` mid-batch, resume from its cursor; otherwise start at step 1.

## 1. Propose the batch & gate (the one human gate)

Read the `status: ready` task files in `seq` order:

```bash
grep -l 'status: ready' .forge/tasks/*.md
```

List each — **id, title, thread, and `verify:` method** — and **propose them as the batch**, in `seq`
order. Present the list as text, then put the **approval gate through the `AskUserQuestion` tool** so it's
answerable from the Claude phone app / `/remote-control` (a prose question can't be answered there) — one
question, header `Batch`, options like **"Run all N"** and **"Trim the list"** (the user types which to drop
via "Other"). **Stop and wait for that approval. Nothing runs before approval — approval is the moment
autonomy begins.** Do not cut a branch, change a status, or dispatch anything until the user says go.

If the batch contains **`verify:visual`** (UI) tasks, add a one-line note that they build best from a design:
*"#N is UI — if it hasn't been designed yet, `/envision` first will give the builder a screenshot + token
spec to match."* A nudge, not a gate.

## 2. Init/refresh run-state, then loop per task

Write the approved batch to `.forge/run-state` (batch list + `cursor` at the first task + `attempt=1`). Keep
it current after every step. Then, for **each task in `seq` order**, do the following. **Sequential only —
one task at a time** (no parallelism; the clean branch → squash → post-merge gate is the ownership edge).

### a. Branch

Ensure a clean working tree and an up-to-date `main`, then cut the branch:

```bash
git switch main && git pull --ff-only 2>/dev/null || git switch main
git status --porcelain   # must be empty; if not, stop and report — do not build on a dirty tree
git switch -c forge/task-<id>
```

If `forge/task-<id>` already exists from a prior failed attempt, use the next suffix
(`forge/task-<id>-r2`, then `-r3`). **Record the resolved branch as `work-branch` in `run-state`** and use
that recorded name everywhere below — never re-derive it, or a retried `-r2`/`-r3` task points at the wrong ref.

### b. Mark forging (in run-state ONLY)

Set `phase=forging` and `thread=<task's thread>` in `run-state`. **Do not touch the task file's `status`** —
it stays `ready` until it resolves to `done`/`needs-human`. `forging` is transient run-state, never persisted.

If this task **opens a new thread** (its `thread` differs from the last completed task, or it's the batch's
first task), also record `pre-thread=$(git rev-parse main)` in `run-state` — the rollback target if this
thread's per-thread deploy (step j) fails.

### c. Dispatch a fresh forge-builder

Dispatch a **fresh `forge-builder`** subagent. Give it ONLY:

- the task's **acceptance criteria + constraining decisions** (read the task file),
- its **`verify:` method**,
- the fact that it's on the `work-branch` in this single repo (its edits land there),
- the **relevant lines of `.knowledge/lessons.md`** (the facts that bear on this task, not the whole file).

It implements on the current branch and returns a distilled `STATUS: DONE | TOO_LARGE | BLOCKED`.

- **`TOO_LARGE`** (slice outgrew one context) → escalate (step g, reason `needs-reslice`) and move on.
  **Never chain a second builder on the same task.**
- **`BLOCKED`** → escalate (step g, reason = the builder's stated blocker), skip and continue.
- **`DONE`** → proceed to hard gates.

### d. Hard gates — BEFORE any review opinion

Run the **objective** checks yourself, at the repo root. These count before any AI verdict does:

- **`verify:test`** → run the project's **test + type-check + lint** (from `CLAUDE.md`'s *Verification
  commands*). All must pass.
- **`verify:check`** → run the **same** test + type-check + lint and confirm they pass **unchanged** (no new
  tests expected; the change must preserve behavior).
- **`verify:visual`** → capture the **render/screenshot evidence** (note its path for the reviewer).
- **Supply-chain check (all methods) — when the diff touches a dependency manifest** (`package.json`,
  `requirements.txt`, `pyproject.toml`, `go.mod`, etc.): for each **newly-added** package, confirm it really
  exists under that exact name and isn't a brand-new/typosquatted impostor:
  ```bash
  npm view <pkg> version          # node: must resolve
  curl -fsS https://pypi.org/pypi/<pkg>/json >/dev/null   # python: must resolve
  ```
  A package that doesn't resolve (invented/typosquatted) is an **automatic FAIL → escalate** (step g, reason
  `supply-chain: <pkg>`). Near-zero overhead when no deps changed.

**Automatic FAIL — do not even consult the reviewer:**

- a hard gate fails, **or**
- the builder **modified, added, or deleted any test or CI-config file** (check the diff). Test-file
  tampering is an **escalation signal** → step g (`review-failed`), not a review question.

A non-tampering hard-gate failure with rounds remaining is a normal FAIL → retry (step f).

### e. Mark in-review & dispatch a fresh forge-reviewer

Set `phase=in-review` in `run-state`. Compute the diff yourself (the reviewer has no git/bash):

```bash
git diff main...<work-branch>   # the recorded work-branch
```

**Non-empty-diff guard.** If that diff is **empty**, the builder edited but never committed (or did nothing):
nothing to review or merge — do **not** dispatch the reviewer. Treat as a builder failure: rounds remaining
(< 3) → retry (step f); else escalate (step g, reason "builder returned DONE with an empty committed diff").

Dispatch a **fresh `forge-reviewer`** (a **different, ≥-capable model** than the builder — Opus over Sonnet)
and give it ONLY: the task's **acceptance criteria**, the **`git diff`**, the **`verify:` method** (+ the
screenshot path for `verify:visual`), and the **relevant lines of `.knowledge/lessons.md`** (the same
codebase facts — never the builder's reasoning). It returns per-criterion `PASS`/`FAIL` with cited diff lines
and a final `DECISION: APPROVE | REJECT`.

### f. On REJECT, retry if rounds remain (< 3)

If `DECISION: REJECT` and the task has had **fewer than 3** builder→reviewer rounds: re-dispatch a **fresh
`forge-builder`** with the reviewer's **cited failures**, telling it explicitly that **this is a retry round
and it may NOT edit test files.** Then **re-run the hard gates (step d) and the reviewer (step e).** Increment
`attempt` in `run-state`.

### g. Escalate (no partial merge, ever)

Escalate if **any** of: **3 rounds** exhausted without APPROVE; the diff exceeds **~2× the task's expected
scope**; the builder **touched test/CI config**; `TOO_LARGE`/`BLOCKED`; a **supply-chain** failure.

First `git switch main` (the builder's WIP stays on its work-branch — it's not deleted; a recovery re-run
cuts `forge/task-<id>-r2`). Then, on `main`:

1. Edit the task file frontmatter: `status: ready → needs-human`, and set `escalation:` to a one-line reason
   (e.g. `review-failed: criterion 2 never passes`, `needs-reslice: builder hit TOO_LARGE`,
   `supply-chain: <pkg> not on registry`).
2. Append a line to `.forge/needs-human.md`:
   ```
   - [ ] #<id> <reason>: <one-line summary>. Recover: fix, set status: ready, re-run /forge.
   ```
3. **Commit the state change** so the next task cuts from a clean tree:
   ```bash
   git add .forge/tasks/<id>-*.md .forge/needs-human.md && git commit -m "content: task #<id> escalated"
   ```
4. Record it (`#<id> ESCALATED: <reason>`), advance the cursor, and **skip to the next task.**

The recovery path is Nate's: fix the blocker, set the task `status` back to `ready`, re-run `/forge`.

### h. On APPROVE → squash-merge locally → post-merge test → done

No remote, no PR — squash-merge into `main` **locally**:

```bash
git switch main
git merge --squash <work-branch>
git commit -m "<task title> (#<id>)"   # subject carries (#<id>) — feeds step-0 reconcile + activity
SQUASH_SHA=$(git rev-parse HEAD)
git branch -D <work-branch>            # force: a squash-merge leaves the branch "unmerged" to git's
                                       # ancestry check, but its content is now in main
# run the project's test command at the repo root (post-merge gate)
```

Branch on the result (mutually exclusive):

- **Post-merge tests PASS** → flip the task file `status: ready → done`, then **commit the state change** so
  the next task cuts from a clean tree:
  ```bash
  git add .forge/tasks/<id>-*.md && git commit -m "content: task #<id> done"
  ```
  Record `#<id> merged`.
- **Post-merge tests FAIL** → a reverted change is **not** done. Revert, then escalate:
  ```bash
  git revert $SQUASH_SHA --no-edit
  ```
  Set the task `status: needs-human` + `escalation: post-merge-revert: <summary>`, append to
  `.forge/needs-human.md`, then commit the state change
  (`git add .forge/tasks/<id>-*.md .forge/needs-human.md && git commit -m "content: task #<id> escalated"`).
  Record `#<id> REVERTED`. Do **not** mark it done.

### i. Advance

Update `.forge/run-state` (advance the cursor to the next task, reset `attempt=1`, clear `work-branch`).
Capture the builder's and reviewer's **context% + round count** from their distilled returns, for the report.

### j. Thread boundary — deploy + UAT smoke + project (per completed thread)

A **thread is the deploy unit.** After advancing, check whether the cursor just **crossed a thread boundary**
— the next task's `thread` differs from the one just finished, **or** the batch is now drained. If it did,
the thread that just completed is ready to validate at runtime. (If the next task is the same thread, skip
this step and keep building.)

Only `status: done` tasks count — if every task in the thread escalated, there's nothing to deploy; skip.

**Deploy + health-check** (gated on `STACK_DIR` set — before the stack exists, e.g. an early skeleton, skip
with a one-line note):

```bash
source .forge/config
[ -n "$STACK_DIR" ] || { echo "STACK_DIR unset — skipping deploy for this thread"; }
docker compose -f "$STACK_DIR/compose.yaml" up -d --build
curl -fsS --retry 5 --retry-delay 2 "http://localhost:$CONTAINER_PORT/" >/dev/null   # health-check
```

**UAT smoke** — not just a health curl: exercise the thread's **real end-to-end path** (the thinnest user
journey this thread delivers — e.g. `POST /api/items` then `GET /api/items` returns it). Use the thread's
own acceptance criteria to choose the path.

- **Deploy or smoke FAILS** → roll back to the **pre-thread image** and escalate (don't auto-continue):
  ```bash
  git revert --no-edit "$(grep pre-thread .forge/run-state | cut -d= -f2)"..HEAD   # revert the thread's commits
  [ -n "$STACK_DIR" ] && docker compose -f "$STACK_DIR/compose.yaml" up -d --build  # redeploy the pre-thread image
  ```
  Append a `.forge/needs-human.md` item (`- [ ] thread <n> deploy-failed: <what broke>. Recover: …`), commit
  the state change, record `thread <n> DEPLOY-FAILED`, and **stop the hands-off run** (a failed thread is a
  natural stop — Nate's recovery path).
- **Deploy + smoke PASS** → **project to the PM hub** (below), then **auto-continue** to the next thread.

#### Projection to the PM hub (gated; local fallback otherwise)

Gate on `PM_HUB_DIR` set **and** the dir exists **and** `PM_SLUG` set. If any is missing, the local `.forge/`
files remain the source of truth — print one line and continue (graceful degradation, no error):

```bash
source .forge/config
HUB="$PM_HUB_DIR/projects/$PM_SLUG"
if [ -n "$PM_HUB_DIR" ] && [ -d "$PM_HUB_DIR" ] && [ -n "$PM_SLUG" ] && [ -d "$HUB" ]; then
  : project   # steps below
else
  echo "PM hub not configured — projection skipped; .forge/ files are the source of truth"
fi
```

When projecting, all **one-way (up) and coarse**:

1. **`meta.yml`** — set `deployed_url:` (the thread's live URL), bump `updated:` to `$(date +%F)`, and write a
   **coarse progress strip** `progress: "<n done>/<total> tasks"` (count `status: done` vs all files in
   `.forge/tasks/`). Don't write per-task churn into the curated roadmap.
2. **Research** — `cp .forge/research/*.md "$HUB/documents/" 2>/dev/null` (the findings library).
3. **needs-human → `actions.yml`** — render each unchecked `- [ ]` line in `.forge/needs-human.md` as an
   `items:` entry (`id` from the task `#NNN`, `title` = the summary, `status: open`, `blocking: true`).
4. **Commit in the hub repo** with the activity-feed subject:
   ```bash
   git -C "$PM_HUB_DIR" add -A && git -C "$PM_HUB_DIR" commit -m "content: $PM_SLUG mark deployed"
   ```
   The `content: <slug> …` subject is what the hub's activity feed reads — no fuzzy phase-task writeback.

## 3. Batch end — STOP and report

When the batch is drained, **stop. Do not auto-chain to a next batch** — the next run is a deliberate human
inflection point. Emit a report: **per task, its outcome** (merged / escalated-with-reason / remaining), plus
the **per-task review-round count and builder/reviewer context%**, e.g.:

```
#006 merged          2 rounds   builder 38% / reviewer 22% ctx
#007 RESLICE         (builder hit context on slice — needs-reslice)
#008 ESCALATED       3 rounds   review-failed: criterion 2 never passes
```

Then **clear/finalize** `.forge/run-state`. Re-running `/forge` starts a new batch from the task files.

## Rules

- **One repo, bare `git`.** No GitHub, no PR, no remote, no `-C`. The queue is `.forge/tasks/`; run-state is
  `.forge/run-state`.
- **Task files + git + run-state are the truth.** You hold only distilled state — never a transcript.
- **Three resting states only** (`ready`/`done`/`needs-human`) ever touch a task file. `forging`/`in-review`
  live only in `run-state`.
- **One human gate: batch approval.** After "go", the loop is hands-off until it stops and reports.
- **No partial merges.** A failing task escalates to `needs-human` (+ `needs-human.md`); it never auto-merges.
- **Fresh subagent per task and per retry.** Never continue a `TOO_LARGE` task; never chain builders.
- **Hard gates outrank the reviewer.** A failed gate, a test/CI-file touch, or a supply-chain miss is an
  automatic FAIL.

## 40/50 & resume

You (the orchestrator) rarely hit the context gate because you stay thin. The in-loop pressure valve is the
**builder's `TOO_LARGE`** — when a slice is too big for one fresh context, the builder signals it and you
reslice-escalate rather than push into the dumb zone. If *you* approach the hard stop, resume is simply
**`/clear` then re-run `/forge`**: it reads `.forge/config` + `.forge/run-state` + the task files, self-heals
(step 0), and picks up at the cursor. No handoff doc needed — the state is already external.

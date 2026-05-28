---
name: forge
description: Phase 3 of the workflow — autonomously drain an approved batch of status:ready GitHub issues, one fresh subagent per issue (build → hard-gate → review → squash-merge), then stop and report. The one human gate is batch approval. Triggered by /forge, "run the batch", "forge the ready issues".
---

# /forge — drain the batch

`/forge` reads the `status:ready` issues, proposes a **batch**, and — once you approve it — works each issue
to merge or escalation by dispatching a **fresh subagent per issue**. Approval is the one human gate; after
that the loop runs hands-off until the batch is drained, then stops and reports.

```
ponder → inscribe → forge      (forge drains the ready queue)
```

## Where the code and board live (read this FIRST, every invocation)

This is the **split layout**: Claude runs from the **outer project folder**; the app code is a **subfolder**,
and that subfolder is the only thing on GitHub. The installer wrote the coordinates to `.claude/forge/config`:

```bash
cat .claude/forge/config    # defines APP_DIR (app subfolder) + REPO_SLUG (owner/name) + BOARD_OWNER, PROJECT_NUMBER
```

Two unbreakable rules for every command below (the working dir resets between Bash calls, so be explicit):

- **Every `git` command targets the app repo:** `git -C "$APP_DIR" …` — never bare `git`.
- **Every `gh` command targets the app repo:** add `--repo "$REPO_SLUG"`.
- **Forge state stays in the OUTER folder:** `.claude/forge/loop-state`, `config`, `seed.md` are read/written
  with their plain relative paths (no `-C`).

Because env doesn't persist between Bash calls, **`source .claude/forge/config` at the start of each Bash
block** that uses `$APP_DIR`/`$REPO_SLUG`. The command blocks below assume you've sourced it.

## You are a THIN orchestrator (D6)

You hold ONLY three things, all distilled:

- the **batch list** (issue numbers, in order),
- a **one-line status** per issue (e.g. `#7 merged`, `#8 round 2`, `#9 RESLICE`),
- the **loop-state** (cursor + per-issue attempt count).

You **never** accumulate builder or reviewer transcripts. You dispatch a fresh subagent, keep only its
**distilled return**, act on it, and move on. This flat context is what makes the 30/40 rule *structural*:
the work happens in subagents whose context dies with them, while yours stays nearly empty. If you ever feel
yourself holding a full diff or a builder's reasoning, you're doing it wrong — pass it down, keep the verdict.

State of record lives outside your head: **GitHub issues/labels + git + `.claude/forge/loop-state`**.

## 0. Resume-awareness (first thing, every invocation)

After reading `.claude/forge/config`, read `.claude/forge/loop-state` if present:

```bash
cat .claude/forge/loop-state 2>/dev/null
```

If a batch is mid-flight, **resume from its cursor** — re-read the board for ground truth (`gh issue list`
below) rather than re-proposing or trusting stale notes. If there's no loop-state, or it's finalized, start
fresh at step 1.

## 1. Propose the batch & gate (D5)

```bash
source .claude/forge/config
gh issue list --repo "$REPO_SLUG" --label status:ready --state open
```

List each issue — **number, title, and its `verify:*` tag** — and **propose them as the batch**, in
dependency order (the order they appear / were filed). Then **stop and wait for the user's approval.** The
user may trim the list. **Nothing runs before approval — approval is the moment autonomy begins.** Do not cut
a branch, move a label, or dispatch anything until the user says go.

## 2. Init/refresh loop-state, then loop per issue

Write the approved batch to `.claude/forge/loop-state` (batch list + a `cursor` pointing at the current
issue + a per-issue `attempt` count, starting at 1). Keep it current after every step so an interrupted run
resumes cleanly. Then, for **each issue in the approved order**, do the following.

### a. Branch (D5)

Ensure a clean working tree and an up-to-date `main` **in the app repo**, then cut the branch:

```bash
source .claude/forge/config
git -C "$APP_DIR" switch main && git -C "$APP_DIR" pull --ff-only
git -C "$APP_DIR" status --porcelain   # must be empty; if not, stop and report — do not build on a dirty tree
git -C "$APP_DIR" switch -c forge/issue-<id>
```

If `forge/issue-<id>` already exists from a prior failed attempt, use the next suffix:
`forge/issue-<id>-r2`, then `-r3`, etc.

```bash
git -C "$APP_DIR" switch -c forge/issue-<id>-r2   # only if the base name (or -r2…) is taken
```

**Record the actual resolved branch name as the issue's `work-branch` in `.claude/forge/loop-state`** and use
that recorded name everywhere the branch is referenced below (steps e and h) — never re-derive it, or a
retried `-r2`/`-r3` issue will point at the wrong ref.

### b. Move to forging

Status labels are **mutually exclusive** — always remove the old when adding the new (the sync workflow
moves the board card on the add):

```bash
gh issue edit <id> --repo "$REPO_SLUG" --add-label status:forging --remove-label status:ready
```

### c. Dispatch a fresh forge-builder

Dispatch a **fresh `forge-builder`** subagent. Give it ONLY:

- the issue's **acceptance criteria** (from the issue body — read it with `gh issue view <id> --repo "$REPO_SLUG"`),
- its **`verify:*` method**,
- the **app folder it works in** (`$APP_DIR` — its edits land there, on the current branch),
- the **relevant lines of `.knowledge/lessons.md`** (the facts that bear on this issue, not the whole file).

It implements on the current branch and returns a distilled `STATUS: DONE | TOO_LARGE | BLOCKED` summary.

- **`TOO_LARGE`** (slice outgrew one context — D12) → escalate and move on. **Never chain a second builder
  on the same issue.**
  ```bash
  gh issue edit <id> --repo "$REPO_SLUG" --add-label status:needs-human --add-label needs-reslice --remove-label status:forging
  ```
  Record it (`#<id> RESLICE`) and **skip to the next issue.**
- **`BLOCKED`** → treat as an escalation: same `status:needs-human` move (reason: the builder's stated
  blocker), record the reason, **skip and continue.**
- **`DONE`** → proceed to hard gates.

### d. Hard gates — BEFORE any review opinion (D8)

Run the **objective** checks yourself, **inside the app repo**. These count before any AI verdict does:

- **`verify:test`** → run the project's **test + type-check + lint** commands (read them from the OUTER
  `CLAUDE.md`'s *Verification commands* section). Run them in `$APP_DIR` (e.g. `cd "$APP_DIR" && <test cmd>`).
- **`verify:visual`** → capture the **render/screenshot evidence** (note its path; you'll hand it to the
  reviewer).

**Automatic FAIL** — do not even consult the reviewer in these cases:

- a hard gate fails, **or**
- the builder **modified, added, or deleted any test or CI-config file** (check the diff). Test-file
  tampering is not a review question — it's an **escalation signal** (go straight to step g, `review-failed`).

A non-tampering hard-gate failure with attempts remaining is a normal FAIL → retry (step f).

### e. Move to in-review & dispatch a fresh forge-reviewer

```bash
source .claude/forge/config
gh issue edit <id> --repo "$REPO_SLUG" --add-label status:in-review --remove-label status:forging
git -C "$APP_DIR" diff main...<work-branch>   # the recorded work-branch; compute the diff yourself — the reviewer has no git/bash
```

Dispatch a **fresh `forge-reviewer`** and give it ONLY:

- the issue's **acceptance criteria**,
- the **`git diff`** you just computed (the branch against `main`),
- the **`verify:*` method** (and, for `verify:visual`, the **screenshot path**),
- the **relevant lines of `.knowledge/lessons.md`** (the same codebase facts you gave the builder — D13).
  Never pass the builder's reasoning; lessons are shared facts, not the builder's account of this change.

It returns per-criterion `PASS`/`FAIL` with cited diff lines and a final `DECISION: APPROVE | REJECT`.

### f. On REJECT, retry if rounds remain (< 3) (D8)

If `DECISION: REJECT` and the issue has had **fewer than 3** builder→reviewer rounds: re-dispatch a **fresh
`forge-builder`** with the reviewer's **cited failures**, telling it explicitly that **this is a retry round
and it may NOT edit test files.** Then **re-run the hard gates (step d) and the reviewer (step e).**
Increment the attempt count in loop-state.

### g. Escalate (D7, D8)

Escalate — no partial merge, ever — if **any** of:

- **3 rounds** exhausted without `APPROVE`,
- the diff exceeds **~2× the issue's expected scope**,
- the builder **touched test/CI config** (from step d).

```bash
gh issue edit <id> --repo "$REPO_SLUG" --add-label status:needs-human --add-label review-failed --remove-label status:in-review
gh issue comment <id> --repo "$REPO_SLUG" --body "Escalated: <diff summary> — failing criterion: <cited failure>"
```

Record it (`#<id> ESCALATED: <reason>`) and **skip to the next issue.**

### h. On APPROVE → PR → squash → post-merge test → done (D5)

Pin the PR to the recorded **work-branch** explicitly so it doesn't depend on which branch is checked out:

```bash
source .claude/forge/config
gh pr create --repo "$REPO_SLUG" --base main --head <work-branch> --title "<issue title>" --body "Closes #<id>"
gh pr merge <work-branch> --repo "$REPO_SLUG" --squash --delete-branch
```

`Closes #<id>` in the body auto-links and closes the issue when the PR merges. Then sync `main`, **capture the
squash SHA**, and **run the test suite** on `main` (in the app repo):

```bash
git -C "$APP_DIR" switch main && git -C "$APP_DIR" pull --ff-only
SQUASH_SHA=$(git -C "$APP_DIR" rev-parse HEAD)
# run the project's test command in $APP_DIR
```

Now branch on the result — these two paths are mutually exclusive:

- **Post-merge tests PASS** → the change is done. Reconcile the label so the card lands in **Done** (the PR
  merge may already have closed the issue):
  ```bash
  gh issue edit <id> --repo "$REPO_SLUG" --add-label status:done --remove-label status:in-review
  ```
  Record `#<id> merged`.

- **Post-merge tests FAIL** → a reverted change is **not** done. Revert, then reopen and escalate (the PR's
  `Closes #<id>` already auto-closed the issue):
  ```bash
  git -C "$APP_DIR" revert $SQUASH_SHA --no-edit && git -C "$APP_DIR" push
  gh issue reopen <id> --repo "$REPO_SLUG"
  gh issue edit <id> --repo "$REPO_SLUG" --add-label status:needs-human --add-label review-failed \
    --remove-label status:done --remove-label status:in-review
  gh issue comment <id> --repo "$REPO_SLUG" --body "Post-merge tests failed on main; squash $SQUASH_SHA reverted. Needs human."
  ```
  Record `#<id> REVERTED (post-merge tests failed)`. Do **not** mark it done/merged.

### i. Advance

Update `.claude/forge/loop-state` (advance the cursor) and **capture the builder's and reviewer's
context% + round count** from their distilled returns, for the end-of-batch report (D19).

## 3. Batch end — STOP and report (D18, D19)

When the batch is drained, **stop. Do not auto-chain to a next batch** — the next run is a deliberate human
inflection point. Emit a report: **per issue, its outcome** (merged / escalated-with-reason / remaining),
plus the **per-issue review-round count and builder/reviewer context%**, e.g.:

```
#6 merged          2 rounds   builder 38% / reviewer 22% ctx
#7 RESLICE 41% ctx (builder hit context on slice — needs-reslice)
#8 ESCALATED       3 rounds   review-failed: criterion 2 never passes
```

Then **clear or finalize** `.claude/forge/loop-state`. Re-running `/forge` after this starts a new batch from
the board.

## Rules

- **Read `.claude/forge/config` first.** `git` → `git -C "$APP_DIR"`; `gh` → `gh … --repo "$REPO_SLUG"`.
  Forge state (loop-state) stays in the outer folder.
- **Issues + labels + git + loop-state are the truth.** You hold only distilled state — never a transcript.
- **One human gate: batch approval.** After "go", the loop is hands-off until it stops and reports.
- **Label transitions always pair add + remove** (`status:*` is mutually exclusive).
- **No partial merges.** A failing issue escalates to `status:needs-human`; it never auto-merges.
- **Fresh subagent per issue and per retry.** Never continue a `TOO_LARGE` issue; never chain builders.
- **Hard gates outrank the reviewer.** A failed gate, or any test/CI-file touch, is an automatic FAIL.

## 30/40 & resume

You (the orchestrator) rarely hit the context gate because you stay thin. The in-loop pressure valve is the
**builder's `TOO_LARGE`** — when a slice is too big for one fresh context, the builder signals it and you
reslice-escalate rather than push into the dumb zone. If *you* approach the hard stop, the resume mechanism
is simply **`/clear` then re-run `/forge`**: it reads `.claude/forge/config` + `.claude/forge/loop-state` +
the board and picks up at the cursor. No handoff doc needed — the state is already external.

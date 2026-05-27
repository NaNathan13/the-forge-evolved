# How The Forge Evolved works

The Forge Evolved is a per-project, GitHub-native Claude Code workflow. You take a fuzzy idea, plan
it into GitHub issues, then turn Claude loose to drain an approved batch of them — build, review, and
merge each one — while context stays under a hard ceiling and bad code never reaches `main`.

The whole system is three commands run in sequence:

```
/ponder  →  /inscribe  →  /forge
 think       record        build
```

This doc is the one narrative for the whole thing. For the exact mechanics of any command, read its
skill under `.claude/skills/`; this explains how the pieces fit and why.

## The three commands

- **`/ponder`** — grill a fuzzy idea into shared understanding, one question at a time, researching
  unknowns on demand (via a read-only `forge-researcher` subagent). It writes no code and touches no
  GitHub; it ends by proposing the issue breakdown — title, scope, UI-vs-logic split, verification
  method, and machine-checkable acceptance criteria per slice — and waits for a one-word approval.
  See `.claude/skills/ponder/SKILL.md`.

- **`/inscribe`** — on that approval (same session, or standalone from a handoff), it records the
  durable decisions where they belong (project docs / CLAUDE.md, and a one-line lesson only if a
  hard-won codebase fact emerged) and creates one GitHub issue per slice — each labeled
  `status:ready` + exactly one `verify:test`/`verify:visual`, with acceptance criteria in the body
  and a card added to the board, in dependency order (logic before the UI that depends on it).
  See `.claude/skills/inscribe/SKILL.md`.

- **`/forge`** — reads the `status:ready` issues, proposes them as a **batch**, and waits. Batch
  approval is the one human gate — the moment autonomy begins. After "go" it works each issue to
  merge or escalation hands-off, then **stops and reports**. It never auto-chains to the next batch.
  See `.claude/skills/forge/SKILL.md`.

Run them in order. Don't `/forge` an empty queue — `/ponder` then `/inscribe` fill it first.

## The forge loop

`/forge` is a **thin orchestrator**. It holds only three distilled things: the batch list, a one-line
status per issue (`#7 merged`, `#8 round 2`, `#9 RESLICE`), and the loop cursor. It never accumulates a
builder's or reviewer's transcript — it dispatches a subagent, keeps only the distilled return, acts,
and moves on. That flatness is what makes context discipline structural rather than a constant fight.

For each issue in the approved batch:

1. **Branch** off a clean, up-to-date `main` as `forge/issue-<id>` (retries get `-r2`, `-r3`; the
   resolved name is recorded in loop-state and reused everywhere). Move the label to `status:forging`.
2. **A fresh `forge-builder`** (a Sonnet subagent) implements the issue on that branch, given only the
   acceptance criteria, the verify method, and the relevant lines of `.knowledge/lessons.md`. It stays
   in scope and returns a distilled `DONE` / `TOO_LARGE` / `BLOCKED`.
3. **Hard gates run first, before any review opinion counts.** For `verify:test` that's the target
   project's test + type-check + lint; for `verify:visual` it's a render/screenshot capture. A failed
   gate is an automatic FAIL. The builder modifying, adding, or deleting any test or CI-config file is
   an automatic FAIL *and* an escalation — not a review question.
4. **A fresh, read-only `forge-reviewer`** (an Opus subagent — deliberately a *different model* than
   the builder, and with no Edit/Write/Bash, so it structurally cannot make the code pass) gets only
   the acceptance criteria, the git diff (computed for it), the verify method, and the same lessons.
   It returns an adversarial **per-criterion PASS/FAIL with cited diff lines** and a final
   APPROVE/REJECT. A FAIL with no diff citation is ignored; APPROVE requires every criterion to pass.
5. On **REJECT** with rounds remaining, a fresh builder retries against the cited failures — and on a
   retry it may not edit test files at all. **At most 3 builder→reviewer rounds.**
6. On **APPROVE**, open a PR (`Closes #<id>`) and **squash-merge** it. Then sync `main`, capture the
   squash SHA, and run the test suite **post-merge**. Pass → reconcile the label to `status:done`.
   Fail → **revert the squash**, reopen, and escalate; a reverted change is not done.

Every issue ends one of two ways: merged, or escalated. There is no partial merge.

## The board

Labels are the state machine; the board is a synchronized view of them.

- **`status:*`** is mutually exclusive — `ready` → `forging` → `in-review` → `done`, or
  `needs-human`. Every transition pairs an add with a remove.
- **`verify:*`** is set once at inscribe time: `verify:test` (logic/backend — the builder must add
  tests, and tests/types/lint gate it) or `verify:visual` (UI — judged on a render/screenshot plus a
  light objective check).
- **Escalation reasons** are added later: `review-failed` or `needs-reslice`.

A GitHub Actions workflow (`.github/workflows/sync-board.yml`) watches label changes and mirrors them
onto a **Projects v2** board, moving each issue's card into the matching column. The board never drives
state — it reflects the labels. (Because Projects v2 is out of reach for the Actions `GITHUB_TOKEN` and
for fine-grained PATs, the sync runs on a stored **classic PAT** with the `project` scope; see Install.)

## Context discipline

The workflow treats the context window as a hard resource, not a soft suggestion.

- **Warn at 30%, hard-stop at 40%** of the window. The statusline shows a gauge, and a `ctx-gate`
  PreToolUse hook *enforces* it — it denies tool calls at ≥40%. A real gate, not a label.
- **Resume is `/clear` + re-run the command.** It works because state of record lives outside the
  session — in **GitHub issues/labels + git + `.claude/forge/loop-state`** — so a re-run reads the
  board and the cursor and picks up at the next issue. `/ponder` is the one exception (no external
  state yet): it checkpoints to `.claude/forge/handoff.md`.
- The orchestrator rarely hits the ceiling because it stays thin; the in-loop pressure valve is the
  builder's `TOO_LARGE` signal (below). Interactive skills self-checkpoint at ~35%, before they can
  get blocked mid-action.

## Escalation — never block, never auto-merge bad code

Escalation is the safety valve, and it never means "wait for a human mid-run." Anything that can't
pass cleanly is labeled `status:needs-human` plus a reason, skipped, and surfaced in the end-of-batch
report — the loop keeps going. Triggers:

- **3 failed builder→reviewer rounds** → `review-failed`.
- **Too large for one fresh context** (the builder's `TOO_LARGE`) or a diff exceeding ~2× expected
  scope → `needs-reslice`. Never continue or chain a second builder on a too-large issue.
- **Test/CI-file tampering** → automatic FAIL and escalation (`review-failed`).
- **Post-merge tests fail** → the squash is reverted, the issue reopened and escalated.

The invariant: a failing issue escalates rather than merging. Bad code simply never lands on `main`.

When the batch is drained, `/forge` **stops and reports** — per issue, the outcome (merged /
escalated-with-reason / remaining) plus round count and builder/reviewer context%. The next run is a
deliberate human inflection point.

## Knowledge

There is exactly one knowledge store: a capped, append-only **`.knowledge/lessons.md`** — one line per
hard-won, reusable fact about *this* codebase (a non-obvious gotcha, a binding constraint). The bar to
add is high; most forge runs add nothing. At dispatch, the orchestrator feeds the *relevant lines* (not
the whole file) to the fresh builder and reviewer so they don't re-hit the same wall. It's distinct
from inscribe's doc-writing — lessons are codebase facts, not idea-specific plans (those live in the
issue), and never the builder's reasoning about a change.

## Recovering from drift — `/scrub`

When a `/forge` run is interrupted (a `/clear` mid-action, a crash between merge and label move), the
three state sources can disagree. **`/scrub`** reconciles the GitHub board, git branches, and
`.claude/forge/loop-state`: it detects stale in-flight cards, orphan branches, and bad loop-state
cursors, reports them in one table, and **offers** each safe fix awaiting your confirmation. It is
read-mostly and advisory — it never auto-merges, auto-closes, deletes a branch, or moves a label on its
own. See `.claude/skills/scrub/SKILL.md`.

## Install — `/light-the-forge`

To stand the workflow up on a target repo, run **`/light-the-forge`** (a thin wrapper around
`light-the-forge.sh`, also runnable directly). The script copies the kit (skills, agents, CLAUDE.md /
CONTEXT.md starters — it won't clobber existing docs) and provisions the GitHub side: the Projects v2
board, the `status:*` / `verify:*` labels, the `sync-board.yml` workflow, the repo variables the
workflow reads (`FORGE_PROJECT_ID`, `FORGE_STATUS_FIELD_ID`, the `FORGE_OPT_*` option IDs), and the
`FORGE_PROJECT_PAT` secret.

Two steps genuinely need a human:

- The `gh` CLI must have the **`project`** auth scope (`gh auth refresh -s project`) for the install.
- The sync workflow needs a **classic** PAT with the `project` scope stored as `FORGE_PROJECT_PAT`
  (add `repo` for a private target). Fine-grained PATs cannot drive Projects v2; until the secret
  exists, the labels→board sync won't run, though the rest of the install is already in place.

After a clean install, the next step is `/ponder`. See `.claude/skills/light-the-forge/SKILL.md`.

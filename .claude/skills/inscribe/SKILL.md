---
name: inscribe
description: Phase 2 of the workflow — on /ponder's confirmation, write one task file per slice into .forge/tasks/ (frontmatter + machine-checkable acceptance criteria) in thread order, threading ponder's already-recorded decisions into the tasks they bind. Invoked by /ponder on "go"; also callable standalone when the breakdown is already settled. Triggered by /inscribe, "write it up", "create the tasks".
---

# /inscribe — write the task files, carry the decisions in

`/inscribe` turns the breakdown `/ponder` approved into **task files** in `.forge/tasks/`, carrying ponder's recorded decisions into the ones they bind. It's the bridge between thinking and building. It runs on `/ponder`'s confirmation (same session), or standalone when an approved breakdown already exists.

```
prospect → ponder → inscribe → forge      (inscribe writes the task files and fills the ready queue)
```

If invoked standalone in a fresh context, read `.forge/continue.md` first to recover the idea and thread breakdown, and `CONTEXT.md` (`## Project terms`, `## Decisions`) for the vocabulary and decisions ponder already pinned.

## Where things live

One repo — no GitHub, no board, no split outer/app folder. The task queue is just **the set of files in `.forge/tasks/`** (there is no separate queue/roadmap file — order is derived from each task's `seq`). Project docs you edit in step 1 (`CLAUDE.md` / `CONTEXT.md` / `.knowledge/`) live at the repo root.

## 1. Carry the knowledge into the tasks (don't re-document it)

`/ponder` already pinned the vocabulary and the qualifying decisions into `CONTEXT.md` (`## Project terms`, `## Decisions`) during the interview. Your job is to **deliver** that knowledge where the builder will actually meet it, and to capture only what ponder didn't:

- **Thread the constraining decisions into the tasks.** For each slice, check `CONTEXT.md` `## Decisions` for a call that binds it — a builder reads its task file, not the glossary. Quote the relevant decision (decision · why · what it rules out) into that task's `## Constraining decisions` block so the constraint travels with the work.
- **CLAUDE.md — only the gaps.** If a durable call (scope, the shape of "done", an architecture convention) belongs in `CLAUDE.md` and isn't already there or in `CONTEXT.md`, fold it into the right existing doc. Don't re-record what ponder already wrote; don't spawn redundant files.
- **`.knowledge/lessons.md`** — append a **one-line** lesson **only if** a hard-won, reusable fact about *this codebase* emerged (a non-obvious gotcha, a binding constraint). **HIGH BAR — usually nothing.** Idea-specific detail belongs in the task, not here.

## 2. Write each task file

Process slices in **thread order** (the walking skeleton `thread: 0` first, then each feature thread logic-before-UI). For each slice, write a file `.forge/tasks/<id>-<slug>.md` where `<id>` is a zero-padded 3-digit number and `<slug>` is the slugified title.

Pick the next `id` from the existing queue (highest `NNN` + 1, else `001`):

```bash
last=$(ls .forge/tasks/ 2>/dev/null | grep -oE '^[0-9]{3}' | sort -n | tail -1)
printf '%03d\n' "$(( 10#${last:-0} + 1 ))"   # the next id
```

Then write the file (use the Write tool) with this exact shape:

```markdown
---
id: 001
title: Walking skeleton — create + list one item end to end
thread: 0                 # 0 = walking skeleton; 1, 2, … = feature threads
seq: 1                    # global ordering (the queue's sort key)
status: ready             # ALWAYS ready at creation (the only resting state inscribe sets)
verify: test              # test | visual | check  — exactly one
escalation:               # leave blank; /forge sets it only on escalation
---

## Scope
<one or two lines: what's in this slice>

## Acceptance criteria (machine-checkable)
- `GET /api/items` returns 200 with a JSON array
- …

## Constraining decisions
> <decision · why · what it rules out — quoted from CONTEXT.md ## Decisions if one binds this task; omit the block if none does>
```

- **`status:` is always `ready`** at creation — the only resting state inscribe sets. It never writes `done`/`needs-human` (that's `/forge`) and never writes the transient `forging`/`in-review` (those are run-state, never persisted to a task file).
- **`verify:` is exactly one** of:
  - `test` — new behavior; the builder must add tests and tests/types/lint gate it.
  - `visual` — UI; the reviewer checks a render/screenshot.
  - `check` — behavior-preserving (refactor/config/infra/docs/chore); **no new tests required**, but existing test+type+lint must keep passing and the diff still gets adversarial review.
- **`thread:` and `seq:`** come straight from ponder's approved thread-order: `thread` groups the vertical slice (the deploy unit); `seq` is the global build order (1, 2, 3, … across all threads). Keep `seq` ascending in thread order so `/forge` drains them correctly.
- The **acceptance criteria** must be objective, verifiable conditions a builder can prove and a reviewer can check — never "works correctly".

## 3. Report back

Report the created task ids in `seq` order, with their verify methods and threads. That's the handoff:

> Wrote #001 (t0, verify:test), #002 (t1, verify:test), #003 (t1, verify:visual). All `status: ready`. Run `/forge` to build them.

If any **`verify:visual`** (UI) tasks were created, add a one-line signpost — those screens want designs first:

> #003 is UI — consider `/envision` to design the screens before `/forge` builds them.

## Rules

- **Task files are the unit.** No separate plan/queue file — the worked-out plan lives in the docs + the task files + their acceptance criteria. The queue order is derived from `seq`.
- **Don't re-document.** ponder already wrote the glossary + decisions to `CONTEXT.md`; inscribe *delivers* the constraining decisions into the tasks that need them — it doesn't copy them back into `CONTEXT.md`.
- **Thread order.** Walking skeleton first; logic/backend before the UI that depends on it; `seq` ascending.
- **Acceptance criteria must be machine-checkable.** No "works correctly" — objective conditions only.
- **Exactly one `verify:`** per task (`test` | `visual` | `check`), `status: ready`, with `thread`/`seq` set.
- **High bar for lessons.** Append to `.knowledge/lessons.md` only for a genuinely reusable codebase fact — usually nothing.
- **No code.** `/inscribe` records and files the work; `/forge` builds it.

## Context for later phases

Builders work each task on a branch named **`forge/task-<id>`** (where `<id>` is the task's zero-padded id). Inscribe doesn't create branches — this is just so the acceptance criteria and naming line up with what `/forge` will do.

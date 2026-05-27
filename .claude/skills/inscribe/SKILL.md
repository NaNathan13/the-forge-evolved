---
name: inscribe
description: Phase 2 of the workflow — on /ponder's confirmation, document the worked-out knowledge where it belongs, then create one GitHub issue per slice (labels + machine-checkable acceptance criteria + board card) in dependency order. Invoked by /ponder on "go"; also callable standalone when the breakdown is already settled. Triggered by /inscribe, "write it up", "create the issues".
---

# /inscribe — record the knowledge, create the issues

`/inscribe` turns the breakdown `/ponder` approved into durable docs and GitHub issues. It's the bridge between thinking and building. It runs on `/ponder`'s confirmation (same session), or standalone when an approved breakdown already exists.

```
ponder → inscribe → forge      (inscribe records the plan and fills the ready queue)
```

If invoked standalone in a fresh context, read `.claude/forge/handoff.md` first to recover the idea, decisions, and slice breakdown.

## 1. Document the worked-out knowledge

Put the knowledge where it belongs so `/forge` and future sessions reuse it instead of re-deriving it:

- **Project docs / CLAUDE.md** — fold in the durable decisions: scope, the shape of "done", architecture calls, any conventions settled during ponder. Edit the right existing doc; don't spawn redundant files.
- **`.knowledge/lessons.md`** — append a **one-line** lesson **only if** a hard-won, reusable fact about *this codebase* emerged (a non-obvious gotcha, a binding constraint). **HIGH BAR — usually nothing.** Idea-specific detail belongs in the issue, not here.

## 2. Create each GitHub issue

Process slices in **dependency order** (logic/backend before the UI that depends on it). For each:

```bash
gh issue create \
  --title "<imperative title>" \
  --body "<scope + machine-checkable acceptance criteria>" \
  --label "status:ready" \
  --label "verify:test"   # OR verify:visual — exactly one
```

- The **body** must contain the **machine-checkable acceptance criteria** — objective, verifiable conditions a builder can prove and a reviewer can check.
- Labels at creation: **`status:ready`** plus **exactly one** of `verify:test` / `verify:visual`. Nothing else. `verify:test` for logic/backend (tests prove it), `verify:visual` for UI (render/screenshot).
- Then add the issue to the project board:

```bash
gh project item-add <project-number> --owner <owner> --url <issue-url>
```

(Capture the issue URL/number from `gh issue create` output; resolve the project/owner from repo config if not already known.)

## 3. Report back

Report the created issue numbers in dependency order, with their verify labels. That's the handoff:

> Created #12 (verify:test), #13 (verify:test), #14 (verify:visual). All `status:ready` and on the board. Run `/forge` to build them.

## Label taxonomy (be aware; inscribe only sets the creation subset)

- **`status:*`** (mutually exclusive — one at a time): `status:ready` | `status:forging` | `status:in-review` | `status:done` | `status:needs-human`. The `/forge` loop manages transitions later.
- **`verify:*`**: `verify:test` | `verify:visual`.
- **Escalation reasons** (set later, never here): `needs-reslice` | `review-failed`. See CONTEXT.md: *escalation*.

**Inscribe only ever SETS `status:ready` + one `verify:*` at creation.** It never touches status transitions or escalation labels.

## Rules

- **Issues are the unit.** No plan files — the worked-out plan lives in the docs + the GitHub issues + their acceptance criteria.
- **Dependency order.** Logic/backend issues before the UI that depends on them.
- **Acceptance criteria must be machine-checkable.** No "works correctly" — objective conditions only.
- **Exactly one `verify:*` per issue**, plus `status:ready`. No other labels at creation.
- **High bar for lessons.** Append to `.knowledge/lessons.md` only for a genuinely reusable codebase fact — usually nothing.
- **No code.** `/inscribe` records and files the work; `/forge` builds it.

## Context for later phases

Builders work each issue on a branch named **`forge/issue-<id>`** (where `<id>` is the issue number). Inscribe doesn't create branches — this is just so the acceptance criteria and naming line up with what `/forge` will do.

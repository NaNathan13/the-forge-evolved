---
name: scrub
description: Tidy up after the workflow — reconcile plan-state drift in .claude/plans/, flag plans that look done-but-unsealed, re-render stale progress bars, strip leftover debug markers, and report a dirty tree. Use after a forge/temper cycle, when things feel cluttered, or via /scrub.
---

# /scrub — tidy up

Core keeps almost no runtime state, so there's little to scrub by design — no worktrees, no continuation files, no token logs. What `/scrub` does is keep the **plan files honest** and sweep up the few kinds of cruft that actually accumulate. It's safe: it applies only deterministic fixes automatically, and merely *flags* anything that would move or remove your work.

Runs inline. No subagents.

## What it checks

### 1. Plan-state drift — `.claude/plans/active/*.md`

For each active plan:

- **Done-but-unsealed.** Every slice `[x]` and the bar reads `N/N`, but the file is still in `active/` → flag: "plan `<slug>` looks complete — run `/seal` to archive it." Don't move it; sealing is `/seal`'s job (it commits).
- **Stale progress bar.** The bar's filled-cell count doesn't match the number of checked boxes → **re-render it** (filled = `round(done / total × 10)`, `█`/`░`). Safe, purely derived — fix it in place.
- **Checklist ↔ slices mismatch.** The number of `- [ ]` / `- [x]` items differs from the count of `## Slice N:` sections, or their titles diverge → flag for the operator (don't guess which is right).
- **Frontmatter vs. location.** `status: done` but the file sits in `active/` (or `status: active` in `done/`) → flag.
- **Empty plan.** Zero slices → flag as likely abandoned.

### 2. Leftover debug markers

Grep the repo for `[DEBUG-` (the marker convention `/diagnose` uses). Report any hits as `file:line` so they can be removed before they ship. Don't auto-delete — they may be intentional.

### 3. Working tree

If `git status` is dirty, report the uncommitted paths — a phase may have been interrupted mid-run. Don't auto-commit; just surface it so the operator decides.

### 4. Junk files

Remove obvious cruft that slipped past `.gitignore`: `.DS_Store`, editor swap files (`*.swp`, `*~`). Only these known-safe patterns, and never anything tracked by git.

## How it behaves

1. **Report first.** Print a short findings list grouped by the four checks above.
2. **Apply safe fixes inline** — re-render a stale bar, delete a `.DS_Store`. State what you fixed.
3. **Flag, don't touch, anything that moves or removes work** — sealing a plan, deleting an abandoned plan, removing a debug marker. Print the command the operator should run.
4. **End with a one-line summary**: what was fixed, what was flagged. If nothing's wrong, say so in one line.

## Rules

- **Never delete a plan file.** Flag abandoned ones; the operator removes them.
- **Never auto-seal or auto-commit.** Those are phase commands.
- **Only auto-remove the known-junk patterns** in check 4 — nothing tracked by git, nothing else.
- **Leave `.gitkeep` alone** in `active/` and `done/` — it keeps the empty dirs tracked.

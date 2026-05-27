---
name: seal
description: Phase 4 of the workflow — finish a plan. Confirms every slice is done, marks the plan done, moves it from active/ to done/, and makes the final commit. Triggered by /seal after /temper.
---

# /seal — finish the plan

`/seal` is the **closer phase** — last look, then it's done. It confirms the work is complete and archives the plan. Inline — no subagents, no merge.

```
Ponder → Forge → Temper → Seal      (the Ponder phase = /ponder then /inscribe)
```

## What it does

1. **Pick the plan.** Same rule: most-recently-modified active plan, or the named one.

2. **Confirm it's done.** Every slice in the progress block must be `- [x]` and the bar should read `N/N`. If any slice is still unchecked:

   > Plan `<slug>` has unfinished slices (<list>). Run `/forge` to finish them, or confirm you want to seal anyway.

   Don't archive a half-done plan without the operator saying so.
   For an app that keeps records, also confirm `/temper` verified persistence (a record survives a restart) — don't seal a record-keeping app whose data could vanish; if unsure, send it back to `/temper`.

3. **Mark and move.** Flip the frontmatter and relocate the file:

   ```bash
   # status: active  →  status: done   (edit in place first)
   git mv .claude/plans/active/<slug>.md .claude/plans/done/<slug>.md
   ```

4. **Final commit:**

   ```bash
   git add -A
   git commit -m "chore(<slug>): seal plan"
   ```

   Work in place — no push. If you want the work on a remote, that's a manual `git push` afterward.

5. **Done:**

   > Sealed `<slug>` — archived to `.claude/plans/done/`. <N> slices shipped.

## Rules

- **All slices done first.** Don't archive unfinished work unless the operator explicitly says to.
- **Move, don't copy.** The plan leaves `active/` so the directory stays a clean ledger of in-flight work.
- **Work in place.** Local commit only. No branches, no push, no GitHub.
- **One plan per `/seal`.**

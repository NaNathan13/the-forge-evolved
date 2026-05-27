---
name: inscribe
description: Write the plan file from resolved /ponder decisions and slice it into parts. Creates a single markdown plan under .claude/plans/active/<slug>.md with a progress block and one section per slice. Sub-skill of the planning phase; also callable standalone when the work is already clear. Triggered by /inscribe, "write the plan", "write it up".
---

# /inscribe — write and slice the plan

`/inscribe` records the understanding reached in `/ponder` as a plan file, broken into slices. It's the bridge between thinking and building.

```
Ponder → Forge → Temper → Seal      (the Ponder phase = /ponder then /inscribe)
```

## What it does

1. **Pick a slug.** Kebab-case, derived from the plan title (`auth-flow`, `dark-mode`). Refuse if `.claude/plans/active/<slug>.md` already exists — surface it rather than overwrite.

2. **Slice the work.** Break the effort into a handful of coherent slices, each one a chunk you could describe in a sentence. Order them so earlier slices unblock later ones.

3. **Write the file** to `.claude/plans/active/<slug>.md` in exactly this shape:

   ```markdown
   ---
   name: <slug>
   created: <YYYY-MM-DD>
   status: active
   ---

   # <Title>

   ## Progress
   `░░░░░░░░░░` 0/<N>
   - [ ] 1. <slice 1 title>
   - [ ] 2. <slice 2 title>
   - [ ] 3. <slice 3 title>

   ## Goal
   <what we're building and why; what "done" looks like>

   ## Constraints / out of scope
   <anything deliberately not being done>

   ## Research
   <Optional — include only if /ponder actually did research. The key facts that shaped the plan, distilled, with source links. Not a transcript dump. Omit the whole section when no research fired.>

   ## Where your data is kept
   <Plain words: what the app saves and where it lives so it's never lost. e.g. "Your client records are saved on this computer in a file the app keeps — they're still here after you close and reopen it, and after the app restarts." For a tool that saves nothing: "This tool doesn't save anything — it just calculates.">

   ## How this app runs
   <Plain words + the start contract. e.g. "Runs as one small program started with `npm start`, serving on the port it's given." For a static page with no server: "Opens as a single web page — no server needed.">

   ---

   ## Slice 1: <title>
   <detail and acceptance notes>

   ## Slice 2: <title>
   <detail>

   ## Slice 3: <title>
   <detail>
   ```

   The progress bar starts all `░` (10 cells, `0/<N>`). The checklist mirrors the slice headings exactly.

4. **Hand off:**

   > Plan written to `.claude/plans/active/<slug>.md`. Run `/forge` to build it.

## Rules

- **One file per plan.** Everything lives in the single markdown file — no side files, no issues, no PRs.
- **Slices are the unit.** The top checklist and the `## Slice N:` sections must stay in sync (same count, same titles).
- **Don't overwrite.** If the slug exists, stop and tell the operator.
- **No code.** `/inscribe` writes the plan; `/forge` builds it.
- **Record research if it happened.** When `/ponder` leaned on the `research` skill, fold the conclusions that mattered into a `## Research` section (key facts + source links, distilled) so `/forge` and `/temper` reuse them instead of re-investigating. Omit the section entirely when no research fired.
- **Settle storage before slicing.** If the app keeps records the user relies on, the plan MUST specify durable server-side storage (a tiny built-in server + a JSON data file, or SQLite for large/relational data) — never browser-only storage — and the slices must build it. Record the choice in plain words in "Where your data is kept". Follow the build doctrine in `CLAUDE.md`.

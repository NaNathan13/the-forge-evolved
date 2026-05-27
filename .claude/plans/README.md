# Plans

This directory is the entire state model. No issue tracker, no Mission Control file — the contents of `active/` and `done/` are the ledger.

- `active/<slug>.md` — a plan with unfinished slices.
- `done/<slug>.md` — every slice is checked off. `/seal` moves it here.

Slugs are kebab-case derived from the plan title (`auth-flow`, `dark-mode`, `csv-export`).

## Plan-file shape

```markdown
---
name: auth-flow
created: 2026-05-19
status: active
---

# Auth flow

## Progress
`░░░░░░░░░░` 0/3
- [ ] 1. Add login form
- [ ] 2. Wire auth API
- [ ] 3. Session refresh

## Goal
What we're building and why. What "done" looks like.

## Constraints / out of scope
Anything deliberately not being done.

## Research
Optional — only when /ponder did research. The key facts that shaped the plan, with source links.

## Where your data is kept
Plain words: what the app saves and where, so it's never lost (e.g. "Accounts live in a JSON file on the server — they survive a restart"). For a tool that saves nothing, say so.

## How this app runs
Plain words + the start contract (e.g. "One Node process, `npm start`, serving UI + API on its port").

---

## Slice 1: Add login form
Detail and acceptance notes for this slice.

## Slice 2: Wire auth API
...

## Slice 3: Session refresh
...
```

## The progress block

Near the top of every plan, right under the title:

- A 10-cell bar — `█` for done, `░` for not. Filled cells = `round(done / total × 10)`.
- A checklist mirroring the slices. `- [ ]` not done, `- [x]` done.

`/forge` ticks boxes and re-renders the bar as it completes slices. `/temper` may un-tick a slice it sends back. `/seal` archives the plan when the bar reads `N/N`.

## Who writes what

- `/inscribe` — creates `active/<slug>.md` with all slices unchecked, bar at `0/N`.
- `/forge` — works through unchecked slices, ticks them, re-renders the bar.
- `/temper` — reviews; un-ticks and annotates any slice that needs rework.
- `/seal` — flips frontmatter `status: done`, moves the file to `done/`.

## This README is permanent

Don't delete it when populating the directory — it documents the contract.

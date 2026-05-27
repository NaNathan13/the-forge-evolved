# CONTEXT — glossary

Every term the workflow uses, pinned down once. When a word turns fuzzy mid-build, settle it here.

## Ponder

The thinking phase — first of the four. `/ponder` grills a fuzzy idea into shared understanding — scope, the shape of "done", how the work splits into slices — without writing any code or plan file. When the grilling hits a question it can't settle from the codebase or known facts, it leans on `/research`. It ends by handing off to `/inscribe`.

## Inscribe

The plan-writing step that ends the Ponder phase (a command, not a phase of its own). `/inscribe` records the understanding from `/ponder` as a single markdown file at `.claude/plans/active/<slug>.md`, sliced into parts, with a progress block near the top.

## Research

A sub-skill `/ponder` leans on (and usable on its own) when a question can't be settled from the codebase or known facts. Two depths: **light** — inline, in-session: read the code, maybe a web lookup; and **deep** — a parallel subagent fan-out across sources for genuinely novel unknowns, which confirms before launching. Research only gathers and reports; `/inscribe` records what mattered in the plan's `## Research` section.

## Forge

The build phase. `/forge` reads the active plan and works through every unchecked slice inline — implementing each, ticking its box, re-rendering the progress bar — then commits. No branches, no subagents; the work happens in this session on the current branch.

## Temper

The review-and-harden phase. `/temper` checks the built work against the plan: does each slice actually meet its intent, is it correct and clean. It fixes small issues inline and sends weak slices back by un-ticking them and annotating what's missing. Commits any fixes.

## Seal

The closer phase. `/seal` confirms every slice is done, flips the plan's frontmatter to `status: done`, moves the file from `.claude/plans/active/` to `.claude/plans/done/`, and makes a final commit.

## Plan

A single markdown file at `.claude/plans/active/<slug>.md` (in-flight) or `.claude/plans/done/<slug>.md` (finished). Holds frontmatter (`name`, `created`, `status`), a `## Progress` block (a 10-cell bar + a slice checklist), a `## Goal`, optional `## Constraints / out of scope` and `## Research` sections, and one `## Slice N:` section per slice.

## Slice

One coherent chunk of a plan — something you could describe in a sentence. Appears twice in the plan file: as a checklist item in the progress block (`- [ ]` / `- [x]`) and as a `## Slice N:` detail section. `/forge` builds slices and ticks them; `/temper` un-ticks any that need rework.

## Progress block

The bit near the top of every plan: a 10-cell bar (`█` done, `░` not — filled cells = `round(done / total × 10)`) plus the slice checklist. The single source of truth for what's done; kept current by `/forge` and `/temper`.

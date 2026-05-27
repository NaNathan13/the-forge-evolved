# CONTEXT — <placeholder: project-name>

> Glossary. Add a term when you find yourself disambiguating it in conversation.

<!--
  Skills read this reactively when a term is ambiguous. Keep entries to a
  paragraph. The workflow vocabulary is pre-seeded below — leave it alone unless
  you genuinely diverge. Add your project's own terms under ## Language.
-->

## Workflow terms

**Ponder**: The thinking phase — first of the four. Grill a fuzzy idea into shared understanding — scope, "done", how the work splits into slices — without writing code or a plan. Ends by handing off to Inscribe.

**Inscribe**: The plan-writing step that ends the Ponder phase (a command, not a phase of its own). Records the understanding as a single markdown file at `.claude/plans/active/<slug>.md`, sliced into parts, with a progress block near the top.

**Forge**: The build phase. Reads the active plan and works through every unchecked slice inline — implementing each, ticking its box, re-rendering the progress bar — then commits. No branches, no subagents.

**Temper**: The review-and-harden phase. Checks the built work against the plan, fixes small issues inline, and un-ticks any slice that needs real rework.

**Seal**: The closer phase. Confirms every slice is done, flips frontmatter to `status: done`, and moves the plan from `active/` to `done/`.

**Plan**: A single `.claude/plans/<active|done>/<slug>.md` file — frontmatter (`name`, `created`, `status`), a `## Progress` block, a `## Goal`, optional constraints and research, and one `## Slice N:` section per slice.

**Slice**: One coherent chunk of a plan. Appears as a checklist item in the progress block and as a `## Slice N:` detail section.

## Language

<!-- Add project-specific terms here as you find ambiguity. -->

(none yet — add as you find them)

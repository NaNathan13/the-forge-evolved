# The Forge Core

A four-phase workflow for Claude Code: **Ponder → Forge → Temper → Seal** — think it, build it, harden it, finish it. All planning and progress lives in markdown plan files under `.claude/plans/` — `active/` for in-flight work, `done/` for finished. No GitHub issues, no PRs, no orchestration. The build runs inline on your branch; read-only subagents may **gather** (research) or **judge** (cold review) and report back, but never write code or own a phase. One workflow, run inline.

This repo is both the working source of the workflow AND something you can drop into any project (via the install script).

## The loop

```
Ponder ─┬ /ponder    grill the idea into shared understanding (lean on /research at an unknown)
        └ /inscribe  write the sliced plan to .claude/plans/active/<slug>.md
Forge ─── /forge     build the whole plan inline, ticking off slices
Temper ── /temper    review + harden what was built; send weak slices back
Seal ──── /seal      confirm done, move the plan to .claude/plans/done/
```

Four phases. The Ponder phase runs two commands (`/ponder` then `/inscribe`); the rest are one each.

State = `ls .claude/plans/active/`. That's the whole ledger.

## Tech stack

- **Language / runtime:** Markdown + Bash (the workflow itself has no runtime).
- **Check command:** `bash -n` on changed shell scripts.
- **Git:** local version control only. Work happens in place on the current branch; phases commit at their natural end. No branches per slice, no pushing, no GitHub coupling.

## Key terms

See [`CONTEXT.md`](./CONTEXT.md). The essentials:

- **Plan** — one markdown file in `.claude/plans/active/<slug>.md`, sliced into parts, with a progress block near the top.
- **Slice** — one coherent chunk of a plan; a checklist item plus a `## Slice N:` detail section.
- **The four phases** — Ponder (think), Forge (build), Temper (review), Seal (finish). The Ponder phase ends with `/inscribe`, which writes the sliced plan.

## Rules

- **Work in place.** No branch-per-slice, no remote pushes. Commit at the end of each phase.
- **The plan file is the only state.** No issue tracker, no Mission Control, no labels.
- **Keep the progress block current.** `/forge` and `/temper` tick / un-tick slices and re-render the bar.
- **Stay in scope.** Build what the slices describe; don't add features or refactor beyond them.

## Context loading

| Layer | Source | When |
|---|---|---|
| Always | this file | session start |
| Glossary | `CONTEXT.md` | reactively when a term is unclear |
| Plans | `.claude/plans/active/*.md` | when a phase runs |
| Skill | `.claude/skills/<name>/SKILL.md` | when its `/command` is invoked |

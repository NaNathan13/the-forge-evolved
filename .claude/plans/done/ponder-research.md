---
name: ponder-research
created: 2026-05-23
status: done
---

# Add a research sub-phase to the Ponder session

## Progress
`██████████` 4/4
- [x] 1. Create the `/research` skill
- [x] 2. Fold research into `/ponder`
- [x] 3. Add the optional `## Research` section to `/inscribe`
- [x] 4. Doc touch-up (README / CLAUDE.md + installer comment)

## Goal
Refine **the Ponder session only** so it can go find things out, not just interrogate what's already known. Today `/ponder` grills the idea and leans on `grill-me`; when the grill hits a question the codebase and known facts can't answer, there's no defined move. This adds one: a reusable `/research` skill with a light/deep dial that `/ponder` folds in the same way it already folds in `grill-me`.

- **Light research** — inline, in-session: skim the codebase, maybe one web lookup. Fires on demand when the grill hits an unknown.
- **Deep research** — a parallel subagent fan-out across many sources, for genuinely novel unknowns. **Confirms before launching** (~N agents, a few minutes — go?).
- **Flow** — grill-first, research on demand. The grill drives; research is summoned, then feeds the next question.
- **Findings** — stay in-conversation during ponder; `/inscribe` distills the ones that matter into a new optional `## Research` section (key facts + source links). The plan file stays the only state.

**Done looks like:** a `research` skill exists and is standalone-usable; `/ponder` documents when/how it fires; `/inscribe`'s template carries an optional `## Research` section; docs nod to the new stage. Forge and Temper are untouched.

## Constraints / out of scope
- **Ponder only.** No changes to `/forge` or `/temper` behaviour.
- **No new phase in the loop.** `Ponder → Forge → Temper → Seal` stays four boxes. Research is a sub-skill ponder leans on, like `grill-me` — not a fifth box, not a new top-level `/command` in the diagram.
- **Stay slim.** One new skill file, two skill edits, a small doc tweak. No new state files, no installer logic change (the installer globs the skills dir).
- **No code runtime.** This is the workflow editing itself — markdown skills + a one-line bash comment.

## Where your data is kept
This workflow saves nothing of its own — it has no runtime and no datastore. The only state is the plan file in `.claude/plans/active/`, exactly as today; this change adds an optional `## Research` section to that same file and introduces no new files or storage.

## How this app runs
There's nothing to run. The deliverables are markdown skill files under `.claude/skills/` plus doc edits. The check is `bash -n` on any changed shell script (here, `light-the-core.sh`).

---

## Slice 1: Create the `/research` skill
New `.claude/skills/research/SKILL.md`, sized in the spirit of the others (grill-me is 26 lines, ponder 33 — keep it tight).

- Frontmatter `name: research` + a `description:` that triggers on "research this", "go find out", "look into", and notes it's leaned on by `/ponder`.
- Document the **light/deep dial**:
  - *Light* — inline, in-session: read the codebase first, then a targeted web lookup if needed. Fast, best-effort, you do it yourself. This is the default.
  - *Deep* — decompose the unknown into a few sub-questions and fan out **parallel subagents** across sources; gather, cross-check, synthesise. For genuinely novel unknowns only.
- **Confirm before deep.** Light just runs. Before a deep fan-out, pause and ask the operator (roughly: "this needs deep research — ~N parallel agents, a few minutes — go?"). No surprise fan-outs.
- **Transcript signal.** When research fires, emit one line — `researching: <question>` or `deep-researching: <question>` — mirroring grill-me's `noted:` pattern, so it's visible without interrupting the rhythm.
- **Read-only / context-cheap.** Research gathers and reports; it does not edit code or write plan files. Findings are returned to the caller (the ponder session), not written anywhere here.
- Standalone-usable: invocable as `/research` on its own, not only from ponder.

Acceptance: the skill reads as a single tight page; the light/deep distinction and the confirm-before-deep rule are unambiguous; it never edits files.

## Slice 2: Fold research into `/ponder`
Edit `.claude/skills/ponder/SKILL.md` so research is a documented move, parallel to how it already leans on `grill-me`.

- In the grilling step (currently step 3, "Grill it"), add that when a question can't be answered from the codebase or known facts, `/ponder` leans on the `research` skill — **grill-first, research on demand** — and feeds the result back into the next question.
- Make clear light research runs freely; deep research confirms first (per the `research` skill).
- Keep the existing "explore the codebase instead of asking" instinct intact — research is the escalation when that isn't enough.
- Add nothing to the Rules that contradicts "no plan file here / no code" — research in ponder produces understanding, not files.

Acceptance: `/ponder` names the `research` skill the same way it names `grill-me`; the grill-first/on-demand flow and confirm-before-deep are stated; ponder stays short.

## Slice 3: Add the optional `## Research` section to `/inscribe`
Edit `.claude/skills/inscribe/SKILL.md` so distilled findings have a home in the plan.

- Add `## Research` to the template shape (placed after `## Goal` / `## Constraints`, before `## Where your data is kept`), with guidance: **optional — include only when research actually fired**; holds the key facts that shaped the plan plus source links; distilled, not a transcript dump.
- Add a one-line rule: when `/ponder` did research, fold the conclusions that matter into this section so `/forge` and `/temper` reuse them rather than re-investigating; omit the section entirely otherwise.

Acceptance: the template carries an optional `## Research` section with clear "only when research fired" guidance; the rest of the template and rules are untouched.

## Slice 4: Doc touch-up (README / CLAUDE.md + installer comment)
Minimal, slim-spirited doc alignment — no rewrites.

- `CLAUDE.md` (this repo) — in the loop description / Ponder line, a one-line nod that `/ponder` can lean on `/research` (light or deep) when it hits an unknown. Don't expand the four-box diagram.
- `README.md` — if it describes the Ponder phase, the same one-line nod; otherwise leave it.
- `light-the-core.sh:14` — refresh the stale comment that enumerates skills by name ("…grill-me, diagnose, scrub, sharpen") to include `research`. No logic change; the copy step already globs the dir.
- Run `bash -n light-the-core.sh` after the comment edit.

Acceptance: docs mention research without bloating the loop; the installer comment lists `research`; `bash -n` passes on the script.

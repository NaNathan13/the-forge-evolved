# The Forge Core

Raw idea in, working code out. Four phases — **Ponder → Forge → Temper → Seal** — shape it, hammer it, harden it, stamp it. A handful of small skills, plans kept as plain markdown on disk, your own session swinging the hammer. No issues, no PRs, no orchestration. No ceremony.

It's also the brain behind [The Forge GUI](../the-forge-gui): the no-terminal app installs these skills into every project it builds.

## Get started

From your project folder, one command fetches and installs it:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-core/main/light-the-core.sh | bash
```

Then open the project in Claude Code and type `/ponder`. That's the whole start.

The installer drops the skills under `.claude/`, sets up `plans/{active,done}/`, and lays down starter `CLAUDE.md` / `CONTEXT.md` / `README.md` — only if you don't already have them, so it never clobbers your docs. **New here?** [**How to work in The Forge**](how-to-work-in-the-forge.md) walks you through your first build.

> Rather set up from inside Claude? Run the `/light-the-core` skill — same installer, and it asks three quick questions (project name, what it is, tech stack) to fill the starter docs for you.

## The five commands

Four phases, five commands, one at a time. Nothing auto-chains — you decide when the next blow lands.

| Command | Phase | What it does |
|---|---|---|
| `/ponder` | Ponder | Grills the idea into shape — questions, no code |
| `/inscribe` | Ponder | Writes the sliced plan to `.claude/plans/active/<slug>.md` |
| `/forge` | Forge | Builds the plan slice by slice, ticking each off |
| `/temper` | Temper | Reviews and hardens it; sends weak slices back to the fire |
| `/seal` | Seal | Confirms it's done and files the plan under `done/` |

Reach for these anytime: `/grill-me` (stress-test an idea), `/research` (go find out — light, or deep when it's worth it), `/diagnose` (a disciplined debugging loop), `/scrub` (tidy up plan state), `/sharpen` (turn a rough idea into a sharp prompt).

## Edit here when…

…you're changing how apps get **built** — the intake questions, how work gets planned and sliced, how data is stored, the rules generated apps follow. The no-terminal app's look — preview, gallery, chrome — lives in [The Forge GUI](../the-forge-gui).

State is just files. `ls .claude/plans/active/` is the whole ledger.

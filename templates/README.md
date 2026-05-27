# <placeholder: project-name>

One-line description of what this project is.

<!--
  Starter README dropped in by the installer. Rewrite it as your project grows.
  The workflow doesn't read this file at runtime — it's just for humans.
-->

## How this project is built

This repo is built with a four-phase Claude Code workflow — **Ponder → Forge → Temper → Seal**. Plans live as plain markdown under `.claude/plans/`; no GitHub ceremony.

To build or change something, open the project in Claude Code and type `/ponder`. The full loop is in [How to work in The Forge](https://github.com/NaNathan13/the-forge-core/blob/main/how-to-work-in-the-forge.md).

## Where things live

- [`CLAUDE.md`](./CLAUDE.md) — context loaded every session: tech stack, rules.
- [`CONTEXT.md`](./CONTEXT.md) — glossary.
- `.claude/plans/active/` — what's in flight · `.claude/plans/done/` — what's shipped.
- `.claude/skills/` — the workflow itself.

---
name: research
description: Go find out what the work needs to know — read the codebase, look things up, and for genuinely novel unknowns fan out parallel subagents across sources. Use when a question can't be answered from what's already known, or when the user says "research this", "go find out", "look into", "go deep on". Leaned on by /ponder.
---

Research answers a question the conversation can't answer on its own. It **gathers and reports** — it never edits code or writes plan files. Findings go back to whoever called it (usually the `/ponder` session), which decides what to do with them.

There's one dial: **light** (the default) or **deep**.

## Light — inline, on demand

Read the codebase first; how does our own code already handle this? If that's not enough, do a targeted web lookup. Fast, best-effort, you do it yourself in this session. This is what fires most of the time.

Emit one line when you start: `researching: <question>`.

## Deep — parallel fan-out, for genuinely novel unknowns

When the question is big and unfamiliar — prior art, an unfamiliar library, a fork you can't settle from one source — decompose it into a few sub-questions and fan out **parallel subagents** across sources, then cross-check and synthesise their reports.

**Confirm before launching.** Light just runs; deep does not. First pause and ask, roughly:

> This needs deep research — ~N parallel agents, a few minutes. Go?

Only fan out once the operator says yes. Then emit: `deep-researching: <question>`.

## Rules

- **Read-only.** Research gathers; it does not edit code or write anything under `.claude/plans/`.
- **Report, don't store.** Hand findings back to the caller — key facts and source links, distilled, not a transcript dump. `/inscribe` is what records the ones that matter.
- **Light by default.** Reach for deep only when the unknown genuinely warrants it, and never without confirming first.

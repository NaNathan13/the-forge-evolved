# {{PROJECT_NAME}}

{{PROJECT_ONE_LINER}}

<!-- Installed by The Forge. Keep this file SHORT — it loads every session. This is the always-loaded
     FRAME only: scope · "done" · conventions · verify commands · pointers. It is NEVER a decision
     log — decisions + glossary live in CONTEXT.md (load-on-demand). -->

## Layout (one repo)

Everything is in **this single git repo** — there is no split outer/app folder, and nothing is on
GitHub. `git` runs bare at the repo root (no `-C`).

- **Code** — your app, wherever its stack puts it.
- **`.claude/`** — the Forge kit (skills, agents, hooks, statusline, settings). Kit-owned; refreshed by
  `forge-update`. Don't hand-edit.
- **`.forge/`** — **all build state, and the source of truth**: `config`, `seed.md`, the task queue
  (`tasks/NNN-slug.md`), `research/`, `continue.md`, `needs-human.md`. Project-owned; `forge-update`
  never touches it.
- **`.knowledge/lessons.md`**, **`CONTEXT.md`** — promoted facts / decisions+glossary (load-on-demand).

## Verification commands (the forge loop's hard gates)

<!-- TODO: fill these once the app's stack exists (likely after the first scaffold task is forged).
     Leave a command blank if it's genuinely N/A to this project. -->

- **Tests:** `TODO`
- **Type-check:** `TODO`
- **Lint:** `TODO`

For `verify:test` tasks all of these must pass before review, and the builder must add tests proving the
criteria. For `verify:check` tasks (refactor/config/docs/chore) they must keep passing **unchanged** — no
new tests required. For `verify:visual` tasks a render/screenshot stands in.

## Commands (the pipeline)

- `/prospect` — pre-ponder warm-up: read the seed (or a fresh idea), propose + run prior-art research on
  approval, refine the vision, write findings to `.forge/research/`, then send you into `/ponder`.
- `/ponder` — grill a fuzzy idea into shared understanding; slice it **thinnest walking-skeleton thread
  first**, then broaden thread by thread. Pins decisions/terms to `CONTEXT.md`. Ends by proposing the
  task breakdown for one-word approval.
- `/inscribe` — on approval, write the breakdown as **task files** in `.forge/tasks/` (frontmatter:
  `status: ready`, `verify:`, `thread:`, `seq:`), threading the constraining decisions into the tasks
  they bind.
- `/forge` — self-heal state, propose the batch of `ready` tasks, and on approval drain it autonomously
  (build → hard-gate → adversarial review → squash-merge → post-merge test per task), **deploy + UAT-smoke
  each completed thread**, then stop and report.

Use them in order. Don't `/forge` without ready tasks — `/prospect → /ponder → /inscribe` fill the queue.

## Context discipline (CRITICAL)

- **Warn at 40% used, hard-stop at 50%.** The statusline shows the gauge; the `ctx-gate` PreToolUse hook
  *enforces* it (denies tool calls at ≥50%). At the 40 warn: refresh `.forge/continue.md` now.
- State of record is **external** — `.forge/` files + git. So resume is just `/clear` then re-run the
  command; it reads the task files + `run-state` and picks up where it left off.

## Architecture quirks

- **Thin orchestrator + fresh subagents.** `/forge` holds only the batch list + a 1-line status per task;
  each task gets a fresh builder and a fresh, independent reviewer. The reviewer is **read-only and a
  different, ≥-capable model** than the builder.
- **Sequential, one task at a time.** Clean branch (`forge/task-<id>`) → squash-merge into `main` locally
  → post-merge test gate. No parallelism, no PRs, no remote.
- **Use absolute paths in Bash.** The working directory resets between tool calls.
- **Skills load on demand**; role-based agents live in `.claude/agents/`. Keep this file lean.

## Building apps people will rely on

This is an app for a real person — usually not a programmer — who will use it to get something done.

**1. Never lose their data.** If the app keeps information the user expects to find later (clients, notes,
inventory, bookings, logs — anything they enter and would be upset to lose), it MUST be saved in durable,
server-side storage, never in the browser. `localStorage`/`sessionStorage`/IndexedDB are per-browser,
per-device, and easily wiped — treat them as throwaway only.
- **Default — a tiny built-in server + a data file.** One small Node program using only built-ins
  (`http`, `fs`), no framework, no `npm install`, that serves the page AND a small JSON API and saves
  records to a JSON file on disk (e.g. `data.json`). Durable, survives restarts, right for office-scale
  record-keeping.
- **SQLite** (Node's built-in `node:sqlite`) instead of a JSON file ONLY when data is large, relational,
  or needs real search/queries.
- **Throwaway / compute-only tools** (calculator, converter, timer) keep no records — a single static page
  is correct; do NOT add a server.

**2. One process, one port.** A server app runs as a single Node process started by `npm start`
(`start` = `node server.js`), listening on `process.env.PORT` (sensible fallback when unset), serving both
UI and API on that one port, logging its address once listening. No build step, no second dev server, no
framework unless the plan requires one.

**Sharing.** One person on one computer → the local file store is perfect. Several people in an office →
bind the server to `0.0.0.0` so others reach it at `http://<this-computer>:<port>`; data still lives in
one place.

## Response Style

- Be concise. No preamble, no filler, no narration of the obvious.
- In a line or two, say what you're about to do and what you just did.
- Keep every exact detail that matters (files, names, values, decisions); cut the prose around them.

---
See CONTEXT.md for decisions + glossary (load on demand). See `.knowledge/lessons.md` (skill-fed).

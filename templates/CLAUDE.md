# {{PROJECT_NAME}}

{{PROJECT_ONE_LINER}}

<!-- Installed by The Forge Evolved. Keep this file short — it loads every session. -->

## Project layout (the split)

You are in the **outer project folder** — the forge tooling lives here; Claude Code opens HERE. The actual
app code is a subfolder and is the only thing on GitHub:

- **App code:** `{{APP_DIR}}/`  (GitHub repo **{{REPO_SLUG}}**) — all `git` runs there: `git -C {{APP_DIR}} …`.
- **Forge tooling + run-state (this folder, not pushed):** `.claude/`, `.knowledge/`, `.claude/forge/` (config,
  loop-state). Coordinates live in `.claude/forge/config` (`APP_DIR`, `REPO_SLUG`, `BOARD_OWNER`, `PROJECT_NUMBER`).

## Verification commands (the forge loop's hard gates)

<!-- TODO: fill these once the app's stack exists (likely after the first scaffold issue is forged).
     They run inside {{APP_DIR}}/. Leave a command blank if it's genuinely N/A to this project. -->

- **Tests:** `TODO`
- **Type-check:** `TODO`
- **Lint:** `TODO`

For `verify:test` issues these must all pass before review; the builder must add tests proving the criteria.
They run in `{{APP_DIR}}/`. A command genuinely not applicable to this project may be left blank.

## Commands

- `/prospect` — the pre-ponder warm-up: read the seed (or a fresh idea), propose + run prior-art research on
  approval, refine the vision, write a findings file, then send you into `/ponder`. Reusable, not just at kickoff.
- `/ponder` — grill a fuzzy idea into shared understanding (research as needed); ends by proposing the
  issue breakdown for one-word approval.
- `/inscribe` — on approval, create GitHub issues (labels + machine-checkable acceptance criteria + board
  card) and thread ponder's recorded decisions into the issues they bind.
- `/forge` — propose the batch of `status:ready` issues, and on approval drain it autonomously
  (build → review → merge per issue), then stop and report.

Use them sequentially. Don't `/forge` without ready issues — `/prospect` → `/ponder` → `/inscribe` fill the queue first.

## Context discipline (CRITICAL)

- **Warn at 30%, hard-stop at 40%** of the context window. The statusline shows the gauge; the `ctx-gate`
  PreToolUse hook *enforces* it (denies tool calls at ≥40%). A real gate, not a label.
- At the hard stop: **write/refresh the handoff, then `/clear` and re-run the command.** Don't push past it.
- State lives in **GitHub issues/labels + git + `.claude/forge/loop-state`** — so resume is just `/clear`
  then re-run the command; it reads the board and picks up the next issue.

## Architecture quirks

- **Thin orchestrator + fresh subagents.** `/forge` holds only the batch list + a 1-line status per issue;
  each issue gets a fresh builder and a fresh, independent reviewer. The reviewer is **read-only and a
  different model** than the builder.
- **Use absolute paths in Bash.** The working directory resets between tool calls.
- **Code lives in `{{APP_DIR}}/`.** Run git there (`git -C {{APP_DIR}} …`) and target GitHub with
  `gh … --repo {{REPO_SLUG}}`. The forge skills read this from `.claude/forge/config`.
- **Skills load on demand**; role-based agents live in `.claude/agents/`. Keep this file lean.

## Building apps people will rely on

This is an app for a real person — usually not a programmer — who will use it to get something done.

**1. Never lose their data.** If the app keeps information the user expects to find later (clients, notes,
inventory, bookings, logs — anything they enter and would be upset to lose), it MUST be saved in durable,
server-side storage, never in the browser. `localStorage`/`sessionStorage`/IndexedDB are per-browser,
per-device, and easily wiped — treat them as throwaway only.
- **Default — a tiny built-in server + a data file.** One small Node program using only built-ins
  (`http`, `fs`), no framework, no `npm install`, that serves the page AND a small JSON API and saves records
  to a JSON file on disk (e.g. `data.json`). Durable, survives restarts, right for office-scale record-keeping.
- **SQLite** (Node's built-in `node:sqlite`) instead of a JSON file ONLY when data is large, relational, or
  needs real search/queries.
- **Throwaway / compute-only tools** (calculator, converter, timer) keep no records — a single static page is
  correct; do NOT add a server.

**2. One process, one port.** A server app runs as a single Node process started by `npm start`
(`start` = `node server.js`), listening on `process.env.PORT` (sensible fallback when unset), serving both UI
and API on that one port, logging its address once listening. No build step, no second dev server, no
framework unless the plan requires one.

**Sharing.** One person on one computer → the local file store is perfect. Several people in an office → bind
the server to `0.0.0.0` so others reach it at `http://<this-computer>:<port>`; data still lives in one place.

## Response Style

- Be concise. No preamble, no filler, no narration of the obvious.
- In a line or two, say what you're about to do and what you just did.
- Keep every exact detail that matters (files, names, values, decisions); cut the prose around them.

---
See CONTEXT.md for glossary (load on demand). See `.knowledge/lessons.md` (skill-fed).

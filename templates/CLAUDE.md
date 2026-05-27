# <placeholder: project-name>

<!--
  Starter CLAUDE.md for the four-phase workflow.
  State lives in .claude/plans/active/<slug>.md (markdown), not in GitHub.
  Replace placeholders below. Keep this file short — it loads every session.
-->

One-line description of what this project is.

## Tech stack

- **Language / runtime:** <placeholder: e.g. TypeScript / Node 20, Rust, Go 1.22>
- **Framework:** <placeholder: e.g. Next.js 14, Django, none>
- **Test runner:** <placeholder: e.g. vitest, pytest, cargo test>
- **Check command:** `<placeholder: e.g. npm run check-all, pnpm test>`

## How work flows here

Four phases, run inline and in order: **`/ponder`** (think it through) → **`/inscribe`** (write the sliced plan) → **`/forge`** (build it slice by slice) → **`/temper`** (review and harden) → **`/seal`** (confirm done). State lives in `.claude/plans/` — `active/` for in-flight, `done/` for finished. No GitHub issues, no PRs; the build runs inline, though read-only subagents may gather or review and report back. `ls .claude/plans/active/` is the whole ledger.

## Rules

- **Work in place.** No branch-per-slice, no remote pushes. Phases commit at their natural end on the current branch.
- **The plan file is the only state.** Keep the `## Progress` block current as slices get done.
- **Stay in scope.** Build what the slices describe; don't add features or refactor beyond them.
- <placeholder: any project-specific hard rules — code style, paid services, etc.>

## Building apps people will rely on

This is an app for a real person — usually not a programmer — who will use it to get something done. Two rules outweigh everything else:

**1. Never lose their data.** If the app keeps information the user will expect to find later — clients, notes, inventory, bookings, logs, anything they enter and would be upset to lose — that information MUST be saved in durable, server-side storage, never in the browser. Browser storage (`localStorage`, `sessionStorage`, IndexedDB) is per-browser, per-device, and easily wiped; treat it as throwaway only.
- **Default — a tiny built-in server + a data file.** Build one small Node program using only built-ins (`http`, `fs`) — no framework, and avoid `npm install` — that serves the page AND a small JSON API, and saves records to a JSON file on disk in the project (e.g. `data.json`). Durable, survives restarts, no database, right for typical office-scale record-keeping.
- **SQLite** (Node's built-in `node:sqlite`, still no native dependency) instead of a JSON file ONLY when the data is large, relational, or needs real search/queries.
- **Throwaway / compute-only tools** (calculator, converter, timer, one-off generator) keep no records — a single static page is correct; do NOT add a server.

**2. One process, one port.** An app that needs a server runs as a single Node process started by `npm start` (i.e. a `start` script = `node server.js`), listening on `process.env.PORT` (with a sensible fallback when unset), serving both the UI and its API on that one port, and logging its address (e.g. `http://localhost:<port>`) once it's listening. No build step, no second dev server, no framework unless the plan explicitly requires one — this keeps it reliable to launch and to preview.

**Sharing.** Just one person on one computer → the local file store above is perfect. Shared by several people in an office → bind the server to `0.0.0.0` on its port so others on the same network reach it at `http://<this-computer>:<port>`; the data still lives in one place on the host. No accounts, no cloud.

## Docs

- [`CONTEXT.md`](./CONTEXT.md) — glossary. Read reactively when a term is unclear.
- [`.claude/plans/active/`](./.claude/plans/active/) — in-flight plans.
- [`.claude/plans/done/`](./.claude/plans/done/) — finished plans.

---
name: forge-update
description: Pull the latest Forge kit into an ALREADY-installed project — runs update-forge.sh to refresh the kit-owned files (skills, agents, hooks, statusline) from GitHub while leaving every project-owned file (.forge/ state, settings.json, CLAUDE.md, CONTEXT.md, lessons.md) untouched. Use when the user says "update the forge", "pull the latest kit", "upgrade the forge", or "/forge-update".
---

# Forge Update

Conversational wrapper around `update-forge.sh`. The script does the file work — fetches the kit from GitHub
(`@ main`, or a pinned `--ref`) and refreshes the **kit-owned** files in place, never touching **project-owned**
state. This skill confirms intent, runs a **dry-run first**, shows the plan, then applies on approval.

Do **not** re-implement the sync logic here — that's the script's job. Run it, stream its output, help when it halts.

## Installer vs updater (don't confuse them)

- **`light-the-forge.sh`** (`/light-the-forge`) — scaffolds a **brand-new** project. Refuses to clobber an
  existing one.
- **`update-forge.sh`** (this skill) — upgrades an **already-installed** project to the latest kit. Refuses
  to run anywhere there's no `.forge/config`.

If the user wants to start fresh, this is the wrong skill — send them to `/light-the-forge`.

## What it touches (and what it never touches)

Run from the project **root** (the single repo, the one with `.forge/config`):

| Refreshed (the kit itself) | Never touched (your state) |
|---|---|
| `.claude/skills/` | `.forge/` (config, tasks, research, continue.md, needs-human.md, run-state) |
| `.claude/agents/` | `.claude/settings.json` (merged at install, yours now) |
| `.claude/hooks/` | `CLAUDE.md`, `CONTEXT.md` (project-specific) |
| `.claude/statusline.sh` | `.knowledge/lessons.md` (accumulated knowledge) |

The kit-owned-vs-project-owned split is now a clean directory boundary: the updater overwrites inside
`.claude/` (minus `settings.json`) and **never** touches `.forge/`, `CLAUDE.md`, or `CONTEXT.md`.

- It **never deletes** local files. A skill you added yourself survives; files removed upstream are *reported*,
  not removed.
- There is **no GitHub workflow** to refresh — GitHub is gone from the loop entirely.

## Preconditions

- Run from an **installed** project's root — the script aborts if `.forge/config` is absent.
- `git` on PATH. `rsync` gives a precise per-file plan; without it the script falls back to `cp` with a coarser report.
- Ideally **no forge run mid-flight.** If a batch is in progress, finish it (or `/clear` and re-run `/forge`)
  before swapping the skills out from under it.

## Workflow

### 1. Confirm intent + dry-run

Confirm you're in the right folder (it must contain `.forge/config`), then **always dry-run first** — it
changes nothing and prints exactly what would update:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/update-forge.sh | bash -s -- --dry-run
```

Pin a version with `--ref <branch|tag|sha>` if the user asked for one. Show the user the plan (new `+` /
changed `~` files, any local-only files being kept). If nothing would change, say "already up to date" and stop.

### 2. Apply on approval

Once the user okays the plan, run it for real:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/update-forge.sh | bash
```

Or, from a local checkout of the-forge: `/path/to/update-forge.sh [--dry-run] [--ref <ref>]`.

### 3. Report

Echo what changed (the script's summary count) and confirm project-owned files were left alone. The script
ends with a **wiring check** — if it flagged gaps (a missing `ctx-gate`/`_probe` hook in `settings.json`,
missing `.forge/config` keys), relay them: the updater deliberately won't touch project-owned files, so those
need a manual fix against a fresh scaffold. If the kit changed how `/forge` or its agents behave, mention that
the new behavior takes effect on the **next** command run — and that any **in-flight** batch should be
finished (or `/clear`ed and re-run) first.

## Bootstrapping a project that predates the updater

A project scaffolded before this skill existed won't have `/forge-update` or `update-forge.sh` locally — and
that's fine. The curl one-liner in step 1 fetches the script from GitHub and only needs `.forge/config` to
exist. Running it once **installs the `/forge-update` skill itself** (it's a kit-owned skill under
`.claude/skills/`), so the project gains the `/command` for next time. In an old project the user can't type
`/forge-update` yet, so just run the curl one-liner directly (or the user runs it with `! curl …`).

## Anti-patterns

- **Don't skip the dry-run.** Always preview before applying — it's free and it's the user's confirmation gate.
- **Don't inline the sync logic.** This skill runs `update-forge.sh`; it never duplicates it.
- **Don't hand-edit project-owned files to "merge" upstream changes.** The script's whole job is to leave them
  alone. If `CLAUDE.md`/`CONTEXT.md` need new content, that's a separate, explicit edit — not part of an update.
- **Don't use this to scaffold.** No `.forge/config` means it's not an installed project — use `/light-the-forge`.

---
name: forge-update
description: Pull the latest Forge Evolved kit into an ALREADY-installed project — runs update-forge.sh to refresh the kit-owned files (skills, agents, hooks, statusline, github-setup doc) from GitHub while leaving every project-owned file (config, loop-state, CLAUDE.md, CONTEXT.md, settings.json, lessons.md) untouched. Use when the user says "update the forge", "pull the latest kit", "upgrade the forge", or "/forge-update".
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
  to run anywhere there's no `.claude/forge/config`.

If the user wants to start fresh, this is the wrong skill — send them to `/light-the-forge`.

## What it touches (and what it never touches)

Run from the project's **outer folder** (the one with `.claude/forge/config`):

| Refreshed (the workflow itself) | Never touched (your state) |
|---|---|
| `.claude/skills/` | `.claude/forge/{config,loop-state,seed.md}` |
| `.claude/agents/` | `.claude/settings.json` (merged at install, yours now) |
| `.claude/hooks/` | `CLAUDE.md`, `CONTEXT.md` (project-specific) |
| `.claude/statusline.sh` | `.knowledge/lessons.md` (accumulated knowledge) |
| `docs/github-setup.md` | |

- It **never deletes** local files. A skill you added yourself survives; files removed upstream are *reported*,
  not removed.
- The app repo's `.github/workflows/sync-board.yml` is kit-owned but **version-controlled**, so it's
  **opt-in** (`--with-workflow`) and the user commits it themselves in the app repo.

## Preconditions

- Run from an **installed** project's outer folder — the script aborts if `.claude/forge/config` is absent.
- `git` on PATH. `rsync` gives a precise per-file plan; without it the script falls back to `cp` with a coarser report.
- Ideally **no forge run mid-flight.** If a batch is in progress, finish it (or `/scrub`) before swapping the
  skills out from under it.

## Workflow

### 1. Confirm intent + dry-run

Confirm you're in the right folder (it must contain `.claude/forge/config`), then **always dry-run first** —
it changes nothing and prints exactly what would update:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/update-forge.sh | bash -s -- --dry-run
```

Pin a version with `--ref <branch|tag|sha>` if the user asked for one. Show the user the plan (new `+` /
changed `~` files, any local-only files being kept, and whether `sync-board.yml` drifted). If nothing would
change, say "already up to date" and stop.

### 2. Apply on approval

Once the user okays the plan, run it for real:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/update-forge.sh | bash
```

Add `--with-workflow` only if the dry-run flagged `sync-board.yml` drift **and** the user wants it refreshed —
then remind them it's version-controlled and must be committed in the app repo (the script prints the exact
`git -C <app> …` command).

Or, from a local checkout of the-forge-evolved: `/path/to/update-forge.sh [--dry-run] [--ref <ref>] [--with-workflow]`.

### 3. Report

Echo what changed (the script's summary count) and confirm project-owned files were left alone. The script
ends with a **wiring check** — if it flagged gaps (a missing `ctx-gate` hook in `settings.json`, missing
`.claude/forge/config` keys), relay them: the updater deliberately won't touch project-owned files, so those
need a manual fix against a fresh scaffold or `docs/github-setup.md`. If the kit changed how `/forge` or its
agents behave, mention that the new behavior takes effect on the **next** command run — and that any
**in-flight** batch should be finished or `/scrub`bed first.

## Bootstrapping a project that predates the updater

A project scaffolded before this skill existed won't have `/forge-update` or `update-forge.sh` locally — and
that's fine. The curl one-liner in step 1 fetches the script from GitHub and only needs `.claude/forge/config`
to exist. Running it once **installs the `/forge-update` skill itself** (it's a kit-owned skill under
`.claude/skills/`), so the project gains the `/command` for next time. In an old project the user can't type
`/forge-update` yet, so just run the curl one-liner directly (or the user runs it with `! curl …`).

## Anti-patterns

- **Don't skip the dry-run.** Always preview before applying — it's free and it's the user's confirmation gate.
- **Don't inline the sync logic.** This skill runs `update-forge.sh`; it never duplicates it.
- **Don't hand-edit project-owned files to "merge" upstream changes.** The script's whole job is to leave them
  alone. If `CLAUDE.md`/`CONTEXT.md` need new content, that's a separate, explicit edit — not part of an update.
- **Don't run `--with-workflow` silently.** Refreshing `sync-board.yml` writes into the app repo's version
  control; surface it and let the user commit it.
- **Don't use this to scaffold.** No `.claude/forge/config` means it's not an installed project — use
  `/light-the-forge`.

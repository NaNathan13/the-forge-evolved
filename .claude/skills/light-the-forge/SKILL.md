---
name: light-the-forge
description: Scaffold a brand-new Forge project — runs light-the-forge.sh to stand up ONE git repo (code + .claude/ kit + .forge/ state) in the current folder, no GitHub. Use when the user says "light the forge", "start a new forge project", "set up the forge here", or "/light-the-forge".
---

# Light the Forge

Conversational wrapper around `light-the-forge.sh`. The script does the file work — copies the kit, fills
CLAUDE.md / CONTEXT.md, scaffolds the `.forge/` state tree, writes `config` + `seed.md`, registers
`settings.json`, and `git init`s the single repo. This skill confirms intent, runs the script, and reports.

Do **not** re-implement the scaffold logic here — that's the script's job. Run it, stream its output, and
help when it halts.

## What it does (one repo, no GitHub)

The installer is built for a **fresh start**, not grafting onto an existing repo. Run from inside an empty
project folder, it `git init`s **one repo** holding everything:

```
<project>/                ← you run it here; git init HERE; Claude Code opens HERE
├── .claude/              skills, agents, hooks, statusline.sh, settings.json   (kit-owned)
├── .forge/               config, seed.md, tasks/, research/, continue.md, needs-human.md   (state)
├── .knowledge/lessons.md
├── CLAUDE.md  CONTEXT.md  .gitignore  README.md
```

There is **no split outer/app folder and nothing on GitHub** — local `.forge/` files are the source of truth.
No repo, board, labels, repo variables, or PAT to set up. The PM hub is an optional projection configured
later in `.forge/config` (`PM_HUB_DIR` / `PM_SLUG`), not a precondition.

## Preconditions

- An **empty (or new) project folder** to run from (default `$(pwd)`). The script aborts rather than clobber
  if it already has a `.forge/`.
- `git` and `jq` on PATH.
- The script won't overwrite an existing `CLAUDE.md`/`CONTEXT.md`/`.gitignore`/`README.md` and merges (not
  clobbers) an existing `.claude/settings.json`.

## Workflow

### 1. Confirm intent

Ask once (skip if it's obvious from the user's message):

> Scaffold a new Forge project in `<current-dir>`? It'll ask for a name, description, and deploy type
> (public/internal), then `git init` one repo with the kit + `.forge/` state. Yes / different folder / cancel.

On cancel, stop.

### 2. Run the installer

The one-liner self-fetches the kit (preferred — run it from inside the project folder):

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/light-the-forge.sh | bash
```

Or from a local checkout of the-forge:

```bash
/path/to/light-the-forge.sh <project-dir>
```

The script prompts (on `/dev/tty`) for: **project name**, **one-line description**, **deploy type**
(`public | internal`), and **whether to kick off initial research** — then a **confirm** step. After that it
installs the kit, scaffolds `.forge/`, writes `config` + `seed.md`, registers `settings.json`, and
`git init`s the repo on `main` with an initial commit. Stream its output; don't re-summarize the file list.

### 3. Report the outcome

On exit 0, echo the essentials: the one repo it created, the deploy type recorded in `.forge/config`, and the
two next steps — **fill `STACK_DIR`/`CONTAINER_PORT` in `.forge/config` once the app's stack exists**, and
**run `/prospect`** (it reads the seed the installer left, researches the idea on approval, then sends them
into `/ponder`). Mention the **hook-probe gate**: the real continuity hooks stay un-wired until Nate runs the
SessionStart/PreCompact/Stop probe (the installer leaves `_probe.sh` logging to `.forge/hook-probe.log`).

On non-zero exit (a folder that's already forged, missing `git`/`jq`), surface the script's stderr verbatim
and stop — do not paper over a partial scaffold.

## Anti-patterns

- **Don't inline the scaffold logic.** This skill runs `light-the-forge.sh`; it never duplicates it.
- **Don't try to set anything up on GitHub.** There is no GitHub side anymore — local files are the truth.
- **Don't try to reuse an already-forged folder.** The script aborts on an existing `.forge/` by design —
  relay that, don't work around it.
- **Don't overwrite the user's `CLAUDE.md` / `CONTEXT.md`.** The script already skips existing docs.

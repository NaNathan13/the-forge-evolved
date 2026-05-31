---
name: light-the-forge
description: Scaffold a brand-new Forge Evolved project — runs light-the-forge.sh to install the kit into the outer project folder and create the <name>-app/ local git repo, then point the user at docs/github-setup.md for the GitHub side they own. Use when the user says "light the forge", "start a new forge project", "set up the forge here", or "/light-the-forge".
---

# Light the Forge

Conversational wrapper around `light-the-forge.sh`. The script does the local file work — copies the kit,
fills CLAUDE.md / CONTEXT.md, scaffolds the `<name>-app/` git repo, writes `config` + `seed.md`, and merges
`settings.json`. This skill confirms intent, runs the script, then hands the user the GitHub-setup checklist
(`docs/github-setup.md`) they run themselves.

Do **not** re-implement the scaffold logic here — that's the script's job. Run it, stream its output, and
help when it halts.

## What it does (the split layout)

The installer is built for a **fresh start**, not grafting onto an existing repo. Run from inside an empty
project folder, it creates:

```
<project-folder>/          ← you run it here; Claude Code opens HERE (forge tooling)
└── <name>-app/            ← a fresh local git repo (the code you'll build)
```

The outer folder holds the forge skills + run-state; the `<name>-app/` subfolder is the code you push to
GitHub when you set up the repo.

## What's the user's, not the installer's

The script touches **code only**. The GitHub side is the user's to set up by hand (or to ask Claude to do
with credentials present): the repo, the Projects v2 board, the labels, the repo variables, and the
`FORGE_PROJECT_PAT` secret. The full checklist of `gh` commands lives in `docs/github-setup.md`, which the
installer drops into the project folder. Point the user there — don't run those commands as part of
lighting the forge.

## Preconditions

- An **empty (or new) project folder** to run from (default `$(pwd)`). The script aborts rather than
  clobber if it already contains `<name>-app/`.
- `git` and `jq` on PATH.
- The script won't overwrite an existing `CLAUDE.md`/`CONTEXT.md` and merges (not clobbers) `.claude/settings.json`.

## Workflow

### 1. Confirm intent

Ask once (skip if it's obvious from the user's message):

> Scaffold a new Forge project in `<current-dir>`? It'll ask for a name, owner, and description, then
> install the kit and a local `<name>-app/` git repo. Yes / different folder / cancel.

On cancel, stop.

### 2. Run the installer

The one-liner self-fetches the kit (preferred — run it from inside the project folder):

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/light-the-forge.sh | bash
```

Or from a local checkout of the-forge-evolved:

```bash
/path/to/light-the-forge.sh <project-dir>
```

The script prompts (on `/dev/tty`) for: **project name**, **GitHub owner** (optional — only fills the config
coordinates), **one-line description**, and **whether to kick off initial research** — then a **confirm**
step. After that it runs: install kit into the outer folder → scaffold `<name>-app/` + `git init` + initial
commit → `config` + `seed.md` → settings.json. Stream its output; don't re-summarize the file list it prints.

### 3. Hand off the GitHub setup

When the script finishes, point the user at **`docs/github-setup.md`** (now in their project folder). That's
the one-time checklist they own: authenticate with the `project` scope, create + push the repo, build the
Projects v2 board and the six-column **Forge Status** field, create the label set, set the repo variables
(`FORGE_PROJECT_ID`, `FORGE_STATUS_FIELD_ID`, the `FORGE_OPT_*`), set the `FORGE_PROJECT_PAT` classic-PAT
secret, and fill `PROJECT_NUMBER` in `.claude/forge/config`.

If the user **asks you to run those steps** and has `gh` authenticated, you may — follow `docs/github-setup.md`
verbatim. Otherwise leave GitHub to them.

### 4. Report the outcome

On exit 0, echo the essentials: where the kit installed, the local `<name>-app/` repo, and the next two
steps — **set up GitHub via `docs/github-setup.md`**, then **open the project folder in Claude Code and run
`/ponder`** (it reads the seed the installer left).

On non-zero exit (collision with an existing folder, missing `git`/`jq`), surface the script's stderr
verbatim and stop — do not paper over a partial scaffold.

## Anti-patterns

- **Don't inline the scaffold logic.** This skill runs `light-the-forge.sh`; it never duplicates it.
- **Don't create anything on GitHub as part of lighting the forge.** The repo, board, labels, variables, and
  secret are the user's — they follow `docs/github-setup.md`. Only run those steps if explicitly asked.
- **Don't try to reuse an existing folder.** The script aborts on collision by design — relay that, don't
  work around it.
- **Don't overwrite the user's `CLAUDE.md` / `CONTEXT.md`.** The script already skips existing docs.
- **Don't suggest a fine-grained PAT** for `FORGE_PROJECT_PAT` — it cannot drive Projects v2. Classic PAT only.

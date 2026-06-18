# The Forge

A per-project, **GitHub-free** Claude Code workflow: plan a fuzzy idea into local task files, then turn
Claude loose to autonomously drain an approved batch — build, review, squash-merge, and deploy each thread —
with a hard context ceiling and no path for bad code to reach `main`. Local `.forge/` files are the source of
truth; everything lives in **one git repo**.

Four commands, in order: **`/prospect`** (research + warm up the idea) → **`/ponder`** (grill it, propose a
thread-ordered task breakdown) → **`/inscribe`** (write the task files) → **`/forge`** (approve the batch,
then build→review→squash-merge→post-merge-test each task, deploy + UAT-smoke each thread, then stop and report).

## Quick start

**1. Make an empty folder for your project and `cd` into it** (e.g. `mkdir my-project && cd my-project`),
**then run the installer** (it asks a handful of questions — project name, description, deploy type, whether
to kick off research — then scaffolds in place and `git init`s one repo):

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/light-the-forge.sh | bash
```

**2. Open that folder in Claude Code** — it's the one repo; everything is here.

**3. Run `/prospect`.** It reads what setup captured, researches the idea on your approval, then sends you
into `/ponder`. You're off.

> Run the one-liner from *inside* your own project folder — don't clone this repo to use it (the one-liner
> fetches what it needs on its own).

## Requirements

- **Claude Code** — the whole workflow runs inside it.
- **`git`** and **`jq`** — required by the installer (it checks and stops if either is missing).
- **`docker compose`** + **`curl`** — only for the per-thread deploy step (`/forge` deploys each completed
  thread to your stack and health-checks it). Optional until you wire `STACK_DIR`/`CONTAINER_PORT`.

No GitHub account, no board, no PAT, no external services. The optional **PM hub** projection
(projects.greenfyre.dev) is configured later in `.forge/config` — absent it, the local files are the whole story.

## One repo

The installer scaffolds a **single git repo** holding everything:

```
my-project/               ← git init HERE; open THIS in Claude Code
├── .claude/              skills, agents, hooks, statusline.sh, settings.json   (kit-owned)
├── .forge/               config, seed.md, tasks/, research/, continue.md, needs-human.md   (state, source of truth)
├── .knowledge/lessons.md
├── CLAUDE.md  CONTEXT.md  .gitignore  README.md
```

`.forge/` is the source of truth — the task queue, per-task status, escalations, and continuity journal all
live there as plain files. The kit (`.claude/`) is refreshed by the updater; your state (`.forge/`,
`CLAUDE.md`, `CONTEXT.md`) is never touched by it.

## Learn more

- **[docs/how-the-forge-works.md](docs/how-the-forge-works.md)** — the full narrative: the forge loop, the
  task files, per-thread deploy, context discipline, escalation, and knowledge.

## Already have a repo?

The installer is built for the fresh-scaffold flow above, but the kit is just files. To graft the forge onto
an existing repo, drop the `.claude/` kit in at the repo root and run the installer from there — it adds
`.forge/`, the templates, and `settings.json` without touching your code (it skips an existing `CLAUDE.md`/
`CONTEXT.md` and won't clobber an already-forged `.forge/`).

## Updating an installed project

When the kit improves, pull the changes into a project you scaffolded earlier — run this from the project
**root** (the one with `.forge/config`), or just ask Claude to `/forge-update`.

Preview what would change (nothing is written):

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/update-forge.sh | bash -s -- --dry-run
```

Apply:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/update-forge.sh | bash
```

It refreshes the **kit-owned** files (`.claude/skills`, `.claude/agents`, `.claude/hooks`, `statusline.sh`)
and leaves every **project-owned** file untouched (`.forge/` state, `settings.json`, `CLAUDE.md`, `CONTEXT.md`,
`.knowledge/lessons.md`) — a clean directory boundary. It never deletes local files, so a skill you added
yourself survives. `--ref <branch|tag|sha>` pins a version. Let any in-flight batch finish (or `/clear` and
re-run `/forge`) first.

**First time (project predates the updater)?** You don't need the skill or script pre-installed — the curl
one-liner fetches `update-forge.sh` from GitHub and only needs `.forge/config` to exist. Running it once also
installs the `/forge-update` skill itself, so future updates are just "update the forge" in Claude. For a
genuinely old project, the run ends with a **wiring check** that flags any project-owned gaps (a missing
`ctx-gate`/continuity hook, missing `.forge/config` keys) it deliberately won't auto-fix — reconcile those
against a fresh scaffold.

## License

MIT — see [LICENSE](LICENSE).

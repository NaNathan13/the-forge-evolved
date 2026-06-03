# The Forge Evolved

A per-project, GitHub-native Claude Code workflow: plan a fuzzy idea into GitHub issues, then turn Claude
loose to autonomously drain an approved batch — build, review, and merge each issue — with a hard context
ceiling and no path for bad code to reach `main`.

Four commands, in order: **`/prospect`** (research + warm up the idea) → **`/ponder`** (grill it, propose an
issue breakdown) → **`/inscribe`** (create the labeled issues + board cards) → **`/forge`** (approve the
batch, then build→review→merge each issue, then stop and report).

## Quick start

**1. Make an empty folder for your project and `cd` into it** (e.g. `mkdir my-project && cd my-project`),
**then run the installer** (it asks a handful of questions — project name, GitHub owner, one-line
description, whether to kick off research — then scaffolds in place):

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/light-the-forge.sh | bash
```

**2. Open that folder in Claude Code** (open `my-project/` — the outer folder, where the forge tooling lives).

**3. Run `/prospect`.** It reads what setup captured, researches the idea on your approval, then sends you
into `/ponder`. You're off.

> Run the one-liner from *inside* your own project folder — don't clone this repo to use it (you'd end up
> working in the wrong git checkout).

## Requirements

- **Claude Code** — the whole workflow runs inside it.
- **`git`** and **`jq`** — required by the installer (it checks and stops if either is missing).
- **`gh` (GitHub CLI), authenticated** — the `/inscribe` and `/forge` phases create and move issues with it.
- **A GitHub account** that can create a repo + a Projects v2 board, and a classic **PAT** (`project` scope)
  for the board-sync workflow. Only needed once you reach `/inscribe` — `/prospect` and `/ponder` need none
  of it, so you can start thinking right away.

## The two folders

The installer scaffolds two nested folders:

```
my-project/                 ← the cockpit: forge tooling, never pushed to GitHub. Open THIS in Claude Code.
└── <name>-app/             ← your actual project: a local git repo that becomes the GitHub repo.
```

The outer folder holds the skills, config, and run-state. The inner `<name>-app/` is the only thing that goes
to GitHub — your code *and* the issues both live there. So if you type **`Recipe Box`**, you get the forge kit
plus a local `recipe-box-app/` git repo with an initial commit.

`/prospect` and `/ponder` need nothing but Claude Code — start thinking immediately. Before `/inscribe` files
issues, set up the GitHub side (the repo, Projects v2 board, labels, variables, and PAT secret are yours to
own): follow **[docs/github-setup.md](docs/github-setup.md)**.

## Learn more

- **[docs/how-the-forge-evolved-works.md](docs/how-the-forge-evolved-works.md)** — the full narrative: the
  forge loop, the board, context discipline, escalation, and knowledge.
- **[docs/github-setup.md](docs/github-setup.md)** — the exact `gh` commands for the GitHub side.

## Already have a repo?

The installer is built for the fresh-scaffold flow above. To graft the forge onto an existing project, mirror
that layout by hand: put the forge `.claude/` tooling in an outer folder, keep your code in a `<name>-app/`
subfolder, and write `.claude/forge/config` with `APP_DIR`, `REPO_SLUG`, `BOARD_OWNER`, and `PROJECT_NUMBER`.
Provision the board, labels, variables, and secret per [docs/github-setup.md](docs/github-setup.md).

## Updating an installed project

When the kit improves, pull the changes into a project you scaffolded earlier — run this from the project's
**outer folder** (the one with `.claude/forge/config`), or just ask Claude to `/forge-update`.

Preview what would change (nothing is written):

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/update-forge.sh | bash -s -- --dry-run
```

Apply:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/update-forge.sh | bash
```

It refreshes the **kit-owned** files (`.claude/skills`, `.claude/agents`, `.claude/hooks`, `statusline.sh`,
`docs/github-setup.md`) and leaves every **project-owned** file untouched (`.claude/forge/*`, `settings.json`,
`CLAUDE.md`, `CONTEXT.md`, `.knowledge/lessons.md`). It never deletes local files, so a skill you added
yourself survives. `--ref <branch|tag|sha>` pins a version; `--with-workflow` also refreshes the app repo's
`sync-board.yml` (version-controlled — you commit it). Finish or `/scrub` any in-flight batch first.

**First time (project predates the updater)?** You don't need the skill or script pre-installed — the curl
one-liner fetches `update-forge.sh` from GitHub and only needs `.claude/forge/config` to exist. Running it
once also installs the `/forge-update` skill itself (it's a kit-owned skill), so future updates are just
"update the forge" in Claude. For a genuinely old project, the run ends with a **wiring check** that flags any
project-owned gaps (a missing `ctx-gate` hook, missing `config` keys) it deliberately won't auto-fix —
reconcile those against a fresh scaffold or `docs/github-setup.md`.

## License

MIT — see [LICENSE](LICENSE).

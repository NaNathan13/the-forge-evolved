# The Forge Evolved

A per-project, GitHub-native Claude Code workflow: plan a fuzzy idea into GitHub issues, then turn
Claude loose to autonomously drain an approved batch — build, review, and merge each issue — with a
hard context ceiling and no path for bad code to reach `main`.

Three commands, in order: **`/ponder`** (grill the idea, propose an issue breakdown) → **`/inscribe`**
(create the labeled issues + board cards) → **`/forge`** (approve the batch, then build→review→merge
each issue, then stop and report).

## Quick start

Make a new project folder, `cd` into it, and run the one-liner:

```bash
mkdir my-project && cd my-project
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/light-the-forge.sh | bash
```

It asks a handful of questions — **project name**, GitHub **owner**, **public/private**, a **one-line
description**, and whether to **kick off initial research** — shows a confirm step, then scaffolds everything:

```
my-project/                 ← you run the one-liner here; open THIS folder in Claude Code
├── .claude/                forge skills, agents, hooks, statusline, run-state
├── .knowledge/             lessons.md
├── CLAUDE.md, CONTEXT.md
└── <name>-app/             ← a fresh git repo, created on GitHub + pushed
    └── .github/workflows/sync-board.yml
```

So if you type **`Recipe Box`**, you get the GitHub repo `recipe-box`, the code folder `recipe-box-app/`,
a Projects board with the six Forge columns, the label set, and the sync workflow — all wired up.

**Requirements:** [`gh`](https://cli.github.com) (logged in, with the `project` scope —
`gh auth refresh -s project`), `git`, and `jq`. The board sync workflow needs a **classic** PAT with the
`project` scope; the installer prompts for it (or set it later with
`gh secret set FORGE_PROJECT_PAT --repo <owner>/<name>`).

When it finishes: **open the project folder in Claude Code and run `/ponder`.** It picks up the description
(and any research request) from the seed the installer left, and the loop begins.

See **[docs/how-the-forge-evolved-works.md](docs/how-the-forge-evolved-works.md)** for the full
narrative — the forge loop, the board, context discipline, escalation, and knowledge.

## Already have a repo?

The installer is built for the fresh-scaffold flow above (it creates the app repo for you). If you want to
graft the forge onto an existing project, mirror that layout by hand: put the forge `.claude/` tooling in an
outer folder, keep your code in a `<name>-app/` subfolder, and write `.claude/forge/config` with `APP_DIR`,
`REPO_SLUG`, `BOARD_OWNER`, and `PROJECT_NUMBER`.

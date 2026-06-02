# The Forge Evolved

A per-project, GitHub-native Claude Code workflow: plan a fuzzy idea into GitHub issues, then turn
Claude loose to autonomously drain an approved batch — build, review, and merge each issue — with a
hard context ceiling and no path for bad code to reach `main`.

Three commands, in order: **`/ponder`** (grill the idea, propose an issue breakdown) → **`/inscribe`**
(create the labeled issues + board cards) → **`/forge`** (approve the batch, then build→review→merge
each issue, then stop and report).

## Quick start

> **Don't clone this repo to use it.** The one-liner below fetches everything it needs on its own.
> Cloning the-forge-evolved and running `/ponder` inside it is the #1 way to get a broken setup — you'd
> be working inside *this* project's git checkout (wrong remote, no config), not your own.

**Step 1 — be in the folder you want as your project's home.** Make an empty one if you don't have it yet
(`mkdir my-project && cd my-project`). The installer scaffolds into whatever folder you're standing in.

**Step 2 — run the one-liner** (copy-paste, it just runs):

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/light-the-forge.sh | bash
```

It asks a handful of questions — **project name**, GitHub **owner**, a **one-line description**, and
whether to **kick off initial research** — shows a confirm step, then scaffolds the local layout
**into the current folder**:

```
my-project/                 ← you run the one-liner here; open THIS folder in Claude Code
├── .claude/                forge skills, agents, hooks, statusline, run-state
├── .knowledge/             lessons.md
├── CLAUDE.md, CONTEXT.md
├── docs/github-setup.md    ← the GitHub setup checklist you run yourself
└── <name>-app/             ← a fresh local git repo (your code goes here)
    └── .github/workflows/sync-board.yml
```

So if you type **`Recipe Box`**, you get the forge kit plus a local `recipe-box-app/` git repo with an
initial commit.

**Two folders, one of which becomes GitHub.** The outer folder (`my-project/`) is the *cockpit* — it holds
the forge tooling and never goes to GitHub. The inner `<name>-app/` folder **is your actual project**: it's
the only thing you push, and it becomes the GitHub repo where your code *and* the issues both live. (Your
code won't show up next to the issues until you create that repo and push `<name>-app/` to it — see below.)

**Requirements:** `git` and `jq`.

**Then set up the GitHub side yourself.** You own the repo, the Projects v2 board, the labels, the repo
variables, and the PAT secret — Claude only touches code. Follow
**[docs/github-setup.md](docs/github-setup.md)** for the exact `gh` commands (create + push the repo, build
the board and label set, set the variables and `FORGE_PROJECT_PAT` secret, and fill `PROJECT_NUMBER` in
`.claude/forge/config`). Run them yourself, or hand them to Claude when you want it to.

With GitHub in place: **open the project folder in Claude Code and run `/ponder`.** It picks up the
description (and any research request) from the seed the installer left, and the loop begins.

See **[docs/how-the-forge-evolved-works.md](docs/how-the-forge-evolved-works.md)** for the full
narrative — the forge loop, the board, context discipline, escalation, and knowledge.

## Already have a repo?

The installer is built for the fresh-scaffold flow above. To graft the forge onto an existing project,
mirror that layout by hand: put the forge `.claude/` tooling in an outer folder, keep your code in a
`<name>-app/` subfolder, and write `.claude/forge/config` with `APP_DIR`, `REPO_SLUG`, `BOARD_OWNER`, and
`PROJECT_NUMBER`. Provision the board, labels, variables, and secret per
[docs/github-setup.md](docs/github-setup.md).

---
name: light-the-forge
description: Scaffold a brand-new Forge Evolved project — runs light-the-forge.sh to install the kit into the outer project folder, create the <name>-app/ GitHub repo, and provision the board, labels, sync workflow, repo variables, and PAT secret. Use when the user says "light the forge", "start a new forge project", "set up the forge here", or "/light-the-forge".
---

# Light the Forge

Conversational wrapper around `light-the-forge.sh`. The script does all the file copying, repo creation, and
`gh` provisioning; this skill confirms intent, runs the script, and walks the user through the two steps that
genuinely need a human: the **`project` auth scope** and the **classic-PAT secret**.

Do **not** re-implement the scaffold/board/label logic here — that's the script's job. Run it, stream its
output, and help when it halts.

## What it does (the split layout)

The installer is built for a **fresh start**, not grafting onto an existing repo. Run from inside an empty
project folder, it creates:

```
<project-folder>/          ← you run it here; Claude Code opens HERE (forge tooling, not pushed)
└── <name>-app/            ← a NEW git repo it creates on GitHub + pushes
```

The outer folder holds the forge skills + run-state; the `<name>-app/` subfolder is the only thing on GitHub.

## Preconditions

- An **empty (or new) project folder** to run from (default `$(pwd)`). The script **creates** the GitHub repo
  — the folder must NOT already contain `<name>-app/`, and the target repo must NOT already exist (it aborts
  on either collision rather than clobbering).
- `gh`, `git`, and `jq` on PATH; `gh` authenticated with the **`project`** scope.
- The script won't overwrite an existing `CLAUDE.md`/`CONTEXT.md` and merges (not clobbers) `.claude/settings.json`.

## Workflow

### 1. Confirm intent

Ask once (skip if it's obvious from the user's message):

> Scaffold a new Forge project in `<current-dir>`? It'll ask for a name, owner, visibility, and description,
> then create the app repo on GitHub. Yes / different folder / cancel.

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

The script prompts (on `/dev/tty`) for: **project name**, **GitHub owner**, **visibility (private/public)**,
**one-line description**, and **whether to kick off initial research** — then shows a **confirm** step. After
that it runs: auth-check → install kit into the outer folder → scaffold `<name>-app/` + create/push the repo →
board → labels → IDs/variables → PAT secret → `config` + `seed.md` → settings.json. Stream its output; don't
re-summarize the file list it already prints.

### 3. Help past the auth-scope halt (if it fires)

If the script stops with **"missing the 'project' scope"**, relay the fix plainly:

```bash
gh auth refresh -s project
```

Then re-run the installer. The runtime requirement it states: the sync workflow needs a **classic** PAT with
the `project` scope — **fine-grained PATs do not support Projects v2**, and the Actions `GITHUB_TOKEN` cannot
touch Projects v2 at all. (This auth check is for the install step; the PAT secret is step 4 below.)

### 4. Help with the classic-PAT secret

Near the end the script asks for the **classic PAT** to store as the `FORGE_PROJECT_PAT` repo secret. Guide the user:

- Create one at <https://github.com/settings/tokens> → **Tokens (classic)** → scope **`project`** (add
  **`repo`** for a private app repo).
- Paste it at the hidden prompt, **or** skip and set it later:
  ```bash
  gh secret set FORGE_PROJECT_PAT --repo <owner>/<name>
  ```
- Until this secret exists, the labels→board sync workflow will not run. The rest of the install (repo, board,
  labels, variables, kit) is already in place.

### 5. Report the outcome

On exit 0, echo the script's summary essentials: the **app repo URL**, the **board URL**, the labels created,
the repo variables set (`FORGE_PROJECT_ID`, `FORGE_STATUS_FIELD_ID`, the five `FORGE_OPT_*`), whether the PAT
secret landed, and where the kit installed. Then point them at the next step: **open the project folder in
Claude Code and run `/ponder`** (it reads the seed the installer left).

On non-zero exit (collision with an existing folder/repo, missing `gh`/`git`/`jq`, repo or board creation
failed, auth halt), surface the script's stderr verbatim and stop — do not paper over a partial scaffold.

## Anti-patterns

- **Don't inline the scaffold/board/label logic.** This skill runs `light-the-forge.sh`; it never duplicates it.
- **Don't try to reuse an existing repo.** The script aborts on collision by design — relay that, don't work around it.
- **Don't overwrite the user's `CLAUDE.md` / `CONTEXT.md`.** The script already skips existing docs.
- **Don't invent IDs or string-edit `sync-board.yml`.** The workflow reads everything from the repo
  variables/secret the script sets; the file is copied as-is into the app repo.
- **Don't suggest a fine-grained PAT** for `FORGE_PROJECT_PAT` — it cannot drive Projects v2. Classic PAT only.

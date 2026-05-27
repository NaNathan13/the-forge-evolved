---
name: light-the-forge
description: Stand up The Forge Evolved on a target repo — runs light-the-forge.sh to install the kit and provision the GitHub board, labels, sync workflow, repo variables, and PAT secret. Use when the user says "light the forge", "install The Forge Evolved here", "set up the forge on this repo", or "/light-the-forge".
---

# Light the Forge

Conversational wrapper around `light-the-forge.sh`. The script does all the file copying and `gh` provisioning; this skill confirms the target, runs the script, and walks the user through the two steps that genuinely need a human: the **`project` auth scope** and the **classic-PAT secret**.

Do **not** re-implement the copy/board/label logic here — that's the script's job. Run it, stream its output, and help when it halts.

## Preconditions

- A target directory (default `$(pwd)`) that is a **GitHub repo** with an `origin` remote (the script resolves it via `gh repo view`; if it can't, it stops).
- `gh`, `git`, and `jq` on PATH; `gh` authenticated with the **`project`** scope.
- The script is idempotent: it won't overwrite an existing `CLAUDE.md`/`CONTEXT.md`, won't duplicate labels, and merges (not clobbers) `.claude/settings.json`.

## Workflow

### 1. Confirm the target

Ask once (skip if the user gave an explicit path):

> Install The Forge Evolved into `<current-dir>` (repo `<owner/name>`)? Yes / different path / cancel.

On cancel, stop.

### 2. Run the installer

From a local checkout of the-forge-evolved (preferred):

```bash
<path-to>/light-the-forge.sh <target-dir>
```

Or, once the repo is published, the one-liner self-fetches the kit:

```bash
curl -fsSL https://raw.githubusercontent.com/OWNER/the-forge-evolved/main/light-the-forge.sh | bash -s -- <target-dir>
```

The script prompts (on `/dev/tty`) for: project name, one-line description, test / type-check / lint commands, and the board owner. It then handles auth-check → copy kit → board → labels → IDs/variables → PAT secret → settings.json. Stream its output; don't re-summarize the file list it already prints.

### 3. Help past the auth-scope halt (if it fires)

If the script stops with **"missing the 'project' scope"**, relay the fix plainly:

```bash
gh auth refresh -s project
```

Then re-run the installer. Make sure the user understands the runtime requirement it states: the sync workflow needs a **classic** PAT with the `project` scope — **fine-grained PATs do not support Projects v2**, and the Actions `GITHUB_TOKEN` cannot touch Projects v2 at all. (This auth check is for the install step; the PAT secret is step 4 below.)

### 4. Help with the classic-PAT secret

Near the end the script asks for the **classic PAT** to store as the `FORGE_PROJECT_PAT` repo secret. Guide the user:

- Create one at <https://github.com/settings/tokens> → **Tokens (classic)** → scope **`project`** (add **`repo`** for a private target repo).
- Paste it at the hidden prompt, **or** skip and set it later:
  ```bash
  gh secret set FORGE_PROJECT_PAT --repo <owner/name>
  ```
- Until this secret exists, the labels→board sync workflow will not run. The rest of the install (board, labels, variables, kit) is already in place.

### 5. Report the outcome

On exit 0, echo the script's summary essentials: board URL, the labels created, the repo variables set (`FORGE_PROJECT_ID`, `FORGE_STATUS_FIELD_ID`, the five `FORGE_OPT_*`), whether the PAT secret landed, and the kit files installed. Then point them at the next step: **`/ponder`**.

On non-zero exit (target not a GitHub repo, missing `gh`/`git`/`jq`, board creation failed, auth halt), surface the script's stderr verbatim and stop — do not paper over a partial install.

## Anti-patterns

- **Don't inline the copy/board/label logic.** This skill runs `light-the-forge.sh`; it never duplicates it.
- **Don't overwrite the user's `CLAUDE.md` / `CONTEXT.md`.** The script already skips existing docs; never work around that.
- **Don't invent IDs or string-edit `sync-board.yml`.** The workflow reads everything from the repo variables/secret the script sets; the file is copied as-is.
- **Don't suggest a fine-grained PAT** for `FORGE_PROJECT_PAT` — it cannot drive Projects v2. Classic PAT only.

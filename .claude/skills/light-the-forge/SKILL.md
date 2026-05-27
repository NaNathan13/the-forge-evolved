---
name: light-the-forge
description: Bootstrap a project on The Forge Evolved — copy skills, agents, hooks, settings, and templates into the target repo, then set up the GitHub board/labels/sync. Use when the user says "install the forge into this project", "light the forge", "set up The Forge Evolved here", or "/light-the-forge". (Full installer behavior is built in Phase 7.)
---

# Light the Core

The bootstrap skill for a fresh project adopting **The Forge Core** — the stripped-down variant where state lives in `.claude/plans/active/<slug>.md` files instead of GitHub issues + a Mission Control doc.

This skill is a thin wrapper around `light-the-core.sh`. The shell script does the file copying; this skill confirms the target, runs the script, and reports what landed.

**Audience matters.** The user has just decided they want Core in this project. Keep it tight: confirm the target, copy the kit, then a short three-question setup to fill in the project docs. No GitHub setup, no dev-mode, no ceremony beyond those three questions.

## Preconditions

Before running the installer:

- We have a target directory. By default it's `$(pwd)`. If the user names a path, use it.
- The target does **not** already have `.claude/plans/` — Core refuses to overwrite an existing install. (Detected by the script; surface its message cleanly if it refuses.)

## Workflow

### 1. Confirm the target

Ask once via AskUserQuestion (skip if the user invoked with an explicit path):

> Install Core into `<current-dir>`? Options:
> - **Yes, install here** (Recommended)
> - **Different path** — freeform follow-up
> - **Cancel**

On `Cancel`, stop.

### 2. Run the installer

Install into the target with the one-step command — it fetches Core and installs, no clone needed:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-core/main/light-the-core.sh | bash -s -- <target-dir>
```

If a local checkout is already on hand (e.g. you're running from inside the Core repo), run `<path>/light-the-core.sh <target-dir>` instead — same result, no fetch.

Stream its output to the user. The script prints what it copied; don't duplicate that summary. If it exits non-zero (target already has `.claude/plans/`, no network, git missing), surface its stderr verbatim and stop.

### 3. Fill in the project docs

The installer drops `CLAUDE.md`, `CONTEXT.md`, and `README.md` with `<placeholder: ...>` markers. Ask three questions — as a short batch, freeform answers (not multiple-choice) — then write the answers into the docs:

1. **Project name?**
2. **What is this project, in one line?**
3. **Tech stack** — language/runtime, framework (or "none"), test runner, and the **check command** (the command that lints/tests the project; `/forge` and `/temper` run it).

Then edit the placeholder lines in the target docs — and *only* those lines, leaving the rest of each template intact:

- `<target>/CLAUDE.md`
  - `# <placeholder: project-name>` → `# <name>`
  - `One-line description of what this project is.` → the one-liner
  - the four `## Tech stack` rows → the stack answers (put the check command in the `**Check command:**` row)
  - the `- <placeholder: any project-specific hard rules …>` bullet → `- (add project-specific rules here as they emerge)`
- `<target>/CONTEXT.md`: `# CONTEXT — <placeholder: project-name>` → `# CONTEXT — <name>`
- `<target>/README.md`: `# <placeholder: project-name>` → `# <name>`, and the one-line description.

If the installer **skipped** a doc because it already existed (the user had their own), leave that doc alone — don't overwrite their content with answers.

### 4. Report the outcome

If the script exited 0, print:

```
The Core is lit.

Target:        <target-dir>
Plans live in: <target-dir>/.claude/plans/active/
Docs:          CLAUDE.md, CONTEXT.md, README.md (filled in from your answers)

Next: /ponder
```

If the script exited non-zero (target already has `.claude/plans/`, target doesn't exist, permission error), surface the script's stderr verbatim and stop.

## Anti-patterns

- **Don't inline the file-copy logic.** That's `light-the-core.sh`'s job. This skill just runs the script; it does not duplicate it.
- **Keep the Q&A to the three setup questions.** Name, one-liner, tech stack — that's it. No dev-mode, no GitHub repo creation, no labels. `/light-the-forge`'s longer interview is exactly what Core avoids.
- **Don't overwrite the user's `CLAUDE.md` / `CONTEXT.md` / `README.md`.** The installer already declines to clobber existing root docs; never paper over that.
- **Don't `git init` or create a GitHub repo.** Core is plan-files-on-disk; remote setup is the user's call.

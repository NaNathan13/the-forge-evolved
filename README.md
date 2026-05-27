# The Forge Evolved

A per-project, GitHub-native Claude Code workflow: plan a fuzzy idea into GitHub issues, then turn
Claude loose to autonomously drain an approved batch — build, review, and merge each issue — with a
hard context ceiling and no path for bad code to reach `main`.

Three commands, in order: **`/ponder`** (grill the idea, propose an issue breakdown) → **`/inscribe`**
(create the labeled issues + board cards) → **`/forge`** (approve the batch, then build→review→merge
each issue, then stop and report).

See **[docs/how-the-forge-evolved-works.md](docs/how-the-forge-evolved-works.md)** for the full
narrative — the forge loop, the board, context discipline, escalation, and knowledge.

## Install

Stand it up on a target repo with `/light-the-forge` (or run the script directly):

```bash
./light-the-forge.sh <target-dir>
```

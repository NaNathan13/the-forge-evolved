# The Forge Evolved

A per-project, GitHub-native Claude Code workflow: **ponder → inscribe → forge**. Plan an idea into
issues, then autonomously drain an approved batch (build → review → merge) with enforced context
discipline. This repo is both the workflow's source and what the installer drops into target projects.

## Commands

- `/ponder` — grill a fuzzy idea into shared understanding (research as needed); ends by proposing the
  issue breakdown for one-word approval.
- `/inscribe` — on approval, document the knowledge and create the GitHub issues (labels + machine-checkable
  acceptance criteria + board card).
- `/forge` — read the `status:ready` issues, propose the batch, and on approval drain it autonomously
  (build → review → merge per issue), then stop and report.

Use them sequentially. Don't `/forge` without ready issues — `/ponder` then `/inscribe` fill the queue first.

## Context discipline (CRITICAL)

- **Warn at 30%, hard-stop at 40%** of the context window. The statusline shows the gauge; the `ctx-gate`
  PreToolUse hook *enforces* it (denies tool calls at ≥40%). A real gate, not a label.
- At the hard stop: **write/refresh the handoff, then `/clear` and re-run the command.** Don't push past it.
- State lives in **GitHub issues/labels + git + `.claude/forge/loop-state`** — so resume is just `/clear`
  then re-run the command; it reads the board and picks up the next issue.
- <important if="context approaching 35%">Skills self-check at safe points and hand off proactively (~35%) to avoid being blocked mid-action. The ctx-gate hook is a backstop, not the plan — being denied a tool call at 40% means you handed off too late.</important>

## Architecture quirks

- **Thin orchestrator + fresh subagents.** `/forge` holds only the batch list + a 1-line status per issue;
  each issue gets a fresh builder and a fresh, independent reviewer. Orchestrator context stays flat, so the
  30/40 rule is structural, not a constant fight.
- **The reviewer is read-only and a different model** than the builder — it structurally cannot edit code to
  make it pass.
- **Use absolute paths in Bash.** The working directory resets between tool calls.
- **Skills load on demand** when their `/command` runs; role-based agents live in `.claude/agents/`.
- **Keep this file <100 lines.** Only CLAUDE.md loads every session — push detail to skills, glossary to
  CONTEXT.md, lessons to `.knowledge/`. Avoid `@imports` (they also load at startup).

## Response Style
- Concise. No preamble, no "I'll now..." narration.
- No explanations unless asked. Skip recaps of completed work.
- Code only when showing actual code, not summaries.
- When a task is done, end. No "let me know if..." closers.
- If I flag a mistake, fix it without re-asking or apologizing.

---
See CONTEXT.md for glossary (load on demand). See `.knowledge/lessons.md` (skill-fed).

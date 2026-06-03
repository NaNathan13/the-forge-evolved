# CONTEXT — {{PROJECT_NAME}}

> Glossary. Loaded on demand, not every session. The Forge vocabulary is pre-seeded below — leave it alone
> unless you genuinely diverge. Add your project's own terms under ## Project terms.

## Layout terms

**Outer / project folder**: Where Claude Code opens and the forge tooling lives (`.claude/`, `.knowledge/`,
`CLAUDE.md`, `.claude/forge/`). Not a git repo, not pushed anywhere — durable state lives in GitHub + the app repo.

**App dir** (`{{APP_DIR}}/`): The subfolder holding the actual code; the only thing on GitHub (repo
**{{REPO_SLUG}}**). All `git` operations run there (`git -C {{APP_DIR}} …`).

**Forge config** (`.claude/forge/config`): Written by `light-the-forge`. Holds `APP_DIR`, `REPO_SLUG`,
`BOARD_OWNER`, `PROJECT_NUMBER` — the skills source it to know where to run `git`/`gh`.

## Workflow terms

**Batch**: The set of `status:ready` issues `/forge` proposes to work in one run. You approve (and may trim)
it; approval is the moment autonomy begins. One run drains one batch, then stops and reports — no auto-chaining.

**Slice**: One discrete issue, small enough for a single fresh builder subagent to finish within one context
window. `/ponder` slices an idea into issues, typically splitting UI from logic. Outgrowing context on a slice
is a slicing failure → `needs-reslice`.

**Hard gate**: Objective checks that run before any AI review opinion counts — tests + type-check + lint
(`verify:test`) or a render/screenshot (`verify:visual`). A failed hard gate is an automatic FAIL; a builder
touching test files to pass is an automatic FAIL + escalation.

**Verification method**: The per-issue label `/inscribe` sets — `verify:test` (builder adds tests; tests/types/
lint gate it) or `verify:visual` (reviewer checks a render/screenshot). Drives builder obligation and reviewer
rubric.

**Escalation**: An issue that can't pass (3 failed rounds, diff >~2× expected scope, touched test/CI config, or
context overflow) is labeled `status:needs-human` + a reason (`review-failed` | `needs-reslice`), skipped, and
surfaced in the end-of-batch report. Never blocks the run waiting for a human; bad code never auto-merges.

**Handoff**: The continuation behind the 30/40 context rule. State lives in GitHub + git +
`.claude/forge/loop-state`, so resume = `/clear` then re-run `/forge`. `/ponder` writes a distilled handoff to
`.claude/forge/handoff.md` when it must checkpoint.

**Prospect**: The pre-ponder warm-up (`/prospect`, phase 0). Reads the kickoff seed (gated by its top-of-file
`status:` flag), proposes + runs prior-art research on approval, refines the vision, then writes
`.claude/forge/intake.md` — the findings `/ponder` opens from. Reusable before any new idea; writes only local
docs (flips the seed flag `todo`→`done`, never deletes it), no code/GitHub.

## Project terms

<!-- Add project-specific terms here as you find ambiguity. -->

(none yet — add as you find them)

## Decisions

> Hard-to-reverse, surprising-without-context, genuine-trade-off calls — the ones a future builder would
> otherwise re-litigate. `/ponder` appends them here as they're settled (decision · why · what it rules out);
> `/inscribe` threads the relevant one into the body of any issue it constrains, so the builder gets it where
> it works. Skip the routine: only decisions meeting all three criteria earn an entry.

(none yet — add as you settle them)

# CONTEXT — {{PROJECT_NAME}}

> Glossary. Loaded on demand, not every session. The Forge vocabulary is pre-seeded below — leave it alone
> unless you genuinely diverge. Add your project's own terms under ## Project terms.

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

## Project terms

<!-- Add project-specific terms here as you find ambiguity. -->

(none yet — add as you find them)

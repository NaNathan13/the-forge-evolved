# CONTEXT — glossary

Terms the Forge Evolved uses, pinned down once. Load this on demand when a term is unclear — it is **not**
loaded every session.

## Batch
The set of `status:ready` issues `/forge` proposes to work in one run. You approve (and may trim) it;
**approval is the moment autonomy begins.** One `/forge` run drains one batch, then stops and reports — no
auto-chaining to the next. A batch ≈ one phase of a larger plan, by convention, not by an enforced grouping.

## Slice
One discrete issue: a unit of work small enough for a single fresh builder subagent to finish within one
context window. `/ponder` slices an idea into issues, typically splitting UI from logic. If a builder
outgrows its context on one slice, that is a *slicing* failure → the issue is labeled `needs-reslice` and
escalated, never continued by a second builder.

## Hard gate
The objective checks that run *before* any AI review opinion counts: tests + type-check + lint (for
`verify:test`) or a render/screenshot capture (for `verify:visual`). A failed hard gate is an automatic FAIL.
A builder modifying, weakening, or deleting test files is an automatic FAIL **and** an escalation.

## Verification method
The per-issue label `/inscribe` sets to say how an issue is proven: `verify:test` (logic/backend — the
builder must add tests; tests/types/lint gate it) or `verify:visual` (UI — the reviewer checks a
render/screenshot plus a light objective check). It drives both the builder's obligation and the reviewer's
rubric.

## Escalation
The safety valve — never "wait for a human mid-run." An issue that can't pass (3 failed builder→reviewer
rounds, a diff exceeding ~2× expected scope, a touch to test/CI config, or context overflow) is labeled
`status:needs-human` + a reason (`review-failed` | `needs-reslice`), skipped, and surfaced in the
end-of-batch report. Bad code simply never auto-merges.

## Handoff
The continuation mechanism behind the 30/40 context rule. State lives in GitHub + git +
`.claude/forge/loop-state`, so resuming the loop is just `/clear` then re-run `/forge` (it reads the board and
picks up the next issue). `/ponder` is the exception (no external state yet): it writes a distilled handoff to
`.claude/forge/handoff.md` when it must checkpoint, which also lets `/inscribe` resume in a fresh context.

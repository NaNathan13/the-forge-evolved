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

## Prospect
The pre-ponder warm-up (`/prospect`) — phase 0. Reads the kickoff seed (`.claude/forge/seed.md`, gated by a
top-of-file `status:` flag), proposes prior-art research and runs it **on approval**, refines the vision in
conversation, then writes `.claude/forge/intake.md` — the findings `/ponder` opens from (it survives a
`/clear`). Reusable before any new idea, not just at kickoff. Writes only local docs (`intake.md` + flipping
the seed flag from `todo` to `done` — it never deletes the seed); no code, no GitHub.

## Permission baseline
The permission posture the Forge ships in `.claude/settings.json`: **`permissions.defaultMode:
"bypassPermissions"`** (Claude never prompts) **plus a small `permissions.deny` safety-net** that hard-fails a
few repo-destroying commands. Three things still bite under bypass — they are the *only* backstops: the
built-in `rm -rf /` / `rm -rf ~` circuit breakers, the `deny` list, and the `ctx-gate` PreToolUse hook (all
fire regardless of mode). It lives at the **outer** `.claude/settings.json` (the inner `<name>-app/` has none);
`light-the-forge` writes it for new installs and `update-forge` idempotently adds it to existing ones only if
absent. Replaces the old curated `allow` list, which is redundant once bypass is on.

## Decisions

> Hard-to-reverse, surprising-without-context, genuine-trade-off calls — the ones a future builder would
> otherwise re-litigate. `/ponder` appends them here as they're settled (decision · why · what it rules out);
> `/inscribe` threads the relevant one into the body of any issue it constrains. Only decisions meeting all
> three criteria earn an entry — skip the routine.

- **Posture = `bypassPermissions` + a small `deny` net, not a curated allow list.** · Why: the user runs
  autonomous `/forge` batches and was interrupted constantly for things they'd always approve (e.g.
  `rm -rf /tmp/...` temp cleanup — the built-in `rm -rf` Ask rule overrides auto mode). · Rules out: the
  prior allow-list model (now redundant); accepts that the deny net + built-in circuit breakers + `ctx-gate`
  hook are the *entire* safety surface for an unattended builder.
- **`deny` is the backstop, and it still works under bypass.** · Why: deny is evaluated before mode and
  hard-fails with no prompt, so it costs nothing on normal work while blocking a runaway builder from
  force-pushing / wiping the tree. · Rules out: relying on interactive approval to catch catastrophe — there
  is none under bypass.
- **The baseline is kit-policy but merged non-destructively.** · Why: `settings.json` is project-owned, so
  `update-forge` adds `defaultMode`/`deny` only when absent and never overrides a user's own edits. · Rules
  out: force-overwriting settings on update (would clobber local tweaks) and leaving existing installs on the
  old prompt-heavy posture.

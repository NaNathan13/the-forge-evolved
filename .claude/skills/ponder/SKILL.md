---
name: ponder
description: Phase 1 of the workflow — grill a fuzzy idea into shared understanding one question at a time, research unknowns as needed, then propose a GitHub issue breakdown for one-word approval and invoke /inscribe to create it. No code, no GitHub writes during ponder. Triggered by /ponder, "let's plan this", "think this through".
---

# /ponder — think the work through

`/ponder` turns a fuzzy idea into an agreed, sliced shape — then proposes the GitHub issue breakdown and, on your "go", invokes `/inscribe` to record it and create the issues. All in one session.

```
ponder → inscribe → forge      (ponder runs the interview + proposes the breakdown; inscribe writes it)
```

**Hard line: no code, no GitHub writes during ponder.** You are reaching understanding and proposing a breakdown. The only thing you may write is `.claude/forge/handoff.md` (the context checkpoint, below).

## 0. First run: read the seed (and resume from handoff if one exists)

**Resume takes priority:** check `.claude/forge/handoff.md` first. If it exists, read it, resume from where it left off (idea, decisions reached, open questions, next step), then continue the interview from that point. Don't re-litigate settled decisions — skip the seed below.

**Otherwise, this is a first run** — check `.claude/forge/seed.md`. The installer writes it from the answers you gave `light-the-forge`: the project description, and (if you asked for it) a `## Research first` note.

- Read the seed for the **idea** (the description) — open the interview from it instead of a blank slate; don't re-ask what it already states.
- If it has a `## Research first` section, that's your cue to do **initial prior-art research before grilling**: state in one line what you'll look into, then dispatch the **`forge-researcher`** subagent (see step 2) to survey how others solve this / best practices / what's out there. Fold its distilled answer into the opening questions — initial research often reshapes the build.
- Once you've absorbed the seed, **retire it**: `rm .claude/forge/seed.md` so it doesn't re-trigger on a later run. (The worked-out idea now lives in your interview, and ultimately in the issues.)

## 1. Interview — ONE question at a time

Lean on the `grill-me` skill. Stress-test the idea by walking the decision tree, surfacing hidden assumptions, and resolving each fork **one question at a time** — ask, wait for the answer, then ask the next. Never batch questions or hand the user a questionnaire. You are settling:

- **Scope** — what's in, what's explicitly out.
- **The shape of "done"** — what observable result proves the idea is built.
- **The slices** — how the work splits into discrete issues (see CONTEXT.md: *slice*), and in particular the **UI vs logic split**: backend/logic comes first, the UI that depends on it comes after.

Skip the grilling only when the work is genuinely small and unambiguous.

## 2. Research on demand (via forge-researcher)

Grill first. When a question can't be settled from the codebase or known facts — an unfamiliar library, prior art, a fork you can't call — dispatch the **`forge-researcher`** subagent with ONE focused question. It returns a distilled answer, not a transcript; feed that into the next question.

- **Confirm before any heavy or broad research fan-out.** A single scoped lookup can just run. Before launching broad/parallel research, state in one line what you intend and get a yes.
- Research informs the interview. It writes nothing.

## 3. Self-checkpoint context (the 30/40 rule)

This is a long interactive session — watch the context gauge. **At ~35%, before you get blocked mid-action:**

1. Write a distilled handoff to `.claude/forge/handoff.md` capturing: the **idea**, **decisions reached so far**, **open questions**, and the **next step**. Distill — it's a continuation note, not a transcript.
2. Tell the user: `/clear`, then re-run `/ponder` — it resumes from the handoff.

This is the **only** skill that writes `handoff.md`. It also lets `/inscribe` run in a fresh context off the same handoff if needed.

## 4. Propose the issue breakdown (then await one word)

When the shape is clear, present the proposed breakdown and ask for a **single one-word confirmation** (`go` / `yes`). Do NOT write anything outward yet. For **each issue**, list:

- **Title** — short, imperative.
- **Scope** — one or two lines: what's in this slice.
- **UI vs logic split** — order logic/backend issues *before* the UI that depends on them.
- **Verification method** — `verify:test` for logic/backend (tests prove it) or `verify:visual` for UI (render/screenshot check). See CONTEXT.md: *verification method*.
- **Machine-checkable acceptance criteria** — objective, verifiable conditions, not vibes ("`GET /api/items` returns 200 with a JSON array", not "the API works").

End with the question, e.g.:

> Proposed breakdown above — 4 issues, logic before UI. Reply `go` to create them, or tell me what to change.

## 5. On "go" → invoke /inscribe

- On `go`/`yes`: invoke `/inscribe` **in this same session** to document the knowledge and create the GitHub issues from the approved breakdown.
- If the user wants changes: revise the breakdown and re-ask for confirmation. Don't proceed on anything but a clear yes.

## Rules

- **No code, no GitHub writes in ponder.** Understanding and a proposed breakdown only. `/inscribe` does the writes.
- **One question at a time.** Never a questionnaire.
- **Resolve forks before proposing.** A breakdown built on an unresolved question just defers the problem into `/forge`.
- **One idea per ponder.** If two unrelated efforts surface, that's two separate ponders.
- **Confirm before heavy research.** Scoped lookups run; broad fan-out asks first.

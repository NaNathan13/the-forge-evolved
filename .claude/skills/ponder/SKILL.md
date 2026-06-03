---
name: ponder
description: Phase 1 of the workflow — grill a fuzzy idea into shared understanding one question at a time, research unknowns as needed, then propose a GitHub issue breakdown for one-word approval and invoke /inscribe to create it. No code, no GitHub writes during ponder. Triggered by /ponder, "let's plan this", "think this through".
---

# /ponder — think the work through

`/ponder` turns a fuzzy idea into an agreed, sliced shape — pinning the vocabulary and decisions as it goes — then proposes the GitHub issue breakdown and, on your "go", invokes `/inscribe` to file the issues. All in one session.

```
ponder → inscribe → forge      (ponder interviews, captures glossary + decisions, proposes the breakdown; inscribe files the issues)
```

**Hard line: no code, no GitHub writes during ponder.** You are reaching understanding and proposing a breakdown. The only files you may write are **local docs**: `.claude/forge/handoff.md` (the context checkpoint, below) and the **glossary + decisions** sections of `CONTEXT.md` as terms and calls get settled (step 1). No app code, no `gh` writes, no issues — `/inscribe` files those.

## 0. First run: read the seed (and resume from handoff if one exists)

**Resume takes priority:** check `.claude/forge/handoff.md` first. If it exists, read it, resume from where it left off (idea, decisions reached, open questions, next step), then continue the interview from that point. Don't re-litigate settled decisions — skip the seed below.

**Otherwise, this is a first run** — check `.claude/forge/seed.md`. The installer writes it from the answers you gave `light-the-forge`: the project description, and (if you asked for it) a `## Research first` note.

- Read the seed for the **idea** (the description) — open the interview from it instead of a blank slate; don't re-ask what it already states.
- If it has a `## Research first` section, that's your cue to do **initial prior-art research before grilling**: state in one line what you'll look into, then dispatch the **`forge-researcher`** subagent (see step 2) to survey how others solve this / best practices / what's out there. Fold its distilled answer into the opening questions — initial research often reshapes the build.
- Once you've absorbed the seed, **retire it**: `rm .claude/forge/seed.md` so it doesn't re-trigger on a later run. (The worked-out idea now lives in your interview, and ultimately in the issues.)

## 1. Interview — ONE question at a time, via the AskUserQuestion UI

**Anchor first.** Before the first question, read the existing domain language so you grill *from* it, not around it: `CONTEXT.md` (especially `## Project terms` and `## Decisions`) and `.knowledge/lessons.md`. When the user's wording diverges from a term already pinned there, that's a fork to resolve out loud — not a silent reinterpretation.

Grill the idea relentlessly: walk the decision tree, surface hidden assumptions, and resolve each fork **one question at a time** — ask, wait for the answer, then ask the next. Never batch questions or hand the user a questionnaire. For each fork, lead with your **recommended answer**. Four moves give the grilling teeth:

- **Sharpen vocabulary.** Challenge vague or overloaded words on the spot — pin a canonical term ("do you mean *Customer* or *User*?"). A word that conflicts with `## Project terms` is a conflict to call out, not absorb.
- **Truth-check against the code.** When the user asserts how something *already* works, don't take it on faith — verify it against the actual code (a **scoped** `forge-researcher` lookup, step 2) and surface any contradiction: "the code does X, you said Y — which holds?"
- **Stress-test with scenarios.** Probe boundaries with concrete invented cases, not just abstract forks — pressure the seams where two concepts meet until the design either holds or reveals a gap.
- **Write as you resolve (local docs only).** As a term gets pinned, append it to `CONTEXT.md` `## Project terms` (never the seeded Layout/Workflow vocab). When a call is **hard-to-reverse AND surprising-without-context AND a genuine trade-off**, append it to `## Decisions` (decision · why · what it rules out). Routine choices earn no entry. These two sections are the only outward write ponder makes besides the handoff — no `gh`, no code.

**Always ask through the `AskUserQuestion` tool — never as plain prose in your reply.** This is the interactive UI the user answers (it's how they answer from the Claude phone app / `/remote-control`; a free-text question in prose can't be answered there). Per question:

- Send **one question object** per call (the one-question-at-a-time doctrine). Don't fan out 4 questions to dodge the rule.
- Give it a short `header`, the full `question`, and **2–4 concrete options** — the plausible answers to that fork, each with a one-line `description` of the tradeoff. Proposing real options *is* the grilling; make them specific to this idea, not generic.
- The UI always offers a free-text "Other" escape, so open-ended forks still work — frame the options as your best guesses and let the user override.
- When their answer opens the next fork, ask the next question the same way.

You are settling:

- **Scope** — what's in, what's explicitly out.
- **The shape of "done"** — what observable result proves the idea is built.
- **The slices** — how the work splits into discrete issues (see CONTEXT.md: *slice*), and in particular the **UI vs logic split**: backend/logic comes first, the UI that depends on it comes after.

Skip the grilling only when the work is genuinely small and unambiguous.

## 2. Research on demand (via forge-researcher)

Grill first. When a question can't be settled from the codebase or known facts — an unfamiliar library, prior art, a fork you can't call — or to **truth-check a claim against the code** (step 1) — dispatch the **`forge-researcher`** subagent with ONE focused question. It returns a distilled answer, not a transcript; feed that into the next question.

- **Confirm before any heavy or broad research fan-out.** A single scoped lookup — including a code-truth-check — can just run. Before launching broad/parallel research, state in one line what you intend and get a yes.
- Research informs the interview. It writes nothing.

## 3. Self-checkpoint context (the 30/40 rule)

This is a long interactive session — watch the context gauge. **At ~35%, before you get blocked mid-action:**

1. Write a distilled handoff to `.claude/forge/handoff.md` capturing: the **idea**, **decisions reached so far**, **open questions**, and the **next step**. Distill — it's a continuation note, not a transcript. Resolved terms and qualifying decisions are already written to `CONTEXT.md`; point to them, don't recopy them.
2. Tell the user: `/clear`, then re-run `/ponder` — it resumes from the handoff.

This is the **only** skill that writes `handoff.md`. Because pinned terms and decisions already live in `CONTEXT.md`, a resume doesn't redo them — the handoff just carries the in-flight thread. It also lets `/inscribe` run in a fresh context off the same handoff if needed.

## 4. Propose the issue breakdown (then await one word)

When the shape is clear, present the proposed breakdown and ask for a **single one-word confirmation** (`go` / `yes`). Do NOT write anything outward yet. For **each issue**, list:

- **Title** — short, imperative.
- **Scope** — one or two lines: what's in this slice.
- **UI vs logic split** — order logic/backend issues *before* the UI that depends on them.
- **Verification method** — `verify:test` for logic/backend (tests prove it) or `verify:visual` for UI (render/screenshot check). See CONTEXT.md: *verification method*.
- **Machine-checkable acceptance criteria** — objective, verifiable conditions, not vibes ("`GET /api/items` returns 200 with a JSON array", not "the API works").

Present the breakdown itself as text (it's long-form), then put the **approval gate through the `AskUserQuestion` tool** so it's answerable from the phone — one question, e.g. header `Breakdown`, question "Proposed breakdown above — 4 issues, logic before UI. Create them?", options like **"Go — create the issues"** and **"Change something"** (the user types what to change via "Other").

## 5. On "go" → invoke /inscribe

- On `go`/`yes`: invoke `/inscribe` **in this same session** to file the GitHub issues from the approved breakdown. The glossary and decisions are already recorded in `CONTEXT.md`; inscribe threads the constraining decisions into the issues that need them — it doesn't re-document what ponder already captured.
- If the user wants changes: revise the breakdown and re-ask for confirmation. Don't proceed on anything but a clear yes.

## Rules

- **No code, no GitHub writes in ponder.** Local-doc writes only: `handoff.md` + `CONTEXT.md` glossary/decisions as they settle. `/inscribe` does the GitHub/issue writes.
- **Grill from the existing language.** Anchor to `CONTEXT.md` + `.knowledge` before the first question; sharpen vague terms into canonical ones, truth-check claims against the code, and pin resolved terms/decisions to `CONTEXT.md` as you go.
- **Ask through the `AskUserQuestion` UI, not prose.** Every interview question and the approval gate go through the tool so they're answerable from the phone. One question object per call.
- **Resolve forks before proposing.** A breakdown built on an unresolved question just defers the problem into `/forge`.
- **One idea per ponder.** If two unrelated efforts surface, that's two separate ponders.
- **Confirm before heavy research.** Scoped lookups run; broad fan-out asks first.

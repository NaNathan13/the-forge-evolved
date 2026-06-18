---
name: ponder
description: Phase 1 of the workflow — grill a fuzzy idea into shared understanding one question at a time, research unknowns as needed, then propose a task-file breakdown (thread-ordered, walking-skeleton first) for one-word approval and invoke /inscribe to write it. No code, nothing built during ponder. Triggered by /ponder, "let's plan this", "think this through".
---

# /ponder — think the work through

`/ponder` turns a fuzzy idea into an agreed, sliced shape — pinning the vocabulary and decisions as it goes — then proposes the **task-file breakdown** and, on your "go", invokes `/inscribe` to write the task files. All in one session.

```
prospect → ponder → inscribe → forge      (ponder interviews from prospect's findings, captures glossary + decisions, proposes the breakdown; inscribe writes the task files)
```

**Hard line: no code, nothing built during ponder.** You are reaching understanding and proposing a breakdown. The only files you may write are **local docs**: `.forge/continue.md` (the continuity checkpoint, below) and the **glossary + decisions** sections of `CONTEXT.md` as terms and calls get settled (step 1). No app code, no task files — `/inscribe` writes those.

## 0. First run: pick up where the work left off

**Resume takes priority:** check `.forge/continue.md` first. If its `Now`/`Next` show an in-flight ponder, resume from there (idea, decisions reached, open questions, next step), then continue the interview from that point. Don't re-litigate settled decisions — skip the rest of this step.

**Otherwise, open from `/prospect`'s findings.** Read `.forge/research/intake.md` — the warm starting point prospect leaves: the **refined idea**, a **research digest**, and the **open questions** it deliberately left for you. Open the interview from there; don't re-research what the digest already settled, and lead with its open questions.

**Fallback — no `intake.md` (prospect wasn't run).** Read `.forge/seed.md` for the **idea** (the project description) and open from it instead of a blank slate; don't re-ask what it already states. If it carries a `## Research first` note, the user wanted prior art gathered first — **point them at `/prospect`** for that rather than running a broad fan-out mid-grill (scoped research-on-demand, step 2, still applies). Once consumed, flip the seed's flag to `status: done` — don't delete it; it's the original-vision record.

## 1. Interview — ONE question at a time, via the AskUserQuestion UI

**Anchor first.** Before the first question, read the existing domain language so you grill *from* it, not around it: `CONTEXT.md` (especially `## Project terms` and `## Decisions`) and `.knowledge/lessons.md`. When the user's wording diverges from a term already pinned there, that's a fork to resolve out loud — not a silent reinterpretation.

Grill the idea relentlessly: walk the decision tree, surface hidden assumptions, and resolve each fork **one question at a time** — ask, wait for the answer, then ask the next. Never batch questions or hand the user a questionnaire. For each fork, lead with your **recommended answer**. Four moves give the grilling teeth:

- **Sharpen vocabulary.** Challenge vague or overloaded words on the spot — pin a canonical term ("do you mean *Customer* or *User*?"). A word that conflicts with `## Project terms` is a conflict to call out, not absorb.
- **Truth-check against the code.** When the user asserts how something *already* works, don't take it on faith — verify it against the actual code (a **scoped** `forge-researcher` lookup, step 2) and surface any contradiction: "the code does X, you said Y — which holds?"
- **Stress-test with scenarios.** Probe boundaries with concrete invented cases, not just abstract forks — pressure the seams where two concepts meet until the design either holds or reveals a gap.
- **Write as you resolve (local docs only).** As a term gets pinned, append it to `CONTEXT.md` `## Project terms` (never the seeded Layout/Workflow vocab). When a call is **hard-to-reverse AND surprising-without-context AND a genuine trade-off**, append it to `## Decisions` (decision · why · what it rules out). Routine choices earn no entry. These two sections are the only outward write ponder makes besides the continuity journal — no task files, no code.

**Always ask through the `AskUserQuestion` tool — never as plain prose in your reply.** This is the interactive UI the user answers (it's how they answer from the Claude phone app / `/remote-control`; a free-text question in prose can't be answered there). Per question:

- Send **one question object** per call (the one-question-at-a-time doctrine). Don't fan out 4 questions to dodge the rule.
- Give it a short `header`, the full `question`, and **2–4 concrete options** — the plausible answers to that fork, each with a one-line `description` of the tradeoff. Proposing real options *is* the grilling; make them specific to this idea, not generic.
- The UI always offers a free-text "Other" escape, so open-ended forks still work — frame the options as your best guesses and let the user override.
- When their answer opens the next fork, ask the next question the same way.

You are settling:

- **Scope** — what's in, what's explicitly out.
- **The shape of "done"** — what observable result proves the idea is built.
- **The threads** — how the work splits into **vertical threads**, not horizontal layers (see CONTEXT.md: *thread*, *walking skeleton*). Two moves:
  - **Walking skeleton first.** Before any feature thread, settle the *thinnest end-to-end thread that proves the whole stack wires together* — "what's the smallest slice that touches every layer and runs end to end?" That's `thread: 0`; it deploys first for early runtime validation.
  - **Thread-order, logic-before-UI within each.** Each feature thread is one vertical slice ordered logic/backend first, then the UI that depends on it (thread 1 logic → thread 1 UI → thread 2 logic → …). Order by thread, not by layer-across-the-whole-app.

Skip the grilling only when the work is genuinely small and unambiguous.

## 2. Research on demand (via forge-researcher)

The big upfront prior-art sweep is `/prospect`'s job — here research is **scoped, on-demand gap-filling**. Grill first. When a question can't be settled from the codebase or known facts — an unfamiliar library, prior art, a fork you can't call — or to **truth-check a claim against the code** (step 1) — dispatch the **`forge-researcher`** subagent with ONE focused question. It returns a distilled answer, not a transcript; feed that into the next question.

- **Confirm before any heavy or broad research fan-out.** A single scoped lookup — including a code-truth-check — can just run. Before launching broad/parallel research, state in one line what you intend and get a yes.
- Research informs the interview. It writes nothing.

## 3. Self-checkpoint context (the 40/50 rule)

This is a long interactive session — watch the context gauge. **At the 40% warn, before you get blocked mid-action:**

1. Refresh `.forge/continue.md` — its `Now` (active thread/decision), `Next` (the next step), and any durable `Friction` note. Distill — it's a continuation note, not a transcript. Resolved terms and qualifying decisions are already written to `CONTEXT.md`; point to them, don't recopy them.
2. Tell the user: `/clear`, then re-run `/ponder` — it resumes from `continue.md`.

`.forge/continue.md` is the single continuity journal (it replaces the old `handoff.md`). Because pinned terms and decisions already live in `CONTEXT.md`, a resume doesn't redo them — the journal just carries the in-flight thread. It also lets `/inscribe` run in a fresh context off the same journal if needed.

## 4. Propose the task breakdown (then await one word)

When the shape is clear, present the proposed breakdown and ask for a **single one-word confirmation** (`go` / `yes`). Do NOT write anything outward yet. Present it **thread-ordered** — the walking skeleton (`thread: 0`) first, then each feature thread logic-before-UI. For **each task**, list:

- **Title** — short, imperative.
- **Thread** — which thread it belongs to (`0` = walking skeleton; `1, 2, …` = feature threads), and its order within.
- **Scope** — one or two lines: what's in this slice.
- **Verification method** — `verify:test` (new behavior → tests prove it), `verify:visual` (UI → render/screenshot check), or `verify:check` (behavior-preserving refactor/config/docs/chore → no new tests required; existing test+type+lint must keep passing). See CONTEXT.md: *verification method*.
- **Machine-checkable acceptance criteria** — objective, verifiable conditions, not vibes ("`GET /api/items` returns 200 with a JSON array", not "the API works").

Present the breakdown itself as text (it's long-form), then put the **approval gate through the `AskUserQuestion` tool** so it's answerable from the phone — one question, e.g. header `Breakdown`, question "Proposed breakdown above — skeleton + 3 feature threads, logic before UI. Create the tasks?", options like **"Go — create the tasks"** and **"Change something"** (the user types what to change via "Other").

## 5. On "go" → invoke /inscribe

- On `go`/`yes`: invoke `/inscribe` **in this same session** to write the task files from the approved breakdown. The glossary and decisions are already recorded in `CONTEXT.md`; inscribe threads the constraining decisions into the tasks that need them — it doesn't re-document what ponder already captured.
- If the user wants changes: revise the breakdown and re-ask for confirmation. Don't proceed on anything but a clear yes.

## Rules

- **No code, nothing built in ponder.** Local-doc writes only: `.forge/continue.md` + `CONTEXT.md` glossary/decisions as they settle. `/inscribe` writes the task files.
- **Grill from the existing language.** Anchor to `CONTEXT.md` + `.knowledge` before the first question; sharpen vague terms into canonical ones, truth-check claims against the code, and pin resolved terms/decisions to `CONTEXT.md` as you go.
- **Ask through the `AskUserQuestion` UI, not prose.** Every interview question and the approval gate go through the tool so they're answerable from the phone. One question object per call.
- **Thread-order, skeleton first.** Slice into vertical threads; the thinnest end-to-end walking skeleton (`thread: 0`) comes before any feature thread, and logic precedes UI within each thread.
- **Resolve forks before proposing.** A breakdown built on an unresolved question just defers the problem into `/forge`.
- **One idea per ponder.** If two unrelated efforts surface, that's two separate ponders.
- **Confirm before heavy research.** Scoped lookups run; broad fan-out asks first.

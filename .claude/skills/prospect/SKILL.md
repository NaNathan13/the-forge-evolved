---
name: prospect
description: Phase 0 of the workflow — the pre-ponder warm-up. Read the seed (or a fresh idea), propose the prior-art research you intend to run, run it on approval, refine the vision in conversation, then write a durable findings file and hand into /ponder warm. Reusable before any new idea, not just at project kickoff. Triggered by /prospect, "scout this idea", "research before planning".
---

# /prospect — warm the idea before you ponder it

`/prospect` is the reconnaissance phase: it turns a one-line seed (or a fresh idea you bring) into a
**researched, refined starting point** so `/ponder` opens warm instead of from a blank line. It reads what
setup captured, proposes the research worth doing, runs it **only on your approval**, talks the vision into
focus, and writes a findings file that survives a `/clear`.

```
prospect → ponder → inscribe → forge      (prospect researches + refines; ponder grills it into a sliced plan)
```

It's **reusable**: most often it runs first, reading the kickoff seed — but invoke it anytime you're about to
ponder a fresh idea and want prior art and context gathered first.

**Hard line: no code, nothing built during prospect.** You are gathering understanding. The only files you
may write are **local docs**: `.forge/research/intake.md` (the findings hand-off, below), other
`.forge/research/<topic>.md` findings, and flipping the seed's done flag. No app code, no task files — those
come later.

## 0. Pick up the idea (seed-gated, with a fresh-idea fallback)

Read `.forge/seed.md`. It carries a top-of-file flag:

```
---
status: todo
---
```

- **`status: todo`** → this is a fresh kickoff. Read the idea (the description) and any `## Research first`
  note as your opening material. You'll flip it to `done` once consumed (step 4).
- **`status: done`, or no seed** → there's nothing to consume. Open from the idea the user states in
  conversation. `/prospect` works fine with no seed at all — it just starts from what they tell you.

Don't re-ask what the seed already states. Anchor to the existing project language too: skim `CONTEXT.md`
(`## Project terms`, `## Decisions`) and `.knowledge/lessons.md` so the research and conversation build on
what's already pinned.

## 1. Propose the research plan — then await approval (via AskUserQuestion)

State **what you intend to look into before you look** — prospect's defining move is "say the plan, get a yes,
then go." Distill the idea (and any `## Research first` note) into a short, concrete research plan: the 1–4
focused questions worth answering (prior art, how others solve this, best practices, library/stack options,
known pitfalls) and roughly how wide you'd fan out.

Put the go/adjust gate through the **`AskUserQuestion`** tool so it's answerable from the phone — present the
plan as text, then one question (header `Research plan`, e.g. "Run these N lookups before we ponder?") with
options like **"Go — run it"** and **"Adjust the plan"** (user refines via "Other"). Never fan out research
the user hasn't seen and approved.

## 2. Run the research (via forge-researcher)

On approval, dispatch the **`forge-researcher`** subagent(s) — **one focused question each**; run independent
questions in parallel. Each returns a *distilled* answer, not a transcript. As findings land, keep the user in
the loop with a line or two on what came back, and let a result reshape the next question (research often
changes the shape of the build).

A single scoped lookup can just run; the approval gate is for the **broad fan-out** that is prospect's bulk.

## 3. Refine the vision — keep talking

Research informs a conversation, it doesn't replace it. Walk the idea with the user — one question at a time,
leading with your recommended take — until the vision is **focused enough to grill**: what they're building,
what's in/out at a high level, the constraints that matter, the forks the research surfaced. This is lighter
than `/ponder`'s full decision-tree grill — you're sharpening the *starting point*, not settling every slice.
Pin genuinely-settled vocabulary to `CONTEXT.md` `## Project terms` as it comes up; leave the deeper decisions
for ponder.

## 4. Write the findings + flip the seed flag

When the ground is prepared, write `.forge/research/intake.md` — the durable hand-off `/ponder` reads on
start (it survives a `/clear`). Other durable findings worth keeping go to `.forge/research/<topic>.md`:

```markdown
# Prospect — <idea>

## Refined idea
<the vision, sharpened through research + conversation>

## Research digest
<distilled findings: prior art, best practices, options weighed, pitfalls to avoid>

## Open questions for ponder
<the forks prospect surfaced but deliberately left for ponder to resolve>

<!-- Written by /prospect; /ponder reads this on first run. -->
```

Then, if you consumed a `status: todo` seed, **flip its flag to `status: done`** (don't delete it — the seed
is the original-vision record). Distill — `intake.md` is a warm starting point, not a transcript.

## 5. Self-checkpoint context (the 40/50 rule)

Research is context-hungry — watch the gauge. Prospect's findings already live in `.forge/research/`, so a
checkpoint is cheap: at the **40% warn**, make sure `intake.md` is current, then it's safe to `/clear`. The
findings file *is* the handoff (it folds into `.forge/continue.md`'s job) — there's no separate `handoff.md`.

## 6. Hand into /ponder (recommend, don't auto-run)

When the idea is researched and focused, **recommend** the next step — don't auto-invoke:

> Ground's prepared — findings in `.forge/research/intake.md`. If context ran heavy, `/clear` first, then
> run `/ponder` to grill this into a sliced plan.

Recommending (rather than chaining) is deliberate: prospect often ends at a natural `/clear` boundary after a
research-heavy session, and `intake.md` is exactly what lets ponder pick up cold.

## Rules

- **No code, nothing built in prospect.** Local-doc writes only: `.forge/research/` + flipping the seed flag.
- **Say the plan before you research.** Propose the lookups and get a yes through `AskUserQuestion` before any
  broad fan-out. A single scoped lookup can just run.
- **Recommend ponder, don't auto-invoke.** End at a clean boundary; `intake.md` carries the context across.
- **Don't grill the whole tree.** Sharpen the starting point; leave slice-level decisions to `/ponder`.
- **One idea per prospect.** Two unrelated efforts are two prospects.

---
name: ponder
description: Phase 1 of the workflow — turn a fuzzy idea into shared understanding by grilling it, then hand off to /inscribe to write the plan. Use when starting new work from a rough idea. Triggered by /ponder.
---

# /ponder — think the work through

`/ponder` is the **planning phase** — it turns a fuzzy idea into a clear, agreed shape *before* a single line gets written. No code, no plan file; that's `/inscribe`'s job.

```
Ponder → Forge → Temper → Seal      (the Ponder phase = /ponder then /inscribe)
```

## What it does

1. **Understand the idea.** Read what the user is asking for. If anything material is ambiguous — scope, the shape of "done", a fork in approach — resolve it now, not later.

2. **Classify what must not be lost, and who uses it.** Part of understanding any app is settling two things that decide its architecture: does it keep information the user will expect to find later (→ it needs durable, server-side storage — never browser-only), and is it for one person or shared by several (→ a local file store vs. a server others on the network can reach)? Settle both before handing off. The build doctrine in `CLAUDE.md` ("Building apps people will rely on") spells out the defaults — you make these calls; don't make the user pick technology.

3. **Grill it.** For anything non-trivial, lean on the `grill-me` skill to stress-test the idea: walk the decision tree, surface hidden assumptions, settle each open question one at a time. Skip the grilling only when the work is genuinely small and unambiguous.

   **Research on demand.** Grill first; when a question can't be settled from the codebase or known facts — an unfamiliar library, prior art, a fork you can't call — lean on the `research` skill, then feed what comes back into the next question. Light research just runs; deep research (a parallel subagent fan-out) confirms with the operator before launching. Research informs the grill; it writes nothing.

4. **Settle the slices.** By the end you should know, roughly, how the work breaks into parts — the slices `/inscribe` will write down. A slice is one coherent chunk of work you could describe in a sentence. Aim for a handful, not twenty.

5. **Hand off.** Once the shape is clear, stop and recommend the next step:

   > Understanding reached. Run `/inscribe` to write the plan.

## Rules

- **No plan file here.** `/ponder` reaches understanding; `/inscribe` records it. Don't create anything under `.claude/plans/`.
- **No code.** Planning only.
- **Resolve forks before inscribing.** A plan written on top of an unresolved question just defers the problem into `/forge`.
- **One idea per ponder.** If the conversation reveals two unrelated efforts, that's two plans — ponder them separately.

---
name: envision
description: Drive Anthropic's Claude Design through a structured, screenshot-gated checkpoint loop — turn a defined concept into a coherent multi-screen design system (brand → design system → nav → screens in batches), then hand the exported designs to the build phase. A standalone utility, not a pipeline phase. Triggered by /envision, "design the screens", "drive claude design", "envision the UI".
---

# /envision — design the screens with Claude Design

`/envision` turns an already-defined concept into a coherent, drift-free set of screen designs by driving **Claude Design** (claude.ai/design) through ordered checkpoints. It authors the brief, then walks the design system and screens in small batches, **verifying each checkpoint against a screenshot before advancing**. It writes a handoff bundle the build phase consumes — it does **not** write app code.

It's a **utility**: invoke it whenever you're ready to design. It isn't a pipeline phase and `/forge` doesn't depend on it — but `/inscribe` and `/forge` signpost it for UI work.

```
prospect → ponder → inscribe → forge    (envision is invoked between inscribe and forge, on demand, for UI slices)
```

**Read `references/design-principles.md` once at the start of every run.** It carries the research-backed rules, the prompt templates, the completeness-audit checklist, and the batching heuristic that make the output good. This SKILL.md is the control flow; that file is the craft.

## Invocation

```
/envision                  # resume if state exists, else start from the project concept
/envision <concept/brief>  # start from a pointer to a concept doc or an existing design brief
```

## 0. Resume-awareness (first thing, every run)

Check `.forge/envision.md`. If it exists, read it and **resume from the cursor** — the locked brand, the design-system reference, the agreed batch plan, and the per-checkpoint status (pending / approved). Don't re-litigate locked decisions or re-design approved screens. If there's no state file, start fresh at step 1.

## 1. Inputs & stack detection

- **Concept:** the product idea + the screen list. Take it from the argument, an existing concept/PRD doc, or — if none — a one-line ask. `/envision` needs a *defined* idea; it does not invent the product (that's `/ponder`).
- **Existing brief?** If a `claude-design-brief.md`-style doc already exists, reuse it and **skip brief authoring** (step 2). Otherwise author it.
- **Stack:** auto-detect the target from `CLAUDE.md` / project files (RN+NativeWind, web React+Tailwind, plain HTML/CSS, Liquid…). Ask only if ambiguous. The stack shapes exactly two things in the brief — the **"output target"** line and the **token output shape**; everything else is universal.

## 2. Author the brief (skip if one exists)

Produce the brief via a **full quality pass**, not a template fill (`references/design-principles.md` has the anatomy + templates):

1. **Short vibe/brand grill** — settle the product's voice/feel and hard constraints (anti-cliché, fonts to avoid). Grill one question at a time, leading with your recommended answer — a few questions, not a questionnaire.
2. **Interactive completeness audit** — check the screen list against the product and **propose the usual gaps for accept/reject**: nav backbone, error/offline states, lifecycle actions (rename/archive/delete), empty states, loading states. The operator accepts or rejects each. (Checklist in the reference.)
3. **Bake in the rules** — system-first, lock brand before screens, name the shared components, enumerate states + failure paths per screen, stack-correct semantic-token shape.

Save the brief to `docs/design/brief.md`.

## 3. The checkpoint loop (courier model — you are the relay)

Claude Design has no API/MCP (verified — research-preview, UI-only). `/envision` drives it **through the operator**. Each checkpoint:

1. **Emit one copy-paste prompt** for the operator to paste into Claude Design (templates in the reference).
2. **Operator runs it** and pastes back Claude Design's response **+ a screenshot**.
3. **Verify against the brief — BLOCKING.** Do not advance without a screenshot. Check: both light + dark present? every promised state/element there? shared components reused (no drift / re-invented badges or colors)? stack-correct token shape?
   - *Preview-down fallback:* Claude Design's screenshot preview is sometimes unavailable. If so, accept its **forked verifier agent's** visual sweep as interim and keep moving — but still capture a real screenshot of that surface before final sign-off; don't let the gate silently lapse for a whole batch.
4. **Branch:** clean → approve, update the state file, emit the **next** prompt. Off → emit a **revision** prompt for the *same* checkpoint and stay put.

If an official Claude Design API/MCP ever ships, the relay in this step is the only thing that changes — the sequence and verification stay.

## 4. Sequence — locked foundation, derived batches

**Foundation (in order, non-negotiable — this is the anti-drift spine). Auto-skip any step whose artifact already exists:**

1. **Brand** — propose 2–3 directions, **stop for the operator to lock one.** Frozen after.
2. **Design system** — emit reusable semantic tokens (light + dark), scales, and the **recurring components as named primitives** (e.g. a status-badge set, a coverage/meter). Publish to the org design system if available; else keep building in one project and re-anchor on fresh sessions.
3. **Nav backbone** — the IA map + shared chrome (tab bar / headers) as components.

**Screens — derived per project:** group the *actual* screen list into **small batches by shared surface**, give the **hero/centerpiece screen its own solo pass**, and **confirm the batch plan with the operator** before starting. One batch at a time; verify each before the next. (Grouping heuristic in the reference.)

## 4b. Optional capstone — clickable prototype

After the screens, offer to have Claude Design wire a **clickable prototype** of the happy path with the 2–3 signature branches (not an exhaustive click-through — that just duplicates the static frames). Its real value is surfacing **navigation/transition gaps static screens hide** — in practice this catches missing back-affordances and dead-end flows. **Fold any fix back into the static screen + its spec** so the prototype, the statics, and the nav backbone agree. Skip it only when the flow is trivial.

## 5. State & context discipline

- After each approved checkpoint, refresh `.forge/envision.md`: locked brand, design-system reference, batch plan, per-checkpoint status, the next step.
- This is a long interactive session — honor the 40/50 rule. **At the 40% warn**, refresh the state file and tell the operator: `/clear`, then re-run `/envision` (it resumes from state). Don't push to the hard gate.

## 6. Output — the handoff bundle (no app code)

When the batches are done:

- **Have Claude Design author the handoff bundle**, then export it — it carries all the RN-translation context (conic-ring→SVG, dashed borders, swipe, safe areas), so let it write the Markdown: `README.md` / `tokens.md` (token map → the stack's token shape) / `components.md` (shared primitives + props + RN notes) / `screens/*.md` (states + components + a navigation contract). Export the whole project (operator-driven — "Handoff to Claude Code" / .zip) into `docs/design/`, alongside the raw HTML/CSS and screenshots.
- **Integrate + reconcile (operator side — you can't fetch the canvas).** When the bundle lands in the repo:
  - **Reconcile the task tags — Claude Design GUESSES task numbers and gets them wrong.** Verify every `screens/*.md` / README / HANDOFF tag against the *real* `.forge/tasks/` ids and correct them; never trust the export's numbers.
  - **Watch for gitignored screenshots.** A global `screenshots/` ignore rule will silently drop the reference shots — confirm they actually get tracked (add a scoped exception if needed), or the bundle lands incomplete.
- **Optionally link each UI task to its design** — link the relevant `.forge/tasks/` UI task to its `screens/*.md` so the builder meets the design where it works. There are no labels to clear (a task is already `status: ready`); no code, no token porting, no component scaffolding — those belong to `/forge`.

## Rules

- **Never advance a checkpoint without a screenshot.** The visual gate is the quality engine.
- **System-first, always.** Brand and design system before any screen; the foundation order is fixed.
- **Lock brand before screens.** Propose options, freeze the pick, never re-invent name/accent/badges later.
- **One batch at a time.** Verify each before the next; the hero screen gets a solo pass.
- **No app code.** `/envision` produces designs + a handoff; `/forge` builds them.
- **Don't invent the product.** A defined concept is the input; this is design, not `/ponder`.
- **Never trust the export's task numbers.** Claude Design guesses them — reconcile every tag against the real `.forge/tasks/` ids on integration.
- **Read `references/design-principles.md` every run** — don't rely on memory for the craft.

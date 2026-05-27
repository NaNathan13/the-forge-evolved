# Vision — The Forge Evolved (2.0)

> Status: **draft, pre-grill.** Captured 2026-05-27 from the kickoff conversation + research into
> [`the-forge-core`](research/forge-core-findings.md) and [`The-Forge`](research/the-forge-findings.md).
> This is the directional north star. It will be sharpened by a `/grill-me` session before any build.

---

## The one-sentence vision

The Forge Evolved is **the Forge Core's lightweight four-phase spine** with a **curated set of full
amenities** — GitHub-native task flow, a genuinely autonomous build loop, and enforced context
discipline — added with *a little more ceremony, not full ceremony*.

It is explicitly a correction of The Forge: same ambitions, none of the sprawl.

---

## Design principles (the spirit)

1. **Lightweight by default.** If a facet doesn't earn its keep every cycle, it doesn't ship. Borrow
   the Core's restraint, not The Forge's ceremony.
2. **Context discipline is a first-class feature, and it is *enforced*, not displayed.** (See below.)
3. **One canonical doc per concept.** No four overlapping "how it works" files, no doc-about-the-docs.
4. **Stable vocabulary.** Names are chosen once and kept. No renaming ADRs, no `_Avoid_:` graveyards.
5. **Build only what's used now.** No instrumentation without a consumer, no crash-recovery substrate
   without a real unattended scenario, no near-twin skills.
6. **Subagents do the heavy reading.** The orchestrator stays lean by delegating fan-out work and
   keeping only distilled conclusions — never transcript dumps.

---

## Non-negotiables (must-haves)

### A. Context-window discipline — *enforced*
- **Warn at 30%** of the context window. Surface it clearly to the user.
- **Hard stop at 40%.** This is a real gate, not a statusline label.
- At the hard stop: **clear context** and **hand off via a continuation** so work resumes cleanly in a
  fresh session.
- Tighter than The Forge's 40%/50% — the whole point is staying *out of the dumb zone*.
- Open question for grill: enforcement mechanism (hook? skill-internal check? statusline + auto-handoff?),
  and what the continuation artifact contains.

### B. GitHub-native task flow
- Use **GitHub Issues + a Kanban (Projects) board** as the real state machine.
- Labels drive transitions (queue → in-progress → review → approved/needs-rework → done), à la The
  Forge but trimmed to the minimum set that works.
- `gh` CLI as the driver.

### C. Ponder → slice → **batch** → human-approved autonomous loop

The loop is **batched and gated**, not a free-running drain of the whole backlog. There are two
distinct moments: (1) slicing work into issues, and (2) a separate, deliberate decision to run a
*batch* of those issues — and the human approval of that batch is what actually starts the autonomy.

**1. Slice into issues (planning).**
- `/ponder` (or equivalent) takes a goal and **slices it into discrete tasks**, each created as a
  **GitHub issue** and placed on the Kanban board.
- Issues that are ready get the **ready-for-agent** label. *Creating/labeling issues does NOT start
  any work* — it just fills the queue.

**2. Run a batch (`/forge`) — the approval gate is the trigger.**
- A **batch** is a deliberately-chosen group of ready issues that belong together (e.g. one phase of a
  larger plan). A `/forge` run ≈ one session working one batch.
- When the user runs `/forge`, it **reads the available ready-for-agent issues, proposes the set it
  intends to work, and lists them out for approval**: "here's the work I plan to do — this, this,
  this… approve?"
- **The user's approval is the moment autonomy begins.** Nothing runs before it.

**3. The autonomous per-issue loop (post-approval, no human needed).**
For each issue in the approved batch, in sequence:
> **do it → review it → if improvements needed, back to forge → fix → review → approve → merge → next**
…continuing through the batch until the **end of queue**, at which point it **reports back** to the user.

**Concrete example (the user's mental model):**
> An idea = 2 phases; each phase has 3 sub-phases; each sub-phase has UI work + logic work.
> Slicing **phase 1** therefore yields **6 issues** (3 sub-phases × {UI, logic}). Once those 6 are
> created, ready, and labeled ready-for-agent, the user runs `/forge`. It lists those 6 as its plan
> and asks for approval. On approval, it works all 6 end-to-end — do → review → fix → review → approve
> → merge → next — then reports back. Phase 2 would be a later, separately-approved batch.

- This batched-with-front-gate model is the capability The Forge *documented but never actually built*
  (its autonomy also stopped at the batch boundary, but it never had the clean "propose batch → approve
  → drain it → report" shape). Evolved must make this the spine.

**Open questions for grill (this area is the least settled — dig hard here):**
- **How are batches defined/assigned?** Does `/forge` auto-propose all ready issues, or does the user
  pre-group them (a board column? a milestone? a label like `batch-1`?)? Is a batch == a phase by
  convention, or an explicit grouping?
- **What does "review" mean with no human in the seat** — self-review by the builder, a cold reviewer
  subagent, confidence thresholds, or layered (self → cold → final)?
- **What stops a runaway loop** (a fix that won't converge)? Max retries → escalate to `needs-human`?
- **How does the loop interact with the 40% hard stop** — continuation handoff *between* issues, mid-issue?
- **Commit/PR strategy per issue** (one PR per issue? merge directly? branch-per-batch?).
- **Pause/intervene** mid-batch.

---

## On the table (decide during grill)

### Knowledge preservation — *iffy, user is neutral*
- The Forge had: `lessons.md` index → `knowledge/<slug>.md`, plus ADRs and a glossary.
- Question: does Evolved want *any* cross-session learning, and if so the lightest form that works?
  Options range from "none (Core-style)" → "a single append-only lessons file" → "the two-tier
  reactive system." Lean light unless grill surfaces a real need.

---

## Anti-goals (lessons from The Forge — do NOT do these)

- ❌ Multiple overlapping documentation systems or a doc explaining which doc to read.
- ❌ Renaming churn; vocabulary-graveyard glossaries.
- ❌ launchd/watchdog/circuit-breaker crash-recovery substrate for a solo tool.
- ❌ Dead-end stub files pointing at things that don't exist.
- ❌ Logging/instrumentation with no consumer.
- ❌ Two mechanisms guarding the same thing.
- ❌ Near-twin skills that cross-reference each other (`/tinker` vs `/prototype`).
- ❌ Display-only "discipline" that doesn't actually gate behavior.

---

## Process for building Evolved

1. ✅ Research the Core and The Forge; produce `findings.md` + this `vision.md`. *(done)*
2. ⏭️ **`/grill-me`** — relentless interview to resolve every open question above and lock the scope.
3. **Per-facet external research** — before building each chosen amenity (context-discipline
   enforcement, GitHub Kanban loop, autonomous review gates, knowledge preservation), look at *how
   others solve it* and adjust the approach to what's available and proven.
4. Plan (`/inscribe`-style) → build the lightweight skeleton (likely starting from a copy of the Core).
5. Dogfood.

---

## Locked decisions (grill session — 2026-05-27)

These are settled. Details/rationale captured here; mechanics to be turned into skills during build.

1. **Artifact model — per-project install.** Each project carries its own copy of the Forge skills/config
   in `.claude/`; the autonomous loop runs against that local repo. "Foundation for all projects" =
   the same methodology installed everywhere, not one central brain. *(Tradeoff parked: knowledge/config
   is duplicated per project — revisit under knowledge preservation + Forge-update propagation.)*

2. **Planning front-end — ponder → confirm → inscribe, one session.**
   - `/ponder` = full grill-me-style session (with research agents as needed) that flushes out and
     refines *what to build*. This is where scope judgment happens. No issues yet.
   - Ponder **ends by proposing the issue breakdown** (titles, scope, UI/logic split, labels) for a
     single one-word confirmation — the gate before any outward GitHub write.
   - `/inscribe` = "the scribe," runs in the **same session** on confirmation. It (a) documents the
     knowledge where it belongs, and (b) creates + triages + labels the GitHub issues `ready-for-agent`.
   - *Parked tension:* a long ponder may leave little context for inscribe — decide under context branch
     whether inscribe can run in a fresh context off a distilled handoff.

3. **Kanban — real GitHub Projects (v2) board, agent-maintained.** The visual command center; the agent
   moves cards as it works. Columns mirror the loop states (finalized after review/runaway questions).

4. **Batch selection — all Ready issues at run time.** A batch = everything labeled `ready-for-agent`
   (the Ready column) when `/forge` runs. Forge lists them for approval; you can trim. No explicit
   grouping mechanism unless a real need appears later (`batch:N` is a future add-only).

5. **Version control — branch + squash-merge PR per issue.** (Informed by research.)
   - `forge/issue-<id>` cut from `main` per issue (`-r2` etc. on retry).
   - Open a PR that auto-links/closes the issue; reviewer reads the diff; squash-merge on approval.
   - **Test suite runs as a gate between merges**; revert the squash commit if tests fail post-merge.
   - Always start each issue from a clean working tree; on repeated failure delete branch + log + skip.
   - Squash chosen for surgical `git revert <sha>` rollback. Worktrees not used (loop is sequential).

6. **Loop architecture — thin orchestrator + fresh subagents per issue.** `/forge` coordinates only
   (batch list + 1-line status per issue). Each issue gets a **fresh builder subagent** (acts — a
   deliberate evolution beyond the Core's "subagents never act") and a **fresh, independent reviewer
   subagent** (clean context, no build bias). Orchestrator context stays ~flat across the batch, making
   the 30%/40% context rule **structural** rather than a constant fight.

7. **Batch autonomy — fully hands-off + escalation.** The only human gate is the batch approval at the
   front of `/forge`. The loop runs every issue to completion; "final approval" is the reviewer
   subagent's automated pass. Safety valve = escalation, never human attention: an issue that can't pass
   is labeled `needs-human`, skipped, and surfaced in the end-of-batch report. Bad code never auto-merges.

8. **Review gate — adversarial, isolated, evidence-based.** (Research-backed.)
   - Reviewer subagent gets **only** the issue's acceptance criteria + the `git diff` — never the
     builder's reasoning. Prompt framing: *"find every way this diff fails the criteria."*
   - **Per-criterion verdict**: cite exact diff line(s), PASS/FAIL + one sentence each; APPROVE only if
     all PASS; a FAIL with no line citation is auto-ignored.
   - **Hard gates run before the AI opinion counts**: tests + type-check + lint must pass. **Builder
     modifying/weakening/deleting test files = automatic FAIL + escalate** (top reward-hacking signal).
   - **Bias toward rejection.** **Max 3 builder→reviewer rounds**, then escalate (no partial merge;
     comment diff + failed criterion on the issue, label `needs-human`). Also escalate if the diff
     exceeds ~2× expected scope or the builder touches test/CI config.
   - **Reviewer uses a different model than the builder** where practical (reduces same-family bias).

9. **Verification posture — per-issue method, rigor by default.** Inscribe tags each issue:
   - **Logic/backend → test-gated**: builder must add tests proving the criteria; tests+types+lint are
     the hard gate before review.
   - **UI/visual → visual check**: reviewer + a lighter objective check (renders / screenshot /
     Playwright), since such work isn't unit-testable.
   - *Implication for inscribe:* issues must carry **machine-checkable acceptance criteria** (where the
     method is test-gated) and a **verification-method tag**.

10. **Context enforcement — hook-enforced real gate.** (Research-backed; CC has no native context-% gate.)
    - The statusline reads live `context_window.used_percentage` and **writes it to a small file each turn**.
    - A **PreToolUse hook reads that file and BLOCKS tool calls at ≥40%** with a "hand off now" instruction
      — a true stop, not The Forge's display-only gauge.
    - Statusline shows a **warn at 30%**; skills **self-check at safe checkpoints and hand off proactively
      ~35%** to avoid being hard-blocked mid-action.
    - Applies across session types; in practice it triggers on the **ponder grill** and **builder subagents**,
      rarely on the thin orchestrator. Prefer deliberate handoff over (lossy) auto-compaction.

11. **Continuation — state-derived + thin run-state file.** The GitHub board + git + issue comments are the
    source of truth. Loop resume = `/clear` then re-run `/forge` (reads board, picks up next issue). A small
    `.claude/forge/loop-state` tracks active batch + in-flight issue + attempt count (interruption-robust).
    **Ponder** is the exception (no external state yet): it writes a **distilled handoff** when it must
    checkpoint, which also lets inscribe run in a fresh context. No per-session history-file sprawl.

12. **Issue overflow — escalate as mis-sliced.** If a builder subagent outgrows its own context on one issue,
    it commits WIP, returns "too large," and the orchestrator labels it `needs-reslice`, skips, and reports.
    Overflow is treated as a slicing failure (preserves "one task = one fresh context"); never chain builders.

13. **Knowledge preservation — lean lessons layer.** A single capped, append-only lessons file of one-line,
    hard-won facts about *this* codebase, fed to fresh builder/reviewer subagents at dispatch (fixes their
    no-memory gap). High bar to add (overcame a real wall). No `knowledge/<slug>.md` tree, no ADRs, no glossary
    gate. Project-local only (cross-project sharing stays parked). Distinct from inscribe's doc-writing.

14. **Naming — forge metaphor retained; knowledge vs run-state split.**
    - Skill vocabulary kept: `ponder / inscribe / forge / temper / seal` (+ utilities, TBD which).
    - **`.knowledge/`** holds the persistent lessons (named for what it is, not a forge-metaphor word).
    - Ephemeral **run-state lives under `.claude/forge/`** (`loop-state`, ponder `handoff`) — kept apart from
      knowledge so the knowledge folder doesn't collect operational lint.

15. **Board taxonomy + mechanism — labels drive state, Actions syncs the board.** (Mechanism revised by research.)
    - **Columns (the visual):** `Backlog → Ready → Forging → In Review → Done`, plus a **`Needs Human`** lane.
    - The agent drives status via **labels** (`status:ready|forging|in-review|done|needs-human`) — one
      `gh issue edit` call, no node IDs, idempotent, queryable. It does **not** call the Projects API directly
      (that path needs 4 cached node IDs and breaks on board recreation).
    - A tiny **`.github/workflows/sync-board.yml`** maps label changes → the board's `Status` field option;
      the board is a **synchronized view**.
    - Attribute labels: `verify:test` / `verify:visual`; escalation *reason* on Needs-Human (`needs-reslice`,
      `review-failed`, …). fix↔review iteration stays internal.
    - **Installer requirements (`light-the-forge`):** a **classic PAT with `project` scope** (fine-grained PATs
      do NOT support Projects v2; Actions `GITHUB_TOKEN` can't touch Projects) — installer checks + guides
      `gh auth refresh -s project`; **one Project per repo**, `gh project link`'d; board + Status field + column
      options are created via `gh project create` / `field-create` (scriptable).

16. **Command surface — three user commands.** `ponder / inscribe / forge`. `temper` (review) and `seal`
    (merge + end-of-batch report) are **named internal stages of the forge loop**, not user commands — so
    nothing manual breaks the hands-off autonomy. Escalations are handled by fixing/re-slicing and dropping
    the issue back into Ready for the next `/forge`.

17. **Skill inventory.**
    - **Phase (user):** `ponder`, `inscribe`, `forge`.
    - **Internal stages / subagents:** temper + seal (inside forge); fresh **builder** and **reviewer** subagents.
    - **Utilities:** `research`, `diagnose`, `scrub` (redefined: reconcile board↔git↔run-state), `sharpen`.
    - **Installer:** `light-the-forge` (renamed from `light-the-core`).
    - **Cut:** `grill-me` standalone (absorbed into ponder), `rollback` (plain `git revert`), `triage`
      (absorbed into inscribe), `prototype`, `tinker`, `examine`, `write-a-skill`.
    - Net: **3 commands + 4 utilities + installer** (vs The Forge's 18).

18. **Batch boundary — stop + report.** `/forge` runs one approved batch to completion, then **stops and
    reports** (merged / escalated / remaining + per-issue context%·review-rounds). No auto-chaining to the
    next batch — a deliberate human inflection point between phases. (Refuses The Forge's unbuilt "Levels 2–4".)

19. **Token/cost observability — lean, in the report.** Each subagent's context%/tokens (already returned to
    the orchestrator) is surfaced in the end-of-batch report (e.g. `#7 RESLICE 41% ctx`). No standalone log
    subsystem — it has a built-in consumer, dodging the "instrumentation before its consumer" trap.

20. **Hooks — only one.** State-derived continuation makes The Forge's `session-start re-injection` and
    `stop-handoff` hooks redundant (continuation = `/clear` → re-run `/forge`, which reads `loop-state`).
    The **only** hook is the **context-enforcement** PreToolUse gate (decision 10). `human-only read guard` cut.

21. **`CONTEXT.md` — kept, lightweight.** Retain the Core's lazy-loaded glossary/orientation doc (part of the
    proven lazy-loading discipline), **without** The Forge's hard-gate term-validation.

22. **Foundation — copy the Core, evolve in place.** Copy `the-forge-core`'s files (**minus `.git`**) into
    `the-forge-evolved` as the skeleton; Evolved starts its own git history. The Core original stays pristine.
    Reuse scaffolding + utility skills; rework `forge` into the autonomous loop; add the hook, board
    integration, subagents, and `.knowledge/`.

23. **`CLAUDE.md` — lean, &lt;100 lines, lazy-load discipline.** (Research-backed.) Only CLAUDE.md loads every
    session, so 50–100 lines max; test each line with *"would Claude fail without this?"*. Push glossary →
    `CONTEXT.md` (lazy), lessons → `.knowledge/` (skill-fed), detail → skills. Imperative voice, one rule/line.
    Avoid `@imports` unless always-needed (they also load at startup). **Two CLAUDE.mds:** the Forge repo's own,
    and the **template** the installer writes into each target project. Includes the refined **Response Style**:
    > - Concise. No preamble, no "I'll now..." narration.
    > - No explanations unless asked. Skip recaps of completed work.
    > - Code only when showing actual code, not summaries.
    > - When a task is done, end. No "let me know if..." closers.
    > - If I flag a mistake, fix it without re-asking or apologizing.

24. **Agents — 3 role-based definitions.** In `.claude/agents/`:
    - **forge-builder** — edit/bash/test tools; fed `.knowledge/lessons.md`; on *retry* rounds, denied write
      access to test files (anti-reward-hacking).
    - **forge-reviewer** — **READ-ONLY tools** (structurally cannot edit/"fix" code to pass), a **different
      model** than the builder, the adversarial per-criterion rubric; adapts to `verify:test` / `verify:visual`.
    - **forge-researcher** — read-only gather/distill; what `ponder` and `/research` fan out to.
    - Role-based, **not** task-based (no UI-builder/logic-builder split) — resist proliferation. This
      *formalizes* the enforcement behind decisions 6 and 8 (tool-scoping = structural, not advisory).

### Parked (explicit future, do NOT solve now)
- **Forge-update propagation** across project installs (per-project copies drift). Revisit only when several
  installs actually need syncing — solving it now is the over-engineering trap that bloated The Forge.
- **Cross-project knowledge sharing** (`.knowledge/` is project-local for now).
- **Resilience substrate** (heartbeat / circuit-breakers / launchd) — only if a real unattended-overnight
  scenario emerges.

## Status

**Design phase: COMPLETE.** 24 decisions locked; every facet The Forge had is accounted for (kept /
absorbed / replaced / cut). All research spikes done: git/PR strategy, autonomous review quality, CC context
enforcement, GitHub Projects v2 automation, CLAUDE.md best practices.
**Next:** write `build-plan.md` (ordered implementation spec) → then build from it.


1. **Foundation:** start Evolved as a verbatim copy of the Core and evolve in place, or build fresh
   with the Core as reference only?
2. **Context enforcement:** what mechanism turns 30%/40% from numbers into actual behavior?
3. **Continuation:** what does the handoff artifact contain, and what triggers it (hard stop vs. per-issue)?
4. **Batch definition:** how is a batch chosen for a `/forge` run — auto-proposed from all ready
   issues, or pre-grouped by the user (board column / milestone / `batch-N` label)? Is a batch a phase
   by convention or an explicit grouping?
5. **Autonomous review:** how do "review → fix → review → approve → merge" gates operate with no human?
   What stops a non-converging fix loop (max retries → `needs-human`)?
6. **GitHub model:** which label set / board columns? One repo or per-project? Issues vs. PRs per task.
7. **Knowledge preservation:** in or out — and if in, the lightest viable form.
8. **Naming:** keep the Core's forge metaphor (`ponder/inscribe/forge/temper/seal`) or rethink?
9. **Scope of "a little more ceremony":** where exactly is the line between Core-minimal and Forge-bloat?

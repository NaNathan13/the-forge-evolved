# The Forge Core — Complete Findings

> Research for The Forge Evolved (2.0). Source: `/Users/nathanwilson/Documents/Nathan/Projects/the-forge-core` (read-only).

---

## 1. Overview & Philosophy

### What It Is

The Forge Core is a **Claude Code workflow installed into any project** — not a separate tool, but a handful of skill files under `.claude/skills/` that drop alongside your code. It provides a disciplined four-phase loop for turning a fuzzy idea into shipped code: **Ponder → Forge → Temper → Seal**.

From `README.md` (line 3):
> "Raw idea in, working code out. Four phases — Ponder → Forge → Temper → Seal — shape it, hammer it, harden it, stamp it."

### The Problem It Solves

Agentic tooling tends toward ceremony: GitHub issues, PRs, orchestration layers, Mission Control files, branch-per-feature. The Core's answer is deliberate subtraction. From `CLAUDE.md` (line 3):
> "No GitHub issues, no PRs, no orchestration. The build runs inline on your branch."

State is reduced to its minimum: `ls .claude/plans/active/` is the entire ledger.

### Design Philosophy — Key Principles

1. **Restraint as a feature.** The system has no runtime, no database, no orchestration layer. "State = `ls .claude/plans/active/`. That's the whole ledger." (`CLAUDE.md` line 19)

2. **The plan file is the only state.** One markdown file per in-flight effort; no issue tracker, no labels, no Mission Control doc.

3. **Nothing auto-chains.** From `how-to-work-in-the-forge.md` (line 31): "Nothing auto-chains — you're always holding the hammer." The user decides when each phase runs.

4. **Subagent doctrine.** The build runs inline, but read-only subagents may gather (research) or judge (cold review) and report back — they never write code or own a phase. Stated explicitly in `CLAUDE.md` (line 3): "read-only subagents may **gather** (research) or **judge** (cold review) and report back, but never write code or own a phase."

5. **Stay scoped.** Build what the slices describe; don't add features or refactor beyond them. This rule appears in every phase skill.

6. **Durability over convenience.** For apps that keep user records, durable server-side storage is non-negotiable — enforced in both `/temper` (persistence test) and `/inscribe` (storage decision required before slicing). `templates/CLAUDE.md` (line 33): "Never lose their data."

7. **Context loads lazily.** CLAUDE.md loads every session; CONTEXT.md is read reactively when a term is unclear; plan files load when a phase runs; skill files load only when their command is invoked. This is explicitly documented in `CLAUDE.md`'s "Context loading" table (lines 43–49).

---

## 2. The Lifecycle / Workflow

### End-to-End Sequence

```
/ponder → /inscribe → /forge → /temper → /seal
  think      write      build    review    finish
```

The Ponder phase is two commands (`/ponder` then `/inscribe`). The other three phases are one command each. Nothing runs automatically between steps.

### Detailed Flow

**1. `/ponder` — think it through**
The user states what they want. Claude grills with one question at a time (each with a recommended answer). If a question can't be settled from the codebase or known facts, `/ponder` leans on `/research`. No code, no files written yet. Ends by saying: "Understanding reached. Run `/inscribe` to write the plan."

**2. `/inscribe` — write the plan**
Records the `ponder` understanding as `.claude/plans/active/<slug>.md` with frontmatter, a progress bar (10-cell `░░░░░░░░░░`), a slice checklist, goal, optional constraints/research, and one `## Slice N:` section per slice. Also requires settling the "Where your data is kept" and "How this app runs" questions before slicing.

**3. `/forge` — build it**
Reads the active plan (most-recently-modified, or named). Works every unchecked slice in order: implements, ticks the box, re-renders the progress bar — immediately after each slice, not in batch. Commits at the end with `feat(<slug>): <plan title>`. No branches, no push.

**4. `/temper` — review and harden**
Checks each done slice against its acceptance notes. Fixes small issues inline. Un-ticks any slice that doesn't meet its intent, adding `> needs rework: <what's wrong>`. Optionally (`/temper cold`) dispatches one fresh-context read-only subagent to review the diff before triaging. Commits fixes. If any slice was sent back, the loop returns to `/forge`.

**5. `/seal` — finish**
Confirms every slice is `[x]` and bar reads `N/N`. Flips frontmatter to `status: done`. Runs `git mv .claude/plans/active/<slug>.md .claude/plans/done/<slug>.md`. Makes final commit `chore(<slug>): seal plan`. No push.

### light-the-core.sh Walk-Through

The installer script (`light-the-core.sh`) does the following, in order:

1. **Self-bootstraps if needed.** When piped via `curl | bash`, it clones the repo to a temp dir first (`git clone --depth 1`). This keeps installation to a single command with no pre-clone required.
2. **Resolves target directory.** Defaults to `$(pwd)` or accepts an argument.
3. **Preflight checks.** Refuses if source equals target; refuses if target already has `.claude/plans/` (prevents re-install).
4. **Copies skills.** `cp -R "$SRC/.claude/skills/." "$TARGET/.claude/skills/"` — all skill directories in one pass.
5. **Scaffolds plan dirs.** Creates `.claude/plans/active/` and `.claude/plans/done/`, copies any `README.md` files from source, writes `.gitkeep` in both to preserve empty dirs in git.
6. **Copies settings.json** — only if the target does not already have one.
7. **Copies root templates** (`CLAUDE.md`, `CONTEXT.md`, `README.md`) — only if the file does not already exist in the target. Never clobbers existing docs.
8. **Prints summary** and instructs: "Next: open this project in Claude Code and run /ponder".

The "never clobber" policy for docs (both settings.json and root templates) is a key design choice — the installer is safe to run on an existing project without destroying existing context.

---

## 3. Facet Inventory

### Core Phase Skills (the five workflow commands)

---

#### `/ponder`
- **File:** `.claude/skills/ponder/SKILL.md`
- **Trigger:** `/ponder`, starting new work from a rough idea
- **One-line purpose:** Turn a fuzzy idea into shared understanding before any code or plan file is written
- **What it does:**
  1. Understands the idea (scope, shape of "done", any ambiguity)
  2. Classifies storage and sharing needs (durable server-side vs. none; single-user vs. shared) — these architectural calls are Claude's to make, not the user's
  3. Grills with `grill-me` (one question at a time, each with a recommended answer)
  4. Leans on `research` on demand when grill hits an unknown the codebase can't settle
  5. Settles the rough slice shape
  6. Hands off: "Understanding reached. Run `/inscribe` to write the plan."
- **Inputs:** User's rough idea (anything from a sentence to a paragraph)
- **Outputs:** Shared understanding in-conversation; no files written
- **Notable design choices:** No plan file written here (that's `/inscribe`'s job). One idea per ponder — if two unrelated efforts surface, that's two plans. Architectural decisions (storage, sharing) are explicitly Claude's responsibility.

---

#### `/inscribe`
- **File:** `.claude/skills/inscribe/SKILL.md`
- **Trigger:** `/inscribe`, "write the plan", "write it up"
- **One-line purpose:** Record the `/ponder` understanding as a single sliced plan file
- **What it does:**
  1. Picks a kebab-case slug; refuses if `active/<slug>.md` already exists
  2. Slices the work into a handful of coherent, ordered chunks
  3. Writes `.claude/plans/active/<slug>.md` with exact template structure (frontmatter, progress bar at `░░░░░░░░░░ 0/N`, checklist, Goal, optional Constraints, optional Research, "Where your data is kept", "How this app runs", then one `## Slice N:` section per slice)
  4. Hands off: "Plan written to `.claude/plans/active/<slug>.md`. Run `/forge` to build it."
- **Inputs:** Understanding from `/ponder` session
- **Outputs:** One new file at `.claude/plans/active/<slug>.md`
- **Notable design choices:** Research section is explicitly optional — "Omit the whole section when no research fired." Storage decision must be recorded in plain words before slicing. Checklist titles and `## Slice N:` section titles must stay in sync.

---

#### `/forge`
- **File:** `.claude/skills/forge/SKILL.md`
- **Trigger:** `/forge` (or `/forge <slug>`)
- **One-line purpose:** Build the entire plan inline, ticking off slices as each completes
- **What it does:**
  1. Picks the plan (most-recently-modified active plan, or named)
  2. Reads goal, constraints, and all slices
  3. For every unchecked slice: implements per its `## Slice N:` section, immediately ticks the box and re-renders the progress bar in the plan file (not in batch at the end)
  4. If a slice is blocked: leaves unchecked, adds `> blocked: <why>`, moves on (or stops if later slices depend on it)
  5. Commits: `git add -A && git commit -m "feat(<slug>): <plan title>"`
  6. Hands off: "Built <done>/<total> slices of `<slug>`. Run `/temper` to review."
- **Inputs:** Active plan file
- **Outputs:** Implemented code + updated plan file (ticked boxes + re-rendered bar) + commit
- **Notable design choices:** "Tick as you go" — the progress block is updated after each slice, not at the end. Whole plan in one pass. No subagents. `git add -A` (all changes).

---

#### `/temper`
- **File:** `.claude/skills/temper/SKILL.md`
- **Trigger:** `/temper` (warm), `/temper cold` (warm + cold subagent review)
- **One-line purpose:** Review and harden the build; send weak slices back
- **What it does:**
  1. Picks the plan
  2. Reviews the diff (`git show --stat HEAD`)
  3. (If `cold`): dispatches one read-only fresh-context subagent with the plan file + diff; it checks each slice against acceptance notes, returns a findings list — never edits, ticks, or un-ticks anything
  4. Checks each done slice: does it satisfy acceptance notes? Is it correct, safe, clean?
  5. For record-keeping apps: proves persistence by starting the app, adding a record, stopping and restarting, confirming the record survived — failure = automatic un-tick
  6. Hardens inline (small corrections, missing checks, tests worth adding)
  7. Un-ticks and annotates anything that doesn't meet its intent: `> needs rework: <what's wrong>`
  8. Commits fixes: `fix(<slug>): temper review`
  9. Hands off: "Reviewed `<slug>`: N slices solid, M sent back for rework."
- **Inputs:** Active plan file + committed build
- **Outputs:** Updated plan (possibly un-ticked slices + re-rendered bar) + commit of inline fixes
- **Notable design choices:** Warm is the default (no friction). `cold` is explicit opt-in — "typing `cold` is the consent." Persistence test is mandatory for record-keeping apps. Cold reviewer is strictly read-only; all ticks and fixes stay in the inline session.

---

#### `/seal`
- **File:** `.claude/skills/seal/SKILL.md`
- **Trigger:** `/seal` (or `/seal <slug>`)
- **One-line purpose:** Confirm the plan is done and archive it
- **What it does:**
  1. Picks the plan
  2. Confirms all slices are `[x]` and bar reads `N/N`; if not, asks the user to confirm or run `/forge` first
  3. For record-keeping apps: confirms `/temper` verified persistence before sealing
  4. Flips frontmatter: `status: active` → `status: done`
  5. Moves: `git mv .claude/plans/active/<slug>.md .claude/plans/done/<slug>.md`
  6. Final commit: `chore(<slug>): seal plan`
  7. Done: "Sealed `<slug>` — archived to `.claude/plans/done/`. N slices shipped."
- **Inputs:** Active plan file with all slices checked
- **Outputs:** Plan moved to `done/` + final commit
- **Notable design choices:** Move, don't copy — `active/` stays a clean ledger. No auto-push. One plan per `/seal`.

---

### Utility Skills (reachable anytime)

---

#### `/research`
- **File:** `.claude/skills/research/SKILL.md`
- **Trigger:** `/research`, "research this", "go find out", "look into", "go deep on"
- **One-line purpose:** Gather information a question can't answer from what's already known
- **What it does:**
  - **Light (default):** Read the codebase first; targeted web lookup if needed. Emits `researching: <question>`. Fast, inline, no confirmation.
  - **Deep (opt-in):** Decomposes the unknown into sub-questions, fans out parallel subagents across sources, cross-checks and synthesises. Emits `deep-researching: <question>`. Requires confirmation first: "This needs deep research — ~N parallel agents, a few minutes. Go?"
- **Inputs:** A question that can't be settled from the codebase or known facts
- **Outputs:** Findings reported back to the caller (key facts + source links, distilled) — nothing written
- **Notable design choices:** Read-only always. "Report, don't store" — findings go back to the caller; `/inscribe` decides what to record. Light just runs; deep confirms first. Standalone-usable, not only from `/ponder`.

---

#### `/diagnose`
- **File:** `.claude/skills/diagnose/SKILL.md`
- **Trigger:** `/diagnose`, "debug this", "diagnose this", bug reports, performance regressions
- **One-line purpose:** Disciplined six-phase debugging loop for hard bugs
- **What it does:** Six phases — (1) Build a feedback loop, (2) Reproduce, (3) Hypothesise (3–5 ranked falsifiable hypotheses), (4) Instrument (one variable at a time), (5) Fix + regression test, (6) Cleanup + post-mortem.
- **Inputs:** Bug description or reproduction steps
- **Outputs:** Fixed code + regression test + commit
- **Notable design choices:** Phase 1 ("Build a feedback loop") is described as "the skill" — everything else is mechanical. Debug markers are tagged `[DEBUG-<id>]` for easy grep-cleanup. Shows ranked hypotheses to the user before testing (cheap checkpoint). Regression test written before the fix (but only when a correct seam exists). References sealed plans (`.claude/plans/done/`) and `CONTEXT.md` for architectural context — not ADRs (those don't exist in the Core).

---

#### `/scrub`
- **File:** `.claude/skills/scrub/SKILL.md`
- **Trigger:** `/scrub`, after a forge/temper cycle, when things feel cluttered
- **One-line purpose:** Tidy up plan-state drift and sweep known cruft
- **What it does:**
  1. Checks `active/*.md` for: done-but-unsealed plans, stale progress bars (re-renders automatically), checklist↔slice mismatches, frontmatter-vs-location mismatches, empty plans
  2. Greps for `[DEBUG-` markers (reports hits, doesn't delete)
  3. Reports dirty working tree (uncommitted paths)
  4. Removes known-safe junk: `.DS_Store`, `*.swp`, `*~` — only if not tracked by git
- **Inputs:** Working tree + plan files
- **Outputs:** Report + safe inline fixes (re-rendered bars, junk files deleted) + flags for anything that would move or remove work
- **Notable design choices:** "Core keeps almost no runtime state, so there's little to scrub by design." Safe-fix vs. flag distinction is strict: never auto-seals, never auto-commits, never deletes plan files. Leaves `.gitkeep` alone.

---

#### `/sharpen`
- **File:** `.claude/skills/sharpen/SKILL.md`
- **Trigger:** `/sharpen`, "write me a prompt", "sharpen", "what should I tell Claude next", "write a continuation prompt"
- **One-line purpose:** Turn a rough idea into a precise, paste-ready prompt
- **What it does:**
  1. Extracts raw intent (what, why, success criteria) — max 3 clarifying questions
  2. Builds a prompt with required fields (Task, Context) and optional fields (Constraints, Output) only when they'd change output
  3. Tightens: cuts filler, uses examples over rules, positive over negative, links instead of inlining
  4. Adapts to destination (new session, continuation, subagent, skill invocation)
  5. Presents in a fenced code block with "Ready to use, or want to adjust?"
- **Inputs:** Rough idea or intent
- **Outputs:** A drafted prompt ready to paste
- **Notable design choices:** "Every token must earn its place." Does not execute the task — only produces the prompt. Anti-pattern explicitly stated: don't over-engineer simple prompts.

---

#### `/grill-me`
- **File:** `.claude/skills/grill-me/SKILL.md`
- **Trigger:** `/grill-me`, "stress-test this", "grill me" (also leaned on by `/ponder`)
- **One-line purpose:** Relentlessly interview until shared understanding with no unresolved branches
- **What it does:** Walks the design decision tree, one question at a time, each with a recommended answer. Uses `AskUserQuestion` for small option sets; prose for open-ended questions. Resolves forks before moving to the next question. Optionally jots newly defined/contradicted terms into `CONTEXT.md` with a `noted:` transcript signal.
- **Inputs:** Idea, plan, or design to stress-test
- **Outputs:** Resolved understanding; optional `CONTEXT.md` updates
- **Notable design choices:** "Resolve forks before moving on" — goal is a design with no unresolved branches, suitable for `/inscribe` to write down without guessing. The `CONTEXT.md` update is cosmetic-variation-resistant: only fires when a term was "genuinely defined or contradicted."

---

#### `/light-the-core`
- **File:** `.claude/skills/light-the-core/SKILL.md`
- **Trigger:** "install core into this project", "light the core", `/light-the-core`
- **One-line purpose:** Bootstrap a fresh project with The Forge Core from inside Claude Code
- **What it does:** Thin wrapper around `light-the-core.sh`. Confirms target, runs the installer, then asks three setup questions (project name, one-liner, tech stack) and fills placeholder markers in the installed `CLAUDE.md`, `CONTEXT.md`, and `README.md`.
- **Inputs:** Target directory (defaults to `cwd`)
- **Outputs:** Installed skills/plans/settings + filled-in docs
- **Notable design choices:** Anti-patterns are explicit: don't inline the file-copy logic (that's the shell script's job), keep Q&A to exactly three questions, never overwrite existing docs, never `git init` or create a GitHub repo.

---

## 4. Templates

The `templates/` directory contains three starter files that `light-the-core.sh` copies into the target project root (only if those files don't already exist):

### `templates/CLAUDE.md`
The primary context file loaded every Claude Code session. Contains:
- Placeholder for project name and one-line description
- Tech stack table (`Language/runtime`, `Framework`, `Test runner`, `Check command`)
- "How work flows here" — a concise summary of the four-phase loop and state model, including the subagent doctrine
- Rules: work in place, plan file is the only state, stay in scope, one placeholder for project-specific rules
- "Building apps people will rely on" — a substantial **build doctrine** (lines 29–41) covering:
  - Durable server-side storage is required for user data; browser storage is throwaway only
  - Default stack: tiny built-in Node server + JSON file; SQLite when data is relational/large
  - Static page only for compute-only tools (no server)
  - One process, one port, `npm start`, `process.env.PORT`
  - Local vs. shared deployment patterns
- Links to `CONTEXT.md` and plan directories

### `templates/CONTEXT.md`
The glossary file. Contains:
- Instruction: "Add a term when you find yourself disambiguating it in conversation"
- Pre-seeded `## Workflow terms` section defining all five phase concepts (Ponder, Inscribe, Forge, Temper, Seal) plus Plan and Slice
- Empty `## Language` section for project-specific terms

### `templates/README.md`
Human-facing project README. Contains:
- Placeholder for project name and one-line description
- "How this project is built" — brief mention of the four-phase workflow and where plans live
- "Where things live" — quick map: CLAUDE.md, CONTEXT.md, plans directories, skills directory
- Link to `how-to-work-in-the-forge.md` for full walkthrough

**Template design philosophy:** Templates are intentionally **neutral** — they install into a stranger's repo and should be professional without carrying the Forge's branded voice. Placeholders are used for project-specific content; the build doctrine is pre-filled because it applies universally.

---

## 5. Plans System

### Structure

```
.claude/plans/
├── README.md          — permanent documentation of the contract
├── active/
│   ├── .gitkeep       — preserves empty dir in git
│   └── <slug>.md      — in-flight plans
└── done/
    ├── .gitkeep
    └── <slug>.md      — sealed plans (permanent record)
```

### Plan File Shape (from `.claude/plans/README.md`)

```markdown
---
name: <slug>
created: <YYYY-MM-DD>
status: active | done
---

# <Title>

## Progress
`░░░░░░░░░░` 0/N
- [ ] 1. <slice 1 title>
...

## Goal
## Constraints / out of scope  (optional)
## Research                     (optional — only if /ponder did research)
## Where your data is kept
## How this app runs

---

## Slice 1: <title>
## Slice 2: <title>
...
```

### Progress Bar Mechanics

- 10 cells: `█` = done, `░` = not done
- Filled cells = `round(done / total × 10)`
- `/forge` renders after each slice tick
- `/temper` re-renders when un-ticking
- `/seal` requires bar to read `N/N`

### Who Writes What

| Command | Action |
|---|---|
| `/inscribe` | Creates `active/<slug>.md`, all slices unchecked, bar at `0/N` |
| `/forge` | Ticks slices, re-renders bar |
| `/temper` | Un-ticks + annotates slices needing rework, re-renders bar |
| `/seal` | Flips `status: done`, moves to `done/` |

### The "plans README is permanent" rule

`.claude/plans/README.md` documents the contract and must not be deleted — a stated invariant from the plans README itself.

### Slugs

Kebab-case derived from the plan title (`auth-flow`, `dark-mode`, `csv-export`). `/inscribe` refuses if the slug already exists.

---

## 6. Context Discipline Mechanisms

This is a critical area. The Forge Core manages context through **structural laziness** rather than explicit token-counting:

### Layered / Lazy Loading (CLAUDE.md lines 43–49)

| Layer | Source | When |
|---|---|---|
| Always | `CLAUDE.md` | session start |
| Glossary | `CONTEXT.md` | reactively when a term is unclear |
| Plans | `.claude/plans/active/*.md` | when a phase runs |
| Skill | `.claude/skills/<name>/SKILL.md` | when its `/command` is invoked |

This means: only `CLAUDE.md` is guaranteed in context. Everything else loads on demand.

### No Continuation Files

From `/scrub` SKILL.md: "Core keeps almost no runtime state, so there's little to scrub by design — no worktrees, no continuation files, no token logs."

### Read-Only Subagents (Context Isolation)

The `/research` skill's deep mode and `/temper cold` both dispatch subagents with **fresh context** — specifically to avoid context contamination from the build session. From `temper/SKILL.md`: "dispatch one read-only subagent with fresh context — none of this session's build assumptions."

### Confirm Before Deep Research

From `research/SKILL.md`: "Light just runs; deep does not. First pause and ask... 'This needs deep research — ~N parallel agents, a few minutes. Go?'" — this is explicitly a cost-and-time gate, not just a UX choice.

### Progress Bar as Resumability

The tick-as-you-go rule in `/forge` means a session can be interrupted and resumed cleanly: the plan file always reflects what's actually done, so a new session can pick up mid-plan without any conversation history.

### No Transcript Dumps

From `research/SKILL.md` Rules: "Hand findings back to the caller — key facts and source links, distilled, not a transcript dump." `/inscribe`'s Research section is explicitly described as "distilled, not a transcript dump." This prevents research from bloating either the plan file or a subsequent session's context.

### One Plan Per Session (guideline, not enforcement)

From `how-to-work-in-the-forge.md` (line 58): "One plan at a time is simplest." Multiple active plans are permitted but not encouraged.

### Implicit Context Reset via `/sharpen`

The `/sharpen` skill's adaptation for continuations explicitly advises: "Include what was done, what's left, key file paths, decisions made. Link to artifacts rather than inlining everything." This is the pattern for starting a fresh session with minimal but sufficient context.

---

## 7. Subagent Doctrine

Source: `.claude/plans/done/subagent-doctrine.md`

### The Doctrine Line

From `subagent-doctrine.md` (Goal section):
> "The build runs inline, on your branch — but read-only subagents may **gather** (research) or **judge** (cold review) and report findings back to the inline session. Subagents never write code, never own a phase. The work stays in your hands; only context-gathering and second opinions may fan out."

### Why It Was Settled

The doctrine emerged because the blanket "no subagents" claim became false once `/research` (with its deep fan-out) was added. Rather than removing the capability, the team settled a principled rule that makes the boundary clear.

### Two Allowed Subagent Roles

1. **Gather (research):** The `/research` skill's deep mode fans out parallel subagents across sources to answer a question. Read-only.
2. **Judge (cold review):** `/temper cold` dispatches one fresh-context subagent to review the build diff against the plan. Read-only.

### What Subagents May Not Do

- Write code
- Edit files
- Tick or un-tick progress boxes
- Own a phase
- Make decisions that stick

### Inline Session Owns All Changes

All edits, ticks, un-ticks, and commits stay in the inline session. Subagent findings are **inputs to the inline session's judgment**, not decisions in themselves.

### Constraints From the Doctrine Plan

- Read-only is the whole point
- Warm `/temper` stays the default; `cold` is deliberate opt-in with no friction on the common path
- No new state, no new files — doctrine lives in existing skill and doc files
- `forge`, `seal`, and `scrub` remain "no subagents" because they run inline; their existing rules stay accurate

---

## 8. What Makes the Core "the Core"

These are the essential, irreducible elements — the things that, if removed, would make it something else:

### The Four Phases (Ponder → Forge → Temper → Seal)

The four phases are the backbone. They enforce a separation of concerns: thinking is separate from planning is separate from building is separate from reviewing is separate from closing. Each phase has one job.

### Plan File as Sole State

One markdown file per effort, under `.claude/plans/active/`. No issue tracker, no Mission Control doc, no labels, no GitHub. This is the design constraint everything else flows from.

### Inline Build on Current Branch

The build session is the author. No branch-per-feature, no worktrees, no GitHub coupling. Commits happen at phase boundaries on whatever branch the user is on.

### Progress Bar + Tick-as-You-Go

The 10-cell bar that updates immediately after each slice gives the plan file resumability: it's always accurate enough to hand to a fresh session.

### Nothing Auto-Chains

The user triggers each phase manually. This is both a design choice (human oversight) and a practical constraint (no orchestration layer to maintain).

### Subagent Boundary (Read-Only Only)

Subagents may gather and judge; they never act. The inline session holds all agency.

### Build Doctrine (Templates CLAUDE.md)

The "Building apps people will rely on" section of `templates/CLAUDE.md` is a durable fixture — it encodes concrete defaults (server + JSON file, one process one port, never browser storage for user data) that prevent a whole class of naive mistakes. This doctrine is not optional or configurable; it's installed into every project.

### The Installer's Non-Destructive Policy

`light-the-core.sh` never overwrites existing docs. This makes the installer safe to run in any project state.

### Laziness of Context Loading

Only `CLAUDE.md` loads every session. Everything else loads reactively. This is not just a convention — it's the documented contract in `CLAUDE.md`'s context loading table.

---

## Appendix: File Map

| Path | Purpose |
|---|---|
| `CLAUDE.md` | Project context — the four phases, rules, context loading table |
| `CONTEXT.md` | Glossary — all terms pinned once |
| `README.md` | Human-facing intro + install instructions |
| `how-to-work-in-the-forge.md` | Onboarding guide — five-minute read |
| `light-the-core.sh` | One-step installer (curl-pipeable) |
| `.gitignore` | Only `.claude/settings.local.json` and `.DS_Store` |
| `.claude/settings.json` | Allowlist: git read commands, ls, cat, head, tail, wc, find, grep, rg, bash -n, mkdir, touch |
| `.claude/plans/README.md` | Plan contract documentation (permanent) |
| `.claude/plans/done/ponder-research.md` | Shipped plan: added /research sub-skill to ponder |
| `.claude/plans/done/docs-voice.md` | Shipped plan: gave docs the voice of a forge |
| `.claude/plans/done/subagent-doctrine.md` | Shipped plan: settled subagent doctrine + added cold temper |
| `.claude/skills/ponder/SKILL.md` | Phase 1: think the work through |
| `.claude/skills/inscribe/SKILL.md` | Phase 1b: write the sliced plan |
| `.claude/skills/forge/SKILL.md` | Phase 2: build the plan |
| `.claude/skills/temper/SKILL.md` | Phase 3: review and harden |
| `.claude/skills/seal/SKILL.md` | Phase 4: finish and archive |
| `.claude/skills/research/SKILL.md` | Utility: gather information (light/deep) |
| `.claude/skills/diagnose/SKILL.md` | Utility: disciplined debugging loop |
| `.claude/skills/scrub/SKILL.md` | Utility: tidy plan state and sweep cruft |
| `.claude/skills/sharpen/SKILL.md` | Utility: turn rough idea into precise prompt |
| `.claude/skills/grill-me/SKILL.md` | Utility: relentless one-at-a-time grilling |
| `.claude/skills/light-the-core/SKILL.md` | Utility: bootstrap installer from inside Claude |
| `templates/CLAUDE.md` | Starter CLAUDE.md for installed projects |
| `templates/CONTEXT.md` | Starter CONTEXT.md with pre-seeded workflow terms |
| `templates/README.md` | Starter README.md (neutral, human-facing) |

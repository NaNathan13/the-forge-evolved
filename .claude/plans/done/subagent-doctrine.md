---
name: subagent-doctrine
created: 2026-05-23
status: done
---

# Settle the subagent doctrine + add cold temper

## Progress
`██████████` 3/3
- [x] 1. Write the subagent doctrine into the docs
- [x] 2. Add `cold` mode to `/temper`
- [x] 3. Fix the dangling ADR reference in `/diagnose`

## Goal
The core's doctrine says "no subagents / no orchestration" in several places — but the `/research` skill we just shipped fans out parallel subagents for deep research, so the blanket rule is already false. Settle it with one principled line and make the docs honest, then cash in the decision by adding an opt-in fresh-eyes review.

**The doctrine (the line everything follows from):** *the build runs inline, on your branch — but read-only subagents may **gather** (research) or **judge** (cold review) and report findings back to the inline session.* Subagents never write code, never own a phase. The work stays in your hands; only context-gathering and second opinions may fan out.

On top of that: a **cold `/temper`**. Plain `/temper` stays warm and inline (the default). `/temper cold` dispatches one fresh-context subagent to review the build against the plan with none of the build session's assumptions, returns findings, and the inline `/temper` triages them exactly as it does today.

And a loose end: `/diagnose` tells you to "check ADRs" and "capture in an ADR," but the core has no decisions convention. Repoint it at what the core actually has — sealed plans and `CONTEXT.md`.

**Done looks like:** the doctrine reads true everywhere (no claim the core contradicts); `/temper cold` works as a read-only fresh-eyes pass that feeds the inline review; `/diagnose` no longer points at a convention that doesn't exist. All slim — the core stays the core.

## Constraints / out of scope
- **Read-only is the whole point.** The cold reviewer gathers and judges; it must not edit code or tick/un-tick anything. The inline `/temper` owns all changes.
- **Warm stays the default.** Don't add friction to plain `/temper` — `cold` is a deliberate opt-in, no prompt on the common path.
- **No new state, no new files.** Doctrine + skill edits only. No decisions log, no ADR directory (that fork was explicitly declined).
- **Don't over-edit the phase skills.** `forge`/`seal`/`scrub` run inline and their "no subagents" lines stay true — leave them. Only `temper` gains a subagent path.
- **Separate from** the planned `/status` and `/sync-core` efforts — don't touch those here.

## Where your data is kept
Nothing is saved — no runtime, no datastore. The only state is the plan files under `.claude/plans/`, unchanged by this work. These edits are to markdown skill and doc files.

## How this app runs
There's nothing to run. The deliverables are edited markdown files. No check command applies (no shell scripts are touched).

---

## Slice 1: Write the subagent doctrine into the docs
State the line once, then make every doc consistent with it.

- **`CLAUDE.md`** (repo) — replace the blanket "no subagents" in the opening with the carve-out: the build runs inline; read-only subagents may gather (research) or review (cold temper) and report back. Keep it to a sentence or two — this file loads every session.
- **`templates/CLAUDE.md`** — same fix to its "no subagents" line (line ~20), kept neutral for installed projects.
- **`README.md`** / **`CONTEXT.md`** — light touch only if they overclaim. (The current README says "no orchestration" and "your own session swinging the hammer," which is still true — likely no change. `CONTEXT.md` glossary entries that say "no subagents" for Forge/Seal stay accurate.)
- **Verify, don't churn:** confirm `forge`, `seal`, and `scrub` still read true (they run inline — their "no subagents" lines stay). Only `temper` changes, and that's Slice 2.

Acceptance: the doctrine is stated in one clear place; no doc claims "no subagents" as an absolute the core contradicts; `forge`/`seal`/`scrub` left intact and still accurate.

## Slice 2: Add `cold` mode to `/temper`
Teach `/temper` one new word without disturbing the warm path.

- **Argument:** `/temper` (or `/temper <slug>`) = warm, inline, today's behavior. `/temper cold` (optionally `/temper cold <slug>`) = warm review PLUS a fresh-eyes pass.
- **The cold pass:** dispatch **one** subagent with fresh context. Give it the plan file and the build diff (`git show`/`git diff` against the pre-build commit) and ask it to check each done slice against its acceptance notes — correctness, missed edge cases, risky shortcuts — and return a findings list. It is **read-only**: it does not edit, fix, tick, or un-tick.
- **Triage stays inline:** the inline `/temper` takes the findings and does what it always does — fix the small stuff inline, un-tick what needs real rework with a `> needs rework:` note. The cold pass *feeds* the existing review steps; it doesn't replace them.
- **No double-confirm:** typing `cold` is the consent (unlike deep research, which confirms because it's not explicitly requested).
- **Fix the wording:** update temper's "Inline — no subagents" line so it's true — warm is inline; cold dispatches one read-only reviewer.

Acceptance: plain `/temper` is unchanged and still the default; `/temper cold` runs a single fresh-context read-only review whose findings flow into the normal inline triage; temper's own description no longer claims it never uses subagents.

## Slice 3: Fix the dangling ADR reference in `/diagnose`
Point `/diagnose` at conventions the core actually has.

- "...check ADRs in the area you're touching" (line ~10) → check the relevant **sealed plans** (`.claude/plans/done/`) and `CONTEXT.md`.
- "...capture the recommendation in a follow-up issue or ADR" (line ~117) → note it in the plan (e.g. its constraints) or a follow-up.
- Leave the rest of `/diagnose` alone — only the two phrases that reference a non-existent convention change.

Acceptance: `/diagnose` no longer references ADRs or issues; its pointers resolve to real core artifacts (sealed plans, `CONTEXT.md`, the plan file).

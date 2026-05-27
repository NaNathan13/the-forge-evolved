---
name: docs-voice
created: 2026-05-23
status: done
---

# Give the docs the voice of a forge

## Progress
`██████████` 5/5
- [x] 1. Rewrite `README.md`
- [x] 2. Voice pass on `how-to-work-in-the-forge.md`
- [x] 3. Sharpen the Forge's own reference (`CONTEXT.md`, `CLAUDE.md`, `.claude/plans/README.md`)
- [x] 4. Light touch on the 11 skill intros
- [x] 5. Neutral pass on the templates

## Goal
The docs read soft — "a calm, four-phase way to build things" is meditation-app copy for something called **The Forge**. Rewrite the human-facing documentation so the tone matches the name: muscular, terse, confident, with the forge metaphor threaded through. No facts change — every structural detail (the loop, the state model, install steps, the plan-file shape) survives intact. Only the voice, and a couple of stale examples, change.

**The voice (the spec for every edit):**
- A blend of **forge-craft** and **sharp / no-fluff**: strong verbs, forge imagery, short lines that land.
- **Zero poetry.** Clarity always wins over a clever line. A reader learns *more*, not less.
- A light **"no ceremony"** edge is on-brand (it positions against bloated agentic tooling) — used sparingly.
- **Metaphor is threaded, not themed:** it lives in intros and phase descriptions, never in section headings (no "At the anvil").
- **Length holds:** one screen each. Better words, not more of them.

**Done looks like:** README, the guide, and the Forge's own reference docs read like The Forge wrote them; skill intros lose their soft openings without touching functional content; templates stay neutral (they become a stranger's project docs) but stop being limp; the `.claude/plans/README.md` example matches what `/inscribe` actually writes today.

## Constraints / out of scope
- **No behavior changes.** This is voice and a few stale-example fixes only — no skill logic, no workflow mechanics, no `light-the-core.sh` install logic.
- **Facts are sacred.** Keep every loop step, command, path, and rule accurate. Voice serves clarity, never replaces it.
- **Templates stay neutral.** They install into other people's repos; give them a light workflow hint, not the full Forge swagger.
- **Skill bodies stay as-is.** Only the soft one-line intros / handoff lines get sharpened — functional instructions are untouched.
- **Separate from `ponder-research`** (still tempered-but-unsealed). Don't touch that plan's work.

## Where your data is kept
Nothing is saved — this workflow has no runtime and no datastore. The only state is the plan files under `.claude/plans/`, unchanged by this work. These edits are to markdown docs and one shell-script comment.

## How this app runs
There's nothing to run. The deliverables are edited markdown files (plus possibly a comment in `light-the-core.sh`). The check is `bash -n light-the-core.sh` if that file is touched.

---

## Slice 1: Rewrite `README.md`
The main event — this sets the reference voice every other slice matches.

- Full rewrite in the agreed voice. Open strong (raw idea in, working code out — not "a calm way to build things").
- Keep all structural content the current README carries: the **loop** (Ponder → Forge → Temper → Seal, with the two-command Ponder phase), the **state model** (`ls .claude/plans/active/` is the ledger), the **install** one-liner, **tech stack** notes, **key terms** pointer, and the "edit here when…" / where-things-live guidance — whatever the file currently documents stays documented.
- Keep the `/research` mention already added to the utilities (don't regress recent work).
- One screen. Threaded metaphor, no themed headings.

Acceptance: README opens with force, reads in the new voice, and a newcomer still learns the loop, the state model, and how to install — nothing factual lost.

## Slice 2: Voice pass on `how-to-work-in-the-forge.md`
The five-minute onboarding read — same energy as the README, same information.

- Rewrite prose in the new voice while preserving every step: the "workflow lives inside your project" idea + the dir tree, one-time setup, the five-command loop walkthrough, the utilities list (incl. `/research`), and the house rules.
- Keep it genuinely a five-minute read — tighten, don't pad.

Acceptance: the guide carries the voice, still walks a beginner from install through `/seal`, and every command + rule remains present and correct.

## Slice 3: Sharpen the Forge's own reference (`CONTEXT.md`, `CLAUDE.md`, `.claude/plans/README.md`)
Reference docs — precision first, voice in the framing.

- **`CONTEXT.md`** — give the intro line a touch of voice; leave the glossary *entries* precise and factual (definitions don't get cute). Keep the `Research` term and synced entries from recent work.
- **`CLAUDE.md`** (this repo's project instructions) — sharpen the limp opening sentence; it's read every session, so keep it functional and short. Don't disturb the build doctrine or rules.
- **`.claude/plans/README.md`** — sharpen tone lightly, AND fix the **stale example**: its plan-file shape predates current `/inscribe` output. Add the `## Research` (optional), `## Where your data is kept`, and `## How this app runs` sections so the example matches what `/inscribe` writes today.

Acceptance: the three reference docs read less soft; glossary stays precise; `CLAUDE.md` rules intact; the `.claude/plans/README.md` example mirrors the real `/inscribe` template.

## Slice 4: Light touch on the 11 skill intros
`.claude/skills/*/SKILL.md` — surgical, not a rewrite.

- For each skill, sharpen only a soft one-line **phase intro** (e.g. "/forge is the build phase…") or a limp **handoff line** where it reads flat. Match the voice without changing meaning.
- **Do not touch functional content** — steps, rules, code blocks, frontmatter `description:` triggers all stay exactly as they are.
- If a skill's intro already reads sharp, leave it alone. This is consistency, not churn.

Acceptance: skill openings feel of-a-piece with the new voice; every behavioral instruction, rule, and trigger is byte-for-byte preserved except the deliberately-sharpened intro/handoff lines.

## Slice 5: Neutral pass on the templates
`templates/` install into a stranger's repo — keep them professional, just not soft.

- **`templates/README.md`** — replace the limp "a calm, four-phase Claude Code workflow" line with a crisp, neutral description. No forge swagger (it's their project, not ours).
- **`templates/CONTEXT.md`** and **`templates/CLAUDE.md`** — light pass: tighten any soft phrasing, keep them neutral starter docs. Preserve placeholders, the pre-seeded glossary, and the build doctrine in `templates/CLAUDE.md`.
- **`light-the-core.sh`** — if the header comment reads limp, sharpen the wording only (no logic change); run `bash -n light-the-core.sh` after.

Acceptance: templates read crisp and professional without adopting the Forge's branded voice; placeholders and doctrine intact; `bash -n` passes if the script was touched.

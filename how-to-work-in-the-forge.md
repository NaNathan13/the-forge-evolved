# How to work in The Forge

Sitting down to build with this workflow? Five-minute read, then you're swinging.

## The one idea to hold

The workflow lives *inside* your project, next to your code. There's no separate "workflow repo." Install The Forge Core and it drops into `.claude/` at your project root — everything it knows about your work (tech stack, glossary, plans) sits right alongside the app it's helping you build:

```
your-project/
├── CLAUDE.md        ← notes about YOUR project (tech stack, rules)
├── CONTEXT.md       ← your project's glossary
├── .claude/
│   ├── skills/      ← the workflow: /ponder /inscribe /forge /temper /seal
│   └── plans/       ← active/ (in-flight) and done/ (shipped)
└── src/ …           ← your app
```

## One-time setup

From your project folder:

```bash
curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-core/main/light-the-core.sh | bash
```

That drops the workflow into `.claude/` and gives you starter docs to fill in (or run the `/light-the-core` skill — it asks three quick questions and fills them for you). Then open the project in Claude Code.

## The loop: how you actually build

Anything you build is four phases, run as five commands — one at a time. You type the command, Claude works the phase, you move on when you're ready. **Nothing auto-chains. You're always holding the hammer.**

1. **`/ponder` — think it through.** Say what you want ("add user login", "export reports as CSV"). Claude grills you one question at a time, each with a recommended answer, until the shape is clear. Pick an option, type your own, or say "go with your rec." No code or files yet.

2. **`/inscribe` — write the plan.** Claude writes the plan to `.claude/plans/active/<slug>.md`: a goal, the work cut into checklist slices, a progress bar. **Open it and read it** — it's plain markdown, so reorder, reword, or cut anything before you build. From here on, this file is the truth.

3. **`/forge` — build it.** Claude works through every unchecked slice — implementing each, ticking its box, committing as it goes. Watch it build; interrupt and redirect anytime.

4. **`/temper` — review and harden.** Claude checks the work against the plan, fixes the small stuff, and **un-ticks** any slice that needs real rework with a note on what's wrong. Something came back? Run `/forge` again, then `/temper` again.

5. **`/seal` — finish.** Claude confirms every slice is done, makes the final commit, and moves the plan to `done/`. Shipped — and the plan stands as a record of what you built.

```
/ponder → /inscribe → /forge → /temper → /seal
  think      write      build    review    finish
```

## A few utilities

- **`/grill-me`** — stress-test any idea or plan with relentless one-at-a-time questions.
- **`/research`** — go find out what an idea needs: light by default (read the code, a quick lookup), or deep (parallel agents across sources) when it's worth it. `/ponder` leans on it.
- **`/diagnose`** — a disciplined hunt for a bug when the cause isn't obvious.
- **`/scrub`** — tidy up: reconcile plan state, re-render a stale bar, sweep junk.
- **`/sharpen`** — turn a rough idea into a precise, paste-ready prompt for any session or tool.

## House rules

- **One plan at a time is simplest.** You can keep several in `active/`; the commands act on the most recent (or pass a name: `/forge my-plan`).
- **The plan file is the truth.** In doubt, open `.claude/plans/active/<slug>.md` — that's the whole state of your work.
- **Git is local.** The phases commit for you at natural points; no GitHub, no pushing unless you choose to.
- **Stay scoped.** Each slice builds what it describes. New idea mid-build? That's a new slice, or a new plan.

That's the whole system. Install it, `/ponder` your first idea, and follow the five commands.

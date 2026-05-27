---
name: temper
description: Phase 3 of the workflow — review and harden what /forge built. Checks each slice against the plan, fixes issues inline, and sends weak slices back by un-ticking them. Runs warm by default; /temper cold adds one read-only fresh-eyes reviewer whose findings feed the inline triage. Triggered by /temper after /forge.
---

# /temper — review and harden

`/temper` is the **review-and-harden phase** — it puts the build to the test. It checks the work against the plan, tightens what's sound, and flags what isn't really done. Warm and inline by default; add `cold` to dispatch one read-only fresh-eyes reviewer whose findings feed the same inline triage.

```
Ponder → Forge → Temper → Seal      (the Ponder phase = /ponder then /inscribe)
```

## What it does

1. **Read the mode, pick the plan.** `/temper` (or `/temper <slug>`) runs warm — inline, this session, today's behavior. `/temper cold` (or `/temper cold <slug>`) runs that same warm review **plus** a cold pass (step 2). Pick the plan with the same rule as `/forge`: most-recently-modified active plan, or the named one.

2. **Look at what changed.** Review the work `/forge` committed:

   ```bash
   git show --stat HEAD     # or git diff against the commit before the build
   ```

   Read the actual changes, not just the file list.

   **If `cold` was given,** get a second opinion before you triage: dispatch **one** read-only subagent with fresh context — none of this session's build assumptions. Hand it the plan file and this diff and ask it to check each done slice against its acceptance notes (correctness, missed edge cases, risky shortcuts) and return a findings list. It is read-only: it does **not** edit, fix, tick, or un-tick. Typing `cold` is the consent — don't prompt to confirm. Carry its findings into the triage below alongside what you found yourself.

3. **Check each slice against its intent.** For every slice marked done, ask:
   - Does the change actually satisfy the slice's acceptance notes?
   - Is it correct, safe, and reasonably clean? Any obvious bug, missing edge case, or risky shortcut?
   - For a tricky bug, lean on the `diagnose` skill.

4. **Prove nothing gets lost.** If the app keeps records the user relies on, verify persistence before calling it done: start the app, add a record through it (or via its API), then fully stop and restart the process and confirm the record is still there. Data that does NOT survive a restart — or that lives in browser storage (`localStorage` etc.) for real records — is an automatic fail: un-tick the storage slice with a `> needs rework:` note. (See the build doctrine in `CLAUDE.md`.)

5. **Harden inline.** Fix what you find — small corrections, a missing check, a test worth adding. These are improvements to work that's basically sound.

6. **Send back what isn't done.** If a slice doesn't actually meet its intent, **un-tick it** (`- [x]` → `- [ ]`), re-render the progress bar, and add a short note under the slice:

   > needs rework: <what's wrong / what's missing>

   The operator re-runs `/forge` to address it.

7. **Commit any fixes:**

   ```bash
   git add -A
   git commit -m "fix(<slug>): temper review"
   ```

8. **Hand off:**

   > Reviewed `<slug>`: <N> slices solid<, M sent back for rework>.
   > Run `/seal` to finish (or `/forge` to rework).

## Rules

- **Check intent, not just diff cleanliness.** A slice that runs but doesn't do what the plan said is not done.
- **Fix the small stuff, send back the big stuff.** Inline-fix sound work; un-tick anything that needs real rework.
- **Warm by default; cold is opt-in and read-only.** Plain `/temper` never prompts for cold. The cold reviewer only gathers and reports — every fix and every tick/un-tick stays in this inline session.
- **Work in place.** No branches, no push. Commit fixes on the current branch.
- **No new scope.** Harden what's there; don't bolt on features the plan didn't ask for.
- **Durable storage is non-negotiable for record apps.** A record-keeping app whose data doesn't survive a restart is not done, no matter how good it looks.

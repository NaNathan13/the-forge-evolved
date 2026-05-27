---
name: scrub
description: Reconcile forge state drift across the three sources of truth — the GitHub board (issues + status:* labels), git branches (forge/issue-*), and .claude/forge/loop-state. Detects stale in-flight cards, orphan branches, and bad loop-state cursors after an interrupted run, then OFFERS safe fixes awaiting your confirmation. Read-mostly and advisory — never auto-merges, auto-closes, deletes a branch, or moves a label on its own. Use after an interrupted /forge, when the board feels out of sync, or via /scrub.
---

# /scrub — reconcile the forge state

`/scrub` reconciles the three places forge state lives — the **GitHub board** (issues + `status:*` labels),
**git branches** (`forge/issue-*`), and **`.claude/forge/loop-state`** — and **offers** safe fixes for any
drift it finds. Use it when a `/forge` run was interrupted, a `/clear` happened mid-action, or the board and
git simply disagree.

It is **read-mostly and advisory.** It detects, reports clearly, and offers the fix — *you* say yes or no.
It **never** auto-merges, auto-closes an issue, deletes a branch, or changes a label without your explicit
confirmation. See Rules.

Runs inline. No subagents.

## How it proceeds

1. **Gather** the three state sources.
2. **Compute** the diffs between them.
3. **Report** the findings as one summary table.
4. **Offer** the safe fix per finding, **one at a time, awaiting confirmation.**

## 1. Gather the three state sources

```bash
# (a) Board: every issue carrying a forge status label, open or closed
gh issue list --state all --json number,title,state,labels \
  --search "label:status:ready,status:forging,status:in-review,status:done,status:needs-human"

# (b) Git: local forge branches, and which have landed on main
git fetch --prune origin
git branch --list 'forge/issue-*'
git branch --merged main --list 'forge/issue-*'   # branches whose work is already on main

# (c) Loop-state: the cursor + per-issue work-branch, if a run is in flight
cat .claude/forge/loop-state 2>/dev/null
```

Note that `/forge` records each issue's resolved **work-branch** in loop-state (it may be `forge/issue-<id>`
or a retried `forge/issue-<id>-r2`/`-r3`). Use the recorded name when reasoning about an in-flight issue's
branch — don't re-derive it.

## 2. Compute the diffs

Cross-reference the three sources to find drift. Detect at least these three cases.

### A. Stale in-flight card

An issue labeled `status:forging` or `status:in-review` whose `forge/issue-<id>` branch is **already merged
into `main`, or gone entirely** — the work actually landed, but the label never advanced (the run was
interrupted between merge and the label move).

```bash
# Is issue <id>'s branch already on main?  (non-empty output = merged)
git branch --merged main --list 'forge/issue-<id>' 'forge/issue-<id>-r*'
git ls-remote --heads origin 'forge/issue-<id>*'   # empty = branch is gone (likely merged + deleted)
gh issue view <id> --json number,state,labels       # confirm the card is still stuck in forging/in-review
```

If the branch is merged-or-gone AND the card is still `status:forging`/`status:in-review` → **stale card.**

### B. Orphan branch

A local `forge/issue-*` branch with **no matching open issue / no live board card** — its issue was
closed/merged, or never existed.

```bash
git branch --list 'forge/issue-*'        # extract <id> from each name
gh issue view <id> --json number,state,labels 2>/dev/null \
  || echo "no such issue"               # missing, or state CLOSED with no active status:* → orphan
```

A branch is an **orphan** when its issue is closed/merged or absent. Before offering deletion, check whether
the branch is merged into `main` (`git branch --merged main --list 'forge/issue-<id>'`) — a **merged** orphan
is safe to delete; an **unmerged** one holds work that would be lost.

### C. Bad loop-state cursor

`.claude/forge/loop-state`'s `cursor` points at an issue that is **closed, or no longer `status:*`-active**
(e.g. already `status:done`, or `status:needs-human`, or the issue was deleted) — so the loop, if resumed,
would re-process or stall on a finished issue.

```bash
# cursor value comes from the loop-state read in step 1
gh issue view <cursor-id> --json number,state,labels
```

Bad cursor when: the issue is `CLOSED`, or its label is `status:done` / `status:needs-human`, or it doesn't
exist. Also flag a **finalized** loop-state (its batch is fully drained — every issue done/escalated) that
was never cleared.

## 3. Report the findings

Print one summary table grouped by case, then handle fixes one at a time. Example:

```
DRIFT FOUND (3)
  A  stale card     #7  status:in-review  → branch forge/issue-7 merged into main
  B  orphan branch  forge/issue-12        → issue #12 closed; branch merged (safe to delete)
  C  bad cursor     loop-state → #7       → #7 already merged; cursor should advance to #8
```

If the three sources agree, **clean-exit in one line**: `Nothing to reconcile — board, git, and loop-state
are in sync.` and stop.

## 4. Offer the safe fix per finding (awaiting confirmation)

For each finding, state the fix and the exact command, then **wait for an explicit yes** before running
anything. Never batch-apply; confirm per finding.

### A. Stale in-flight card → offer to advance to `status:done`

Pair the add + remove (status labels are mutually exclusive — the sync workflow moves the board card on the
add). Remove whichever in-flight label the card carries:

```bash
# if the card is status:forging:
gh issue edit <id> --add-label status:done --remove-label status:forging
# if the card is status:in-review:
gh issue edit <id> --add-label status:done --remove-label status:in-review
```

Only on confirmation. If you can't verify the branch truly landed (merged), say so and **do not offer
`done`** — flag it for the human to inspect instead. Never close an issue here.

### B. Orphan branch → offer deletion (risk made explicit)

```bash
# merged orphan (safe): -d refuses if not actually merged
git branch -d forge/issue-<id>
```

For an **unmerged** orphan, make the risk explicit — `-d` will refuse, and only `-D` force-deletes, which
**discards the work permanently**:

```bash
# unmerged orphan — DESTRUCTIVE: forces deletion of unmerged work. Confirm the work is truly abandoned.
git branch -D forge/issue-<id>
```

Always prefer `-d`. Only reach for `-D` after the human explicitly confirms the unmerged work is disposable.
Never delete a remote branch.

### C. Bad loop-state cursor → offer to advance/reset, or clear a finalized state

- **Cursor on a finished issue, batch not done** → offer to **advance the cursor** to the next undrained
  issue in the batch list (edit `.claude/forge/loop-state` in place).
- **Loop-state finalized** (whole batch drained) → offer to **clear/finalize** it so the next `/forge` starts
  a clean batch from the board.

Only edit `.claude/forge/loop-state` on confirmation. State what the new cursor will be (or that the file
will be cleared) before touching it.

End with a one-line summary: what was reconciled (with the user's yeses) and what was left as-is.

## Rules

- **Read-mostly and advisory.** `/scrub` detects and offers; the human decides. Nothing changes without an
  explicit yes.
- **NEVER destructive without confirmation. NEVER auto-merge or auto-close.** No `gh pr merge`, no
  `gh issue close`, no `git branch -D`, no label change — ever — until the user confirms that specific fix.
- **Issues + labels + git + loop-state are the truth.** Re-read them live; don't trust stale notes.
- **Label transitions always pair add + remove** (`status:*` is mutually exclusive).
- **Confirm per finding, not in bulk.** One fix, one yes.
- **Make the risk explicit before any destructive offer** — especially `git branch -D` on unmerged work,
  which cannot be undone.
- **When the truth is ambiguous** (can't confirm a branch merged, can't tell which source is right), **flag
  it for the human** rather than offering a fix that assumes.

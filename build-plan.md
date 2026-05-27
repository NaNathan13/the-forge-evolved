# The Forge Evolved — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `superpowers:subagent-driven-development` (recommended) or
> `superpowers:executing-plans` to implement this plan phase-by-phase. Steps use checkbox (`- [ ]`) syntax.
>
> **Source of truth:** [`vision.md`](vision.md) (24 locked decisions, referenced below as "D#"). Do **not**
> re-litigate decisions. [`findings.md`](findings.md) holds the Core-vs-Forge analysis and the cut-list.
> [`research/`](research/) holds raw research on each facet.
>
> **Plan granularity note:** This is a workflow made mostly of *prompts* (skill/agent markdown) plus some real
> code (a hook, a GitHub Actions workflow, the installer, `scrub`). For prompt artifacts, steps give exact path +
> responsibility + required behaviors + how to verify (a precise spec) rather than full final prose. For code
> artifacts, steps give concrete content/commands and real verification. No vague placeholders either way.

**Goal:** A per-project-installed, GitHub-native Claude Code workflow — `ponder → inscribe → forge` — where
`/forge` autonomously drains an approved batch of issues (build → review → merge) with structural context
discipline, built from a copy of the Forge Core.

**Architecture:** Three user commands; a thin `/forge` orchestrator dispatches fresh role-based subagents
(builder, read-only reviewer, researcher) per issue; state lives in GitHub issues/labels + git + a thin
run-state file; a labels→board Actions workflow renders the Kanban; a statusline+hook gate enforces the
30%/40% context rule. Lean by default, full amenities, no Forge ceremony.

**Tech stack:** Claude Code skills/agents/hooks, `gh` CLI + GitHub Projects v2 + Actions, git (branch+squash-PR
per issue), bash, jq, markdown.

**Build order (dependency-sound, progressively dogfoodable):**
`Phase 0 scaffold → 1 CLAUDE.md → 2 context substrate → 3 planning front-end → 4 board/labels/sync →
5 the forge loop → 6 knowledge + scrub → 7 installer → 8 dogfood + doc`.
Full autonomous value lands at Phase 5; the installer (7) automates what phases 4–5 set up by hand for testing.

---

## File map (what gets created, by responsibility)

```
the-forge-evolved/
  CLAUDE.md                      # repo's OWN lean instructions (<100 lines) — D23
  CONTEXT.md                     # lazy-loaded glossary, lightweight — D21
  light-the-forge.sh             # installer/bootstrap — D17, D22
  templates/
    CLAUDE.md                    # template installed into target projects — D23
    CONTEXT.md                   # template glossary
    sync-board.yml               # template Actions workflow (IDs filled by installer) — D15
  .claude/
    settings.json                # registers statusline + the one hook
    statusline.sh                # renders ctx gauge + writes % to run-state — D10
    skills/
      ponder/SKILL.md            # grill + research; ends proposing breakdown — D2
      inscribe/SKILL.md          # docs + create/triage/label issues — D2, D9
      forge/SKILL.md             # the orchestrator loop — D5,6,7,8,12,15,18,19
      research/SKILL.md          # ad-hoc gather (kept from Core) — D17
      diagnose/SKILL.md          # debugging loop (kept from Core) — D17
      scrub/SKILL.md             # reconcile board<->git<->run-state (redefined) — D17
      sharpen/SKILL.md           # prompt/handoff helper (kept from Core) — D17
      light-the-forge/SKILL.md   # in-CC bootstrap entry (wraps the .sh) — D17
    agents/
      forge-builder.md           # edit/bash/test tools; fed lessons — D24
      forge-reviewer.md          # READ-ONLY, alt model, adversarial rubric — D24, D8
      forge-researcher.md        # read-only gather/distill — D24
    hooks/
      ctx-gate.sh                # PreToolUse: deny tool calls at >=40% — D10
    forge/                       # ephemeral run-state (NOT knowledge) — D11, D14
      .ctx                       # current context % (written by statusline)
      loop-state                 # active batch + in-flight issue + attempt
  .github/
    workflows/
      sync-board.yml             # labels -> Projects v2 Status (live install) — D15
  .knowledge/
    lessons.md                   # capped, append-only, fed to subagents — D13
  docs/
    how-the-forge-evolved-works.md  # ONE canonical doc — anti-Forge-sprawl
```

**Cut from the Core/Forge (verify these are ABSENT):** `triage`, `prototype`, `tinker`, `examine`, `rollback`,
`write-a-skill`, standalone `grill-me`; the resilience substrate (heartbeat / watchdog / launchd / circuit
breakers); `instructions-loaded.jsonl` + its hook; `MISSION-CONTROL.md`; ADRs; the glossary hard-gate; the
`human-only read guard` hook. (D17, D20, findings.md cut-list.)

---

## Phase 0 — Scaffold from the Core copy

**Files:** copy `../the-forge-core/*` (minus `.git`) into repo root; then prune.

- [x] **Step 1: Copy the Core (minus its git history).** D22.
  Run: `rsync -a --exclude='.git' ../the-forge-core/ ./` (from repo root). The planning docs already here
  (`vision.md`, `findings.md`, `build-plan.md`, `research/`) must be preserved — `rsync` without `--delete`
  is safe.
- [x] **Step 2: Initialize fresh git history.** *(on branch `build/bootstrap`, never main)*
  Run: `git init && git add -A && git commit -m "chore: scaffold from forge-core (minus history)"`
  Expected: clean repo, one commit, no Core history.
- [x] **Step 3: Rename `light-the-core` → `light-the-forge`** (script + skill dir) and update internal refs.
  Run: `git mv light-the-core.sh light-the-forge.sh` and `git mv .claude/skills/light-the-core .claude/skills/light-the-forge`.
- [x] **Step 4: Delete the cut skills.**
  Run: `rm -rf .claude/skills/{grill-me,temper,seal}` *(temper/seal become internal stages, not commands — D16;
  grill-me absorbed into ponder — D17)*. The Core has no triage/prototype/tinker/examine/rollback/write-a-skill,
  so confirm none exist: `ls .claude/skills`.
- [x] **Step 5: Create the new empty dirs/files** the later phases fill:
  `mkdir -p .claude/agents .claude/hooks .claude/forge .knowledge .github/workflows docs templates` and
  `touch .knowledge/lessons.md`.
- [x] **Step 6: Verify + commit.**
  Check: `ls .claude/skills` shows exactly `ponder inscribe forge research diagnose scrub sharpen light-the-forge`.
  Commit: `git commit -am "chore: prune to the Evolved skill set"`.

**Delivers:** clean skeleton with the kept utilities, metaphor intact, ready to evolve. **Verify:** skill list
matches D17 exactly; cut artifacts absent.

---

## Phase 1 — CLAUDE.md + lazy-load discipline

**Files:** Create/rewrite `CLAUDE.md`, `templates/CLAUDE.md`; trim `CONTEXT.md` + `templates/CONTEXT.md`. D21, D23.

- [x] **Step 1: Write the repo's own `CLAUDE.md`** (<100 lines, imperative, one rule/line). Required sections:
  - Title + one-line purpose.
  - **Commands:** `ponder` / `inscribe` / `forge` one-liners + "use sequentially; don't forge without ready issues."
  - **Context discipline (CRITICAL):** warn 30% / hard-stop 40% / hand off + continue; the statusline gauge and
    `ctx-gate` hook enforce it (D10). State lives in GitHub + git, so resume = `/clear` then re-run the command.
  - **Architecture quirks:** thin orchestrator + fresh subagents; absolute paths in Bash (cwd resets); skills load
    on demand; keep this file <100 lines.
  - **Response Style** (verbatim, D23):
    ```
    ## Response Style
    - Concise. No preamble, no "I'll now..." narration.
    - No explanations unless asked. Skip recaps of completed work.
    - Code only when showing actual code, not summaries.
    - When a task is done, end. No "let me know if..." closers.
    - If I flag a mistake, fix it without re-asking or apologizing.
    ```
  - Footer: `See CONTEXT.md for glossary (load on demand). See .knowledge/lessons.md (skill-fed).` No `@imports`.
- [x] **Step 2: Write `templates/CLAUDE.md`** — the generic version the installer drops into a *target* project:
  same structure, project-name placeholder, project-specific test/lint commands left as `{{TEST_CMD}}` etc.
  for the installer to fill (D22).
- [x] **Step 3: Trim `CONTEXT.md`** to a lightweight glossary of the Forge's own terms (batch, slice, hard gate,
  verification method, escalation, handoff). Remove any Core glossary cruft and any hard-gate validation language.
- [x] **Step 4: Verify + commit.** Check: `wc -l CLAUDE.md` ≤ 100; `grep -c '@' CLAUDE.md` shows no stray imports.
  Commit: `git commit -am "feat: lean CLAUDE.md + template + trimmed CONTEXT"`.

**Delivers:** the always-loaded layer is lean and high-signal. **Verify:** <100 lines; Response Style present;
glossary lazy, not inlined.

---

## Phase 2 — Context-discipline substrate (the #1 feature)

**Files:** Create `.claude/statusline.sh`, `.claude/hooks/ctx-gate.sh`; modify `.claude/settings.json`. D10, D11.

- [x] **Step 1: Write `.claude/statusline.sh`.** Reads statusline JSON on stdin; extracts
  `.context_window.used_percentage`; writes the integer to `.claude/forge/.ctx`; prints a gauge.
  ```bash
  #!/usr/bin/env bash
  input=$(cat)
  pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
  echo "$pct" > .claude/forge/.ctx 2>/dev/null
  model=$(printf '%s' "$input" | jq -r '.model.display_name // "?"')
  if   [ "$pct" -ge 40 ]; then printf '\033[41m HARD %s%% \033[0m %s' "$pct" "$model"
  elif [ "$pct" -ge 30 ]; then printf '\033[43m WARN %s%% \033[0m %s' "$pct" "$model"
  else printf 'ctx %s%% ▸ warn 30/hard 40  %s' "$pct" "$model"; fi
  ```
- [x] **Step 2: Write `.claude/hooks/ctx-gate.sh`** (PreToolUse). Reads `.claude/forge/.ctx`; at ≥40 returns a
  deny decision with a handoff instruction; else allows.
  ```bash
  #!/usr/bin/env bash
  pct=$(cat .claude/forge/.ctx 2>/dev/null || echo 0)
  if [ "${pct:-0}" -ge 40 ]; then
    cat <<'JSON'
  {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",
   "permissionDecisionReason":"Context >=40% (hard stop). Stop now: write/refresh the handoff, then /clear and re-run the command — state is in GitHub + git + loop-state."}}
  JSON
  else echo '{}'; fi
  ```
- [x] **Step 3: Register both in `.claude/settings.json`** — `statusLine.command` → `.claude/statusline.sh`;
  `hooks.PreToolUse[*]` matcher `*` → `.claude/hooks/ctx-gate.sh`. `chmod +x` both scripts.
- [x] **Step 4: Verify the gate.**
  Run: `echo 41 > .claude/forge/.ctx && bash .claude/hooks/ctx-gate.sh` → Expected: JSON with `"deny"`.
  Run: `echo 28 > .claude/forge/.ctx && bash .claude/hooks/ctx-gate.sh` → Expected: `{}`.
  Run: `echo '{"context_window":{"used_percentage":31.4},"model":{"display_name":"Opus"}}' | bash .claude/statusline.sh`
  → Expected: `WARN 31%`; and `cat .claude/forge/.ctx` → `31`.
- [x] **Step 5: Commit.** `git commit -am "feat: context-discipline statusline + hard-stop hook"`.

**Delivers:** a *real* 30/40 gate (not display-only — D10). **Verify:** deny at 41, allow at 28, % file written.

---

## Phase 3 — Planning front-end (ponder + inscribe + researcher agent)

**Files:** Rewrite `.claude/skills/ponder/SKILL.md`, `.claude/skills/inscribe/SKILL.md`; create
`.claude/agents/forge-researcher.md`. D2, D9, D24.

- [x] **Step 1: Write `.claude/agents/forge-researcher.md`.** Read-only tools only (no Edit/Write/Bash-mutating).
  Responsibility: take a focused question, fan out, return a **distilled** answer (no transcript dump). Frontmatter
  sets read-only tool list + model. (D24)
- [x] **Step 2: Rewrite `ponder/SKILL.md`.** Required behaviors:
  - Runs a grill-me-style, one-question-at-a-time interview to define/refine the idea (D2).
  - May dispatch `forge-researcher` for unknowns (confirm before heavy fan-out).
  - **Self-checkpoints context:** at ~35% writes a distilled handoff to `.claude/forge/handoff.md` and tells the
    user to `/clear` + re-run `ponder` (D10, D11).
  - **Ends by proposing the issue breakdown** — titles, scope, the UI/logic split, each issue's verification
    method (`verify:test` | `verify:visual`) and machine-checkable acceptance criteria — and asks for one-word
    confirmation before any GitHub write (D2, D9). On "go", invokes inscribe.
- [x] **Step 3: Rewrite `inscribe/SKILL.md`.** On confirmation:
  - Documents the worked-out knowledge where it belongs (project docs / CLAUDE.md); appends a lesson to
    `.knowledge/lessons.md` only if a hard-won reusable fact emerged (high bar — D13).
  - Creates each GitHub issue: `gh issue create` with a body containing **machine-checkable acceptance criteria**;
    applies labels `status:ready`, `verify:test`|`verify:visual` (D9, D15); adds it to the project board
    (`gh project item-add`).
  - Triages/orders the issues (dependency order: logic before dependent UI) and reports the created issue numbers.
- [x] **Step 4: Verify** (on a throwaway test repo with a board, or `--dry-run` style):
  ponder on a toy idea proposes a breakdown and stops for confirmation; on "go", inscribe creates issues whose
  bodies contain acceptance criteria and that carry `status:ready` + a `verify:*` label. Check:
  `gh issue list --label status:ready` shows them.
  *(Done as per-criterion read-only review of both skills against the spec — all 11 PASS. Live ponder→inscribe
  run on a real board is folded into the Phase 8 dogfood, since the board is stood up by the Phase 7 installer.)*
- [x] **Step 5: Commit.** `git commit -am "feat: ponder (grill+research) and inscribe (docs+issues)"`.

**Delivers:** idea → confirmed → GitHub issues with criteria + labels. **Verify:** breakdown gate fires; issues
created with correct labels/criteria.

---

## Phase 4 — Board, labels & the labels→board sync

**Files:** Create `.github/workflows/sync-board.yml` and `templates/sync-board.yml`. Define the label set. D15.

- [ ] **Step 1: Define the label set** (created by the installer in Phase 7; documented here):
  `status:ready`, `status:forging`, `status:in-review`, `status:done`, `status:needs-human`;
  `verify:test`, `verify:visual`; `needs-reslice`, `review-failed`. Status labels are mutually exclusive
  (the agent removes the old status label when adding the new one).
- [ ] **Step 2: Write `.github/workflows/sync-board.yml`.** Trigger: `issues: [labeled, unlabeled]`. On a
  `status:*` label change, call `updateProjectV2ItemFieldValue` to set the board's `Status` field to the matching
  option. Uses repo/org **variables** for `PROJECT_ID`, `STATUS_FIELD_ID`, and the option IDs (written by the
  installer — D15), and a **PAT secret** with `project` scope (the Actions `GITHUB_TOKEN` cannot touch Projects).
  Map: `status:ready→Ready`, `forging→Forging`, `in-review→In Review`, `done→Done`, `needs-human→Needs Human`.
  Pause/handle GraphQL `errors` in the response (rate-limit returns 200+errors).
- [ ] **Step 3: Write `templates/sync-board.yml`** — identical but with `${{ vars.* }}` placeholders documented
  so the installer can populate them per repo.
- [ ] **Step 4: Verify** on the test repo: `gh issue edit <n> --add-label status:forging --remove-label status:ready`
  → within a few seconds the board card moves to **Forging**. Confirm the Action run succeeded
  (`gh run list --workflow sync-board.yml`).
- [ ] **Step 5: Commit.** `git commit -am "feat: labels->Projects v2 board sync workflow"`.

**Delivers:** agent-simple label state renders as a live Kanban. **Verify:** a label change moves the card.

---

## Phase 5 — The forge loop (orchestrator + builder & reviewer agents)

**Files:** Create `.claude/agents/forge-builder.md`, `.claude/agents/forge-reviewer.md`; rewrite
`.claude/skills/forge/SKILL.md`. D5, D6, D7, D8, D12, D15, D18, D19, D24.

- [x] **Step 1: Write `.claude/agents/forge-builder.md`.** Tools: Edit/Write/Bash/test-run. Responsibility: given
  one issue (criteria + repo + relevant `.knowledge/lessons.md`), implement it on the current branch, add tests
  if `verify:test`, return a **distilled** summary + the changed files + a "too-large" signal if it approached its
  context limit (D12). Frontmatter notes: on retry rounds the orchestrator restricts test-file writes (D8).
- [x] **Step 2: Write `.claude/agents/forge-reviewer.md`.** Tools: **READ-ONLY** (read + `git diff`, no edit —
  structural enforcement, D8/D24). Different model than builder. Input: the issue's acceptance criteria + the
  diff, *nothing else*. Output: per-criterion `PASS|FAIL` with a cited diff line + one-sentence evidence; a FAIL
  without a citation is auto-ignored; APPROVE only if all PASS. Prompt framing: "find every way this diff fails
  the criteria." Adapts to `verify:visual` (checks the screenshot/render evidence instead of tests).
- [ ] **Step 3: Write `forge/SKILL.md`** — the thin orchestrator. Required loop (holds only batch list + 1-line
  status per issue — D6):
  1. Read `gh issue list --label status:ready`; **propose the batch** and list it; **wait for approval** (D5).
  2. Init/refresh `.claude/forge/loop-state` (batch + cursor + attempt). For each issue, in order:
     - `git switch -c forge/issue-<id>` from updated `main` (`-r2` etc. on retry — D5); ensure clean tree.
     - Set `status:forging` (removes `status:ready`).
     - Dispatch `forge-builder`; if it returns "too-large" → `status:needs-human` + `needs-reslice`, skip,
       record, continue (D12).
     - **Hard gates** (D8/D9): run tests + type-check + lint (`verify:test`) or capture render/screenshot
       (`verify:visual`). If a hard gate fails or the builder touched test/CI files → treat as FAIL.
     - Set `status:in-review`; dispatch `forge-reviewer` (diff + criteria). 
     - If FAIL and attempts <3: re-dispatch builder with the reviewer's cited failures (retry restricts test-file
       writes); loop. If still failing after 3, or diff >~2× expected scope → `status:needs-human` +
       `review-failed`, skip, record, continue (D8).
     - On APPROVE: open PR (`gh pr create`, auto-closes issue), **squash-merge**, run tests post-merge; if they
       fail, `git revert` the squash commit and record (D5). Set `status:done`.
     - Update `loop-state`; capture the builder/reviewer **context% + round count** for the report (D19).
  3. At batch end: **stop**, emit the report (merged / escalated-with-reason / remaining + per-issue context% &
     rounds). No auto-chaining to the next batch (D18).
- [ ] **Step 4: Verify end-to-end** on the test repo: ready 2 trivial issues (one `verify:test`, one
  `verify:visual`), run forge, approve the batch, confirm: branches created, cards moved ready→forging→in-review
  →done, PRs squash-merged + issues closed, a deliberately-failing issue escalates to Needs Human after 3 rounds,
  and the end report lists context%/rounds.
- [ ] **Step 5: Commit.** `git commit -am "feat: forge orchestrator loop + builder/reviewer agents"`.

**Delivers:** the autonomous, hands-off, escalating batch loop (D7). **Verify:** full happy-path + an escalation
path both observed end-to-end.

---

## Phase 6 — Knowledge layer + scrub

**Files:** Wire lessons into the agents (Phase 5 files); rewrite `.claude/skills/scrub/SKILL.md`. D13, D17.

- [ ] **Step 1: Confirm lessons wiring.** `forge-builder` and `forge-reviewer` receive the relevant lines of
  `.knowledge/lessons.md` at dispatch; builder appends a one-line lesson **only** after overcoming a real wall
  (high bar). Add a soft cap (e.g., 50 lines) note in `lessons.md` header. (D13)
- [ ] **Step 2: Rewrite `scrub/SKILL.md`** (redefined — D17). Reconciles board ↔ git ↔ `loop-state`, safe-fix
  only, never auto-merges/auto-closes:
  - card in `Forging`/`In Review` but its `forge/issue-*` branch is merged/gone → flag + offer to set `status:done`.
  - orphan `forge/issue-*` branch with no open issue/card → flag for deletion.
  - `loop-state` cursor pointing at a closed issue → reset.
- [ ] **Step 3: Verify.** Plant an inconsistency (e.g., merge a branch but leave its label `status:forging`); run
  scrub; confirm it detects and proposes the fix (and does nothing destructive without confirmation).
- [ ] **Step 4: Commit.** `git commit -am "feat: lessons wiring + scrub reconcile"`.

**Delivers:** subagents stop re-discovering; state stays honest. **Verify:** lesson append works; scrub catches drift.

---

## Phase 7 — Installer (`light-the-forge`)

**Files:** Rewrite `light-the-forge.sh` + `.claude/skills/light-the-forge/SKILL.md`. D17, D22, D15.

- [ ] **Step 1: Write `light-the-forge.sh`** to bootstrap a *target* project. Steps it performs:
  - Ask setup questions (project name; `{{TEST_CMD}}`, `{{TYPECHECK_CMD}}`, `{{LINT_CMD}}`; board owner).
  - **Auth check:** `gh auth status`; verify `project` scope present; if not, instruct `gh auth refresh -s project`
    and that a **classic** PAT is required (fine-grained PATs don't support Projects v2 — D15). Halt until satisfied.
  - Copy skills/agents/hooks/statusline/`.knowledge`/templates into the target's `.claude/` etc.; fill template
    placeholders in `CLAUDE.md`/`CONTEXT.md`.
  - **Create the board:** `gh project create`; `gh project field-create … --data-type SINGLE_SELECT
    --single-select-options "Backlog,Ready,Forging,In Review,Done,Needs Human"`; `gh project link` to the repo.
  - **Create labels** (the Phase-4 set) via `gh label create`.
  - **Fetch the IDs** (project node id, Status field id, option ids) and write them into the repo's
    `.github/workflows/sync-board.yml` + repo variables/secrets; install the PAT secret for the workflow.
  - Register statusline + `ctx-gate` hook in the target `.claude/settings.json`.
- [ ] **Step 2: Write `.claude/skills/light-the-forge/SKILL.md`** — the in-Claude-Code entry that runs the script
  and walks the user through the auth/board steps conversationally.
- [ ] **Step 3: Verify** on a fresh empty test repo: run the installer → board with the 6 columns exists, labels
  exist, `sync-board.yml` present with IDs filled, skills/agents/hooks installed, a label change moves a card.
- [ ] **Step 4: Commit.** `git commit -am "feat: light-the-forge installer (board+labels+sync+skills)"`.

**Delivers:** one command stands up the whole workflow on a new repo. **Verify:** end-to-end install on a clean repo.

---

## Phase 8 — Dogfood + the one canonical doc

**Files:** Create `docs/how-the-forge-evolved-works.md`; update `README.md`.

- [ ] **Step 1: Write ONE canonical doc** (`docs/how-the-forge-evolved-works.md`) — the only narrative doc
  (anti-Forge-sprawl: no at-a-glance + how-it-works + workflow + meta-doc-about-docs). Cover the 3 commands, the
  loop, the board, context discipline, escalation. Keep `README.md` to a short pointer.
- [ ] **Step 2: Dogfood** the full loop on a small real feature in a sandbox project: ponder → inscribe → forge a
  2–4 issue batch; confirm the end report + board reflect reality. Capture any lesson into `.knowledge/lessons.md`.
- [ ] **Step 3: Commit.** `git commit -am "docs: canonical how-it-works + first dogfood"`.

**Delivers:** documented, proven workflow. **Verify:** a real feature shipped through the loop unattended.

---

## Self-review (against vision.md)

**Spec coverage — every locked decision maps to a phase:**
D1 per-project install → P7 installer · D2 ponder→confirm→inscribe → P3 · D3 board → P4/P7 · D4 batch=ready issues
→ P5.1 · D5 branch+squash-PR+test-gate → P5.3 · D6 thin orchestrator+subagents → P5 · D7 hands-off+escalation →
P5.3 · D8 review gate → P5.2/P5.3 · D9 verification posture → P3/P5 · D10 context hook → P2 · D11 continuation →
P2/P3/P5 · D12 overflow→reslice → P5.3 · D13 knowledge → P3/P6 · D14 folders (.knowledge vs .claude/forge) → P0/P2/P6
· D15 labels+Actions sync + auth → P4/P7 · D16 three commands → P0 · D17 skill inventory → P0 · D18 stop+report →
P5.3 · D19 token report → P5.3 · D20 one hook → P2 · D21 CONTEXT.md → P1 · D22 copy Core → P0 · D23 CLAUDE.md → P1 ·
D24 three agents → P3/P5. **No gaps.**

**Placeholder scan:** template files intentionally carry `{{...}}`/`${{ vars.* }}` (installer fills them) — these
are the *only* placeholders and are real install-time variables, not plan gaps.

**Naming consistency:** labels `status:ready|forging|in-review|done|needs-human` + `verify:test|visual` +
`needs-reslice|review-failed`; branches `forge/issue-<id>`; run-state `.claude/forge/{.ctx,loop-state,handoff.md}`;
knowledge `.knowledge/lessons.md`; agents `forge-builder|forge-reviewer|forge-researcher` — used consistently across
all phases.

---

## Execution handoff

Plan saved to `build-plan.md`. Two execution options:

1. **Subagent-driven (recommended)** — dispatch a fresh subagent per phase, review between phases. This also
   *dogfoods the very architecture we're building* (thin orchestrator + fresh subagents + context discipline).
2. **Inline** — execute phases in-session with checkpoints.

Phases are independently verifiable and committed, so either works. Phase 0–2 are quick and unblock everything;
Phase 5 is the heart and worth its own focused session.

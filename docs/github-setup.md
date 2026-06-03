# GitHub setup (you do this)

`light-the-forge.sh` installs the local kit and the app repo. The GitHub side is yours: the repo, a
Projects v2 board, the label set, the repo variables, and the PAT secret. This is the one-time checklist.

These are plain `gh` commands — run them yourself, or hand them to Claude when you want it to. They assume
`gh`, `git`, and `jq` on PATH. Replace `<owner>`, `<slug>`, and `./<name>-app` with your values (the slug
and app folder are what the installer printed; they're in `.claude/forge/config`).

## 0. Authenticate

The board lives on Projects v2, which needs the `project` scope:

```bash
gh auth login                 # if you're not logged in yet
gh auth refresh -s project    # add the 'project' scope
```

## 1. Create the repo and push the app folder

```bash
cd ./<name>-app
gh repo create <owner>/<slug> --private --source . --remote origin --push
# use --public instead of --private if you want it public
```

## 2. Create the Projects v2 board

The board carries the six Forge columns as a single-select field named **Forge Status**, in order.

```bash
# create the board
PROJECT_NUMBER="$(gh project create --owner <owner> --title "<Project Name> — Forge" --format json -q .number)"

# link it to the repo
gh project link "$PROJECT_NUMBER" --owner <owner> --repo <owner>/<slug>

# the six-option status field (order matters)
gh project field-create "$PROJECT_NUMBER" --owner <owner> \
  --name "Forge Status" --data-type SINGLE_SELECT \
  --single-select-options "Backlog,Ready,Forging,In Review,Done,Needs Human"
```

In the board's UI, open the board/Kanban view → **Group by** → **Forge Status** so the six columns appear.

## 3. Create the labels

Labels are the actual state machine; the board mirrors them.

```bash
R=<owner>/<slug>
gh label create "status:ready"       --color 0e8a16 --description "Queued for the forge loop"            --force --repo "$R"
gh label create "status:forging"     --color fbca04 --description "A builder is implementing this issue"  --force --repo "$R"
gh label create "status:in-review"   --color 1d76db --description "Under read-only adversarial review"    --force --repo "$R"
gh label create "status:done"        --color 5319e7 --description "Merged and verified"                   --force --repo "$R"
gh label create "status:needs-human" --color b60205 --description "Escalated — needs a human"             --force --repo "$R"
gh label create "verify:test"        --color c2e0c6 --description "Gated by tests + type-check + lint"     --force --repo "$R"
gh label create "verify:visual"      --color bfdadc --description "Gated by a render/screenshot review"    --force --repo "$R"
gh label create "needs-reslice"      --color d93f0b --description "Outgrew a single context window — reslice" --force --repo "$R"
gh label create "review-failed"      --color e11d21 --description "Failed review after max rounds"         --force --repo "$R"
```

## 4. Resolve board IDs and set the repo variables

The sync workflow reads these as repo Variables. Resolve the IDs from the board, then set them:

```bash
R=<owner>/<slug>

# project node id (PVT_...)
PROJECT_ID="$(gh project view "$PROJECT_NUMBER" --owner <owner> --format json -q .id)"

# the Forge Status field id and its option ids
FIELDS="$(gh project field-list "$PROJECT_NUMBER" --owner <owner> --format json)"
FIELD_ID="$(jq -r '.fields[]? | select(.name=="Forge Status") | .id' <<<"$FIELDS")"
opt() { jq -r --arg o "$1" '.fields[]? | select(.name=="Forge Status") | .options[]? | select(.name==$o) | .id' <<<"$FIELDS"; }

gh variable set FORGE_PROJECT_ID      --repo "$R" --body "$PROJECT_ID"
gh variable set FORGE_STATUS_FIELD_ID --repo "$R" --body "$FIELD_ID"
gh variable set FORGE_OPT_READY       --repo "$R" --body "$(opt 'Ready')"
gh variable set FORGE_OPT_FORGING     --repo "$R" --body "$(opt 'Forging')"
gh variable set FORGE_OPT_IN_REVIEW   --repo "$R" --body "$(opt 'In Review')"
gh variable set FORGE_OPT_DONE        --repo "$R" --body "$(opt 'Done')"
gh variable set FORGE_OPT_NEEDS_HUMAN --repo "$R" --body "$(opt 'Needs Human')"
```

## 5. Set the PAT secret

The labels→board sync workflow authenticates to Projects v2 with a **classic** PAT carrying the `project`
scope (add `repo` for a private app repo). Fine-grained PATs cannot drive Projects v2, and the Actions
`GITHUB_TOKEN` cannot reach it. Create one at <https://github.com/settings/tokens> → **Tokens (classic)**.

```bash
gh secret set FORGE_PROJECT_PAT --repo <owner>/<slug>   # paste the classic PAT at the prompt
```

## 6. Wire the coordinates into the kit

Open `.claude/forge/config` and set:

- `PROJECT_NUMBER` — the board number from step 2.
- `REPO_SLUG` / `BOARD_OWNER` — confirm they match `<owner>/<slug>` and `<owner>` (the installer pre-fills
  these from the owner you gave it).

The forge skills read this file to find and move issues on the board.

## Done

Open the project folder in Claude Code and run `/prospect` (it researches + warms the idea, then sends you
into `/ponder`). Once issues exist and a `status:*` label moves, the sync workflow mirrors it onto the board.

#!/usr/bin/env bash
# light-the-forge.sh — scaffold a brand-new Forge Evolved project, in one run.
#
# Run this from inside an empty (or nearly empty) PROJECT FOLDER. It asks a few
# questions, then stands up the split layout The Forge Evolved expects:
#
#   project-folder/                 ← you run this here; Claude Code opens HERE
#   ├── .claude/skills, agents, hooks, statusline.sh, forge/ (run-state)
#   ├── .knowledge/lessons.md
#   ├── CLAUDE.md, CONTEXT.md
#   └── <name>-app/                 ← a fresh git repo, created + pushed to GitHub
#       ├── .github/workflows/sync-board.yml
#       └── README.md               ← (your code gets built here, via /ponder → /forge)
#
# The outer folder holds the forge tooling + run-state and is NOT pushed anywhere.
# The <name>-app/ subfolder is the only thing on GitHub. After this runs, open the
# OUTER folder in Claude Code and run /ponder.
#
# It also provisions the GitHub side for the new app repo: a Projects v2 board with
# the six Forge columns, the Forge label set, the labels->board sync workflow, and
# the repo variables + PAT secret that workflow reads.
#
# Usage:
#   # One-liner (self-fetches the kit), from inside your empty project folder:
#   curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/light-the-forge.sh | bash
#
#   # Or from a local checkout of the-forge-evolved:
#   /path/to/light-the-forge.sh                 # scaffold into the current dir
#   /path/to/light-the-forge.sh <project-dir>   # scaffold into the named (outer) dir
#
# Requirements: gh (authenticated, with `project` scope), git, jq.

set -euo pipefail

# Real published location of the kit (used by the curl|bash self-fetch path).
REPO_URL="https://github.com/NaNathan13/the-forge-evolved.git"

# ─── color helpers ───────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'
  BOLD=$'\033[1m';  DIM=$'\033[2m';     CYAN=$'\033[36m'; N=$'\033[0m'
else
  GREEN='' YELLOW='' RED='' BOLD='' DIM='' CYAN='' N=''
fi
green()  { printf '%s%s%s\n' "$GREEN"  "$*" "$N"; }
yellow() { printf '%s%s%s\n' "$YELLOW" "$*" "$N" >&2; }
red()    { printf '%s%s%s\n' "$RED"    "$*" "$N" >&2; }
bold()   { printf '%s%s%s\n' "$BOLD"   "$*" "$N"; }
cyan()   { printf '%s%s%s\n' "$CYAN"   "$*" "$N"; }
die()    { red "✗ $*"; exit 1; }

# ─── resolve source root from $0 ──────────────────────────────────────────────
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_PATH" ]]; then
  while [[ -L "$SCRIPT_PATH" ]]; do
    SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
  done
  SRC="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
else
  SRC=""
fi

# ─── tool preflight ───────────────────────────────────────────────────────────
command -v gh  >/dev/null 2>&1 || die "GitHub CLI (gh) is required and not on PATH. Install: https://cli.github.com"
command -v git >/dev/null 2>&1 || die "git is required and not on PATH."
command -v jq  >/dev/null 2>&1 || die "jq is required and not on PATH. Install: https://jqlang.github.io/jq/"

# ─── self-bootstrap: clone the kit if we're not running from a checkout ───────
is_forge_checkout() {
  [[ -n "$SRC" && -f "$SRC/light-the-forge.sh" && -d "$SRC/templates" && -d "$SRC/.claude/skills" ]]
}
if ! is_forge_checkout; then
  CLONE_DIR="$(mktemp -d)"
  trap 'rm -rf "$CLONE_DIR"' EXIT
  bold "Fetching The Forge Evolved…"
  git clone --depth 1 --quiet "$REPO_URL" "$CLONE_DIR" || die "Failed to clone $REPO_URL"
  SRC="$CLONE_DIR"
fi

# ─── resolve the OUTER project folder (where the kit installs / Claude runs) ──
OUTER="${1:-$(pwd)}"
[[ -d "$OUTER" ]] || die "Project directory does not exist: $OUTER"
OUTER="$(cd -P "$OUTER" && pwd)"
if [[ "$SRC" == "$OUTER" ]]; then
  die "You're running this from inside the-forge-evolved checkout itself. Run it from a NEW, empty project folder (or pass one as an argument)."
fi

bold "The Forge Evolved — new project scaffold"
printf '  Kit source:     %s\n  Project folder: %s\n\n' "$SRC" "$OUTER"

# ─── auth gate (BEFORE the questions, so you don't fill the form then hit a wall) ─
bold "Checking GitHub authentication…"
if ! gh auth status >/dev/null 2>&1; then
  red   "✗ Not logged in to GitHub CLI."
  yellow "  Run: gh auth login   (then re-run this installer)"
  exit 1
fi
# Parse the 'Token scopes:' line from gh auth status text output (the --json
# field set does not expose scopes). Scopes are single-quoted, comma-separated.
SCOPE_LINE="$(gh auth status 2>&1 | grep -i 'Token scopes:' | head -n1 || true)"
if ! grep -q "'project'" <<<"$SCOPE_LINE"; then
  red    "✗ Your gh token is missing the 'project' scope (required for Projects v2)."
  echo   "    Detected scopes: ${SCOPE_LINE#*Token scopes: }" >&2
  echo   "" >&2
  yellow "  Fix it:  gh auth refresh -s project   (then re-run)"
  echo   "" >&2
  echo   "  NOTE: a CLASSIC PAT with the 'project' scope is what the sync workflow" >&2
  echo   "        needs at runtime. Fine-grained PATs do NOT support Projects v2," >&2
  echo   "        and the Actions GITHUB_TOKEN cannot touch Projects v2 at all." >&2
  exit 1
fi
green "  ✓ gh is authenticated and has the 'project' scope"

# ─── setup questions ──────────────────────────────────────────────────────────
ask() {  # ask VARNAME "prompt" "default"
  local __var="$1" __prompt="$2" __default="${3:-}" __ans=""
  if [[ -n "$__default" ]]; then
    printf '%s%s%s [%s]: ' "$BOLD" "$__prompt" "$N" "$__default" > /dev/tty
  else
    printf '%s%s%s: ' "$BOLD" "$__prompt" "$N" > /dev/tty
  fi
  IFS= read -r __ans < /dev/tty || true
  [[ -z "$__ans" ]] && __ans="$__default"
  printf -v "$__var" '%s' "$__ans"
}

# slugify: lowercase, spaces/underscores→hyphens, strip non [a-z0-9-], collapse + trim hyphens
slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[ _]+/-/g; s/[^a-z0-9-]//g; s/-+/-/g; s/^-+//; s/-+$//'
}

default_owner="$(gh api user -q .login 2>/dev/null || true)"

echo
bold "Tell me about the project"
ask PROJECT_NAME       "Project name (proper casing, e.g. Recipe Box)"   ""
[[ -n "$PROJECT_NAME" ]] || die "Project name is required."
ask OWNER              "GitHub owner (user or org login)"                "$default_owner"
[[ -n "$OWNER" ]] || die "A GitHub owner is required."
ask VISIBILITY         "Repo visibility (private/public)"                "private"
case "$VISIBILITY" in
  private|public) ;;
  *) yellow "  ! '$VISIBILITY' isn't private/public — defaulting to private"; VISIBILITY="private" ;;
esac
ask PROJECT_ONE_LINER  "One-line description of what you're building"    "A project built with The Forge Evolved."
ask DO_RESEARCH        "Kick off initial research before building? (y/N)" "N"
RESEARCH_NOTE=""
case "$DO_RESEARCH" in
  y|Y|yes|YES)
    ask RESEARCH_NOTE  "  What should /ponder research first?"           ""
    ;;
esac

# ─── derive names ─────────────────────────────────────────────────────────────
SLUG="$(slugify "$PROJECT_NAME")"
[[ -n "$SLUG" ]] || die "Could not derive a repo slug from '$PROJECT_NAME'. Use letters/numbers."
APP_DIR_NAME="${SLUG}-app"
APP_DIR="$OUTER/$APP_DIR_NAME"
REPO_SLUG="$OWNER/$SLUG"

# ─── confirm ───────────────────────────────────────────────────────────────────
echo
bold "── Confirm ─────────────────────────────────"
cyan  "  Display name : $PROJECT_NAME"
cyan  "  Repo         : $REPO_SLUG  ($VISIBILITY)"
cyan  "  App folder   : ./$APP_DIR_NAME"
cyan  "  Description  : $PROJECT_ONE_LINER"
if [[ -n "$RESEARCH_NOTE" ]]; then
  cyan "  Research     : $RESEARCH_NOTE"
elif [[ "$DO_RESEARCH" =~ ^(y|Y|yes|YES)$ ]]; then
  cyan "  Research     : (yes — /ponder will research as it grills the idea)"
else
  cyan "  Research     : (none)"
fi
echo
ask CONFIRM "Proceed? (Y/n)" "Y"
case "$CONFIRM" in
  n|N|no|NO) die "Aborted — nothing was created." ;;
esac

# ─── collision checks ──────────────────────────────────────────────────────────
echo
bold "Checking for collisions…"
if [[ -e "$APP_DIR" ]]; then
  die "App folder already exists: $APP_DIR
  Refusing to clobber it. Pick a different project name, or remove that folder, then re-run."
fi
if gh repo view "$REPO_SLUG" >/dev/null 2>&1; then
  die "GitHub repo already exists: $REPO_SLUG
  Refusing to reuse it for a fresh scaffold. Pick a different name (or delete that repo), then re-run."
fi
green "  ✓ ./$APP_DIR_NAME is free, and $REPO_SLUG does not exist yet"

# ─── 1. install the forge kit into the OUTER folder ───────────────────────────
echo
bold "Installing the forge kit into the project folder…"

copy_tree() {  # copy_tree <relpath> [label]
  local rel="$1" label="${2:-$1}"
  if [[ -d "$SRC/$rel" ]]; then
    mkdir -p "$OUTER/$rel"
    cp -R "$SRC/$rel/." "$OUTER/$rel/"
    green "  ✓ $label"
  else
    yellow "  ! source missing $rel — skipped"
  fi
}

copy_tree ".claude/skills"  ".claude/skills/"
copy_tree ".claude/agents"  ".claude/agents/"
copy_tree ".claude/hooks"   ".claude/hooks/"

# statusline (single file)
if [[ -f "$SRC/.claude/statusline.sh" ]]; then
  mkdir -p "$OUTER/.claude"
  cp "$SRC/.claude/statusline.sh" "$OUTER/.claude/statusline.sh"
  chmod +x "$OUTER/.claude/statusline.sh" 2>/dev/null || true
  green "  ✓ .claude/statusline.sh"
fi
# make hooks executable
if [[ -d "$OUTER/.claude/hooks" ]]; then
  find "$OUTER/.claude/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi

# .knowledge (with lessons.md)
copy_tree ".knowledge" ".knowledge/ (lessons.md)"

# ephemeral run-state dir (in the OUTER folder — this is where loop-state lives)
mkdir -p "$OUTER/.claude/forge"
: > "$OUTER/.claude/forge/.gitkeep"
green "  ✓ .claude/forge/ (run-state)"

# ─── fill CLAUDE.md / CONTEXT.md in the OUTER folder (never overwrite) ─────────
fill_doc() {  # fill_doc <template-relpath> <target-filename>
  local tpl="$SRC/$1" out="$OUTER/$2"
  [[ -f "$tpl" ]] || { yellow "  ! source missing $1 — skipped"; return; }
  if [[ -f "$out" ]]; then
    yellow "  ! $2 already exists — left untouched"
    return
  fi
  PN="$PROJECT_NAME" POL="$PROJECT_ONE_LINER" AD="$APP_DIR_NAME" RS="$REPO_SLUG" \
  awk '
    { line=$0
      gsub(/\{\{PROJECT_NAME\}\}/,      ENVIRON["PN"],  line)
      gsub(/\{\{PROJECT_ONE_LINER\}\}/, ENVIRON["POL"], line)
      gsub(/\{\{APP_DIR\}\}/,           ENVIRON["AD"],  line)
      gsub(/\{\{REPO_SLUG\}\}/,         ENVIRON["RS"],  line)
      print line
    }' "$tpl" > "$out"
  green "  ✓ $2 (filled from template)"
}
fill_doc "templates/CLAUDE.md"  "CLAUDE.md"
fill_doc "templates/CONTEXT.md" "CONTEXT.md"

# ─── 2. scaffold the app repo and push it to GitHub ───────────────────────────
echo
bold "Scaffolding the app repo (./$APP_DIR_NAME)…"

mkdir -p "$APP_DIR/.github/workflows"

# starter README
cat > "$APP_DIR/README.md" <<EOF
# $PROJECT_NAME

$PROJECT_ONE_LINER

> Built with [The Forge Evolved](https://github.com/NaNathan13/the-forge-evolved).
> Work is planned and built from the parent folder via \`/ponder → /inscribe → /forge\`.
EOF
green "  ✓ README.md"

# board sync workflow lives INSIDE the app repo (Actions only run from the repo on GitHub)
if [[ -f "$SRC/templates/sync-board.yml" ]]; then
  cp "$SRC/templates/sync-board.yml" "$APP_DIR/.github/workflows/sync-board.yml"
  green "  ✓ .github/workflows/sync-board.yml"
else
  die "Source missing templates/sync-board.yml — cannot install the board sync workflow."
fi

# the app repo's own .gitignore (forge run-state lives in the OUTER folder, so the
# app repo stays clean — this just covers the usual local noise)
cat > "$APP_DIR/.gitignore" <<'EOF'
.DS_Store
node_modules/
EOF
green "  ✓ .gitignore"

# init, commit, create on GitHub, push
git -C "$APP_DIR" init -q
git -C "$APP_DIR" add -A
# Respect the user's configured git identity; fall back to a neutral one only if none is set
# (a fresh machine with no global user.email would otherwise fail the commit).
COMMIT_IDENT=()
if ! git -C "$APP_DIR" config user.email >/dev/null 2>&1; then
  COMMIT_IDENT=(-c user.name="Forge" -c user.email="forge@local")
fi
# NB: ${arr[@]+"${arr[@]}"} so an empty array doesn't trip `set -u` on bash 3.2 (macOS default).
git -C "$APP_DIR" ${COMMIT_IDENT[@]+"${COMMIT_IDENT[@]}"} commit -q -m "chore: initial scaffold (The Forge Evolved)" \
  || die "Failed to create the initial commit in $APP_DIR."
green "  ✓ git init + initial commit"

bold "Creating GitHub repo $REPO_SLUG ($VISIBILITY) and pushing…"
if gh repo create "$REPO_SLUG" "--$VISIBILITY" \
     --source "$APP_DIR" --remote origin --push >/dev/null 2>&1; then
  green "  ✓ created and pushed $REPO_SLUG"
else
  die "Failed to create/push $REPO_SLUG (gh repo create). Check you can create repos for owner '$OWNER'."
fi

# ─── 3. create the Projects v2 board ──────────────────────────────────────────
echo
bold "Provisioning the GitHub board…"
BOARD_OWNER="$OWNER"
BOARD_TITLE="$PROJECT_NAME — Forge"
STATUS_OPTIONS="Backlog,Ready,Forging,In Review,Done,Needs Human"

PROJECT_NUMBER=""
existing="$(gh project list --owner "$BOARD_OWNER" --format json 2>/dev/null \
  | jq -r --arg t "$BOARD_TITLE" '.projects[]? | select(.title == $t) | .number' \
  | head -n1 || true)"
if [[ -n "$existing" && "$existing" != "null" ]]; then
  PROJECT_NUMBER="$existing"
  yellow "  ! Reusing existing project '$BOARD_TITLE' (number $PROJECT_NUMBER)"
else
  PROJECT_NUMBER="$(gh project create --owner "$BOARD_OWNER" --title "$BOARD_TITLE" \
    --format json -q .number 2>/dev/null || true)"
  [[ -n "$PROJECT_NUMBER" && "$PROJECT_NUMBER" != "null" ]] \
    || die "Failed to create the project board (gh project create). Check that you can create Projects for owner '$BOARD_OWNER'."
  green "  ✓ Created board '$BOARD_TITLE' (number $PROJECT_NUMBER)"
fi

if gh project link "$PROJECT_NUMBER" --owner "$BOARD_OWNER" --repo "$REPO_SLUG" >/dev/null 2>&1; then
  green "  ✓ Linked board to $REPO_SLUG"
else
  yellow "  ! Could not link board to $REPO_SLUG (may already be linked) — continuing"
fi

# A new Projects v2 board ships a built-in "Status" field we can't rebuild via CLI,
# so we create our OWN single-select "Forge Status" carrying the six options in order.
FORGE_FIELD_NAME="Forge Status"
field_json() {
  gh project field-list "$PROJECT_NUMBER" --owner "$BOARD_OWNER" --format json 2>/dev/null || echo '{}'
}
existing_field="$(field_json | jq -r --arg n "$FORGE_FIELD_NAME" \
  '.fields[]? | select(.name == $n) | .id' | head -n1 || true)"
if [[ -n "$existing_field" && "$existing_field" != "null" ]]; then
  yellow "  ! Field '$FORGE_FIELD_NAME' already exists — reusing it"
else
  gh project field-create "$PROJECT_NUMBER" --owner "$BOARD_OWNER" \
    --name "$FORGE_FIELD_NAME" --data-type SINGLE_SELECT \
    --single-select-options "$STATUS_OPTIONS" >/dev/null 2>&1 \
    || die "Failed to create the '$FORGE_FIELD_NAME' single-select field on the board."
  green "  ✓ Created status field '$FORGE_FIELD_NAME' [$STATUS_OPTIONS]"
fi

# Resolve the project node id (needed for the grouping mutation + repo var).
PROJECT_VIEW="$(gh project view "$PROJECT_NUMBER" --owner "$BOARD_OWNER" --format json 2>/dev/null || true)"
PROJECT_ID="$(jq -r '.id // empty' <<<"$PROJECT_VIEW")"
[[ -n "$PROJECT_ID" ]] || die "Could not resolve the project node id (PVT_...) for board number $PROJECT_NUMBER."

# Group the board view by "Forge Status" so the six columns appear (best-effort).
GROUPED_OK=0
# shellcheck disable=SC2016
view_resp="$(gh api graphql -f query='
  query($p: ID!) {
    node(id: $p) { ... on ProjectV2 {
      views(first: 1) { nodes { id } }
    } }
  }' -F p="$PROJECT_ID" 2>/dev/null || true)"
VIEW_ID="$(jq -r '.data.node.views.nodes[0].id // empty' <<<"$view_resp" 2>/dev/null || true)"
GROUP_FIELD_ID="$(field_json | jq -r --arg n "$FORGE_FIELD_NAME" \
  '.fields[]? | select(.name == $n) | .id' | head -n1 || true)"
if [[ -n "$VIEW_ID" && -n "$GROUP_FIELD_ID" && "$GROUP_FIELD_ID" != "null" ]]; then
  # shellcheck disable=SC2016
  grp_resp="$(gh api graphql -f query='
    mutation($v: ID!, $f: ID!) {
      updateProjectV2View(input: { viewId: $v, groupByFields: [$f], layout: BOARD_LAYOUT }) {
        projectV2View { id }
      }
    }' -F v="$VIEW_ID" -F f="$GROUP_FIELD_ID" 2>/dev/null || true)"
  if [[ -n "$grp_resp" ]] \
     && ! jq -e '.errors? | length > 0' <<<"$grp_resp" >/dev/null 2>&1 \
     && [[ -n "$(jq -r '.data.updateProjectV2View.projectV2View.id // empty' <<<"$grp_resp" 2>/dev/null)" ]]; then
    GROUPED_OK=1
    green "  ✓ Grouped the board view by '$FORGE_FIELD_NAME' (columns should appear)"
  fi
fi
if [[ "$GROUPED_OK" -ne 1 ]]; then
  yellow "  ⚠ One-time UI step needed: open the board → the board/Kanban view →"
  yellow "    'Group by' → select '$FORGE_FIELD_NAME' so the six columns appear."
fi

# ─── 4. create labels (idempotent via --force) ────────────────────────────────
echo
bold "Creating Forge labels…"
make_label() {  # make_label <name> <color-hex> <description>
  if gh label create "$1" --color "$2" --description "$3" --force --repo "$REPO_SLUG" >/dev/null 2>&1; then
    green "  ✓ label $1"
  else
    yellow "  ! could not create/update label '$1' — continuing"
  fi
}
make_label "status:ready"       "0e8a16" "Queued for the forge loop"
make_label "status:forging"     "fbca04" "A builder is implementing this issue"
make_label "status:in-review"   "1d76db" "Under read-only adversarial review"
make_label "status:done"        "5319e7" "Merged and verified"
make_label "status:needs-human" "b60205" "Escalated — needs a human"
make_label "verify:test"        "c2e0c6" "Gated by tests + type-check + lint"
make_label "verify:visual"      "bfdadc" "Gated by a render/screenshot review"
make_label "needs-reslice"      "d93f0b" "Outgrew a single context window — reslice"
make_label "review-failed"      "e11d21" "Failed review after max rounds"

# ─── 5. resolve IDs and wire repo variables ───────────────────────────────────
echo
bold "Resolving board IDs and wiring repo variables…"

FIELDS_JSON="$(field_json)"
FORGE_STATUS_FIELD_ID="$(jq -r --arg n "$FORGE_FIELD_NAME" \
  '.fields[]? | select(.name == $n) | .id' <<<"$FIELDS_JSON" | head -n1)"
[[ -n "$FORGE_STATUS_FIELD_ID" && "$FORGE_STATUS_FIELD_ID" != "null" ]] \
  || die "Could not resolve the '$FORGE_FIELD_NAME' field id."

opt_id() {  # opt_id <option-name>
  jq -r --arg f "$FORGE_FIELD_NAME" --arg o "$1" \
    '.fields[]? | select(.name == $f) | .options[]? | select(.name == $o) | .id' \
    <<<"$FIELDS_JSON" | head -n1
}
OPT_READY="$(opt_id "Ready")"
OPT_FORGING="$(opt_id "Forging")"
OPT_IN_REVIEW="$(opt_id "In Review")"
OPT_DONE="$(opt_id "Done")"
OPT_NEEDS_HUMAN="$(opt_id "Needs Human")"

for pair in "Ready:$OPT_READY" "Forging:$OPT_FORGING" "In Review:$OPT_IN_REVIEW" \
            "Done:$OPT_DONE" "Needs Human:$OPT_NEEDS_HUMAN"; do
  name="${pair%%:*}"; val="${pair#*:}"
  [[ -n "$val" && "$val" != "null" ]] || die "Could not resolve option id for '$name' on field '$FORGE_FIELD_NAME'."
done

set_var() {  # set_var <NAME> <VALUE>
  if gh variable set "$1" --repo "$REPO_SLUG" --body "$2" >/dev/null 2>&1; then
    green "  ✓ var $1"
  else
    die "Failed to set repo variable $1 on $REPO_SLUG."
  fi
}
set_var FORGE_PROJECT_ID       "$PROJECT_ID"
set_var FORGE_STATUS_FIELD_ID  "$FORGE_STATUS_FIELD_ID"
set_var FORGE_OPT_READY        "$OPT_READY"
set_var FORGE_OPT_FORGING      "$OPT_FORGING"
set_var FORGE_OPT_IN_REVIEW    "$OPT_IN_REVIEW"
set_var FORGE_OPT_DONE         "$OPT_DONE"
set_var FORGE_OPT_NEEDS_HUMAN  "$OPT_NEEDS_HUMAN"

# ── the PAT secret (FORGE_PROJECT_PAT) ───────────────────────────────────────
echo
bold "Setting the Projects PAT secret (FORGE_PROJECT_PAT)…"
echo   "  The sync workflow authenticates to Projects v2 with a CLASSIC PAT" >&2
echo   "  (scope 'project'; add 'repo' for private repos). The Actions" >&2
echo   "  GITHUB_TOKEN cannot touch Projects v2, and fine-grained PATs do not" >&2
echo   "  support Projects v2 — it MUST be a classic PAT." >&2
echo   "  Create one at: https://github.com/settings/tokens (Tokens classic)." >&2
echo >&2
PAT_VALUE=""
if [[ -e /dev/tty ]]; then
  printf '%sPaste the classic PAT now (input hidden), or press Enter to skip: %s' "$BOLD" "$N" > /dev/tty
  read -rs PAT_VALUE < /dev/tty || true
  printf '\n' > /dev/tty
fi
if [[ -n "$PAT_VALUE" ]]; then
  if printf '%s' "$PAT_VALUE" | gh secret set FORGE_PROJECT_PAT --repo "$REPO_SLUG" >/dev/null 2>&1; then
    green "  ✓ secret FORGE_PROJECT_PAT set"
  else
    yellow "  ! Failed to set FORGE_PROJECT_PAT — set it manually (see below)"
    PAT_VALUE=""
  fi
fi
if [[ -z "$PAT_VALUE" ]]; then
  yellow "  ! FORGE_PROJECT_PAT not set. The board sync workflow will NOT run until you set it:"
  echo   "      gh secret set FORGE_PROJECT_PAT --repo $REPO_SLUG   # paste the classic PAT" >&2
fi
unset PAT_VALUE

# ─── 6. write the forge config the skills read (APP_DIR + REPO_SLUG) ──────────
echo
bold "Writing .claude/forge/config…"
cat > "$OUTER/.claude/forge/config" <<EOF
# Written by light-the-forge.sh — read by the forge skills (/forge, /inscribe, /scrub).
# Paths are relative to this OUTER project folder (where you launch Claude Code).
# All git operations target the app repo; all gh operations target the GitHub repo.
APP_DIR="$APP_DIR_NAME"
REPO_SLUG="$REPO_SLUG"
BOARD_OWNER="$BOARD_OWNER"
PROJECT_NUMBER="$PROJECT_NUMBER"
EOF
green "  ✓ .claude/forge/config (APP_DIR=$APP_DIR_NAME, REPO_SLUG=$REPO_SLUG)"

# ─── 7. write the seed for /ponder (description + optional research note) ─────
bold "Writing .claude/forge/seed.md…"
{
  printf '# Initial idea — %s\n\n' "$PROJECT_NAME"
  printf '%s\n\n' "$PROJECT_ONE_LINER"
  if [[ "$DO_RESEARCH" =~ ^(y|Y|yes|YES)$ ]]; then
    printf '## Research first\n\n'
    if [[ -n "$RESEARCH_NOTE" ]]; then
      printf '%s\n' "$RESEARCH_NOTE"
    else
      printf 'Yes — look at prior art and best practices before shaping the build.\n'
    fi
    printf '\n'
  fi
  printf '<!-- /ponder reads this on first run, then retires it. Delete once the idea is underway. -->\n'
} > "$OUTER/.claude/forge/seed.md"
green "  ✓ .claude/forge/seed.md"

# ─── 8. register statusline + ctx-gate hook in OUTER settings.json ────────────
echo
bold "Registering statusline + ctx-gate hook in .claude/settings.json…"
SETTINGS="$OUTER/.claude/settings.json"
mkdir -p "$OUTER/.claude"

read -r -d '' FORGE_SETTINGS <<'JSON' || true
{
  "statusLine": { "type": "command", "command": ".claude/statusline.sh" },
  "hooks": {
    "PreToolUse": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": ".claude/hooks/ctx-gate.sh" } ] }
    ]
  }
}
JSON

if [[ -f "$SETTINGS" ]]; then
  if jq -e . "$SETTINGS" >/dev/null 2>&1; then
    had_statusline=0
    jq -e 'has("statusLine")' "$SETTINGS" >/dev/null 2>&1 && had_statusline=1
    tmp="$(mktemp)"
    if jq '
          ($statusline_cmd) as $sl
        | ($ctxgate_cmd)    as $cg
        | (if has("statusLine") then .
           else .statusLine = {"type":"command","command":$sl} end)
        | .hooks = (.hooks // {})
        | .hooks.PreToolUse = (.hooks.PreToolUse // [])
        | (if [ .hooks.PreToolUse[]?.hooks[]?.command ] | any(. == $cg)
             then .
           else .hooks.PreToolUse += [ {"matcher":"*","hooks":[{"type":"command","command":$cg}]} ]
           end)
        ' \
        --arg statusline_cmd ".claude/statusline.sh" \
        --arg ctxgate_cmd ".claude/hooks/ctx-gate.sh" \
        "$SETTINGS" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$SETTINGS"
      if [[ "$had_statusline" -eq 1 ]]; then
        green  "  ✓ appended ctx-gate PreToolUse hook to existing settings.json"
        yellow "    (kept your existing statusLine — verify it shows the context gauge)"
      else
        green "  ✓ merged statusline + ctx-gate hook into existing settings.json"
      fi
    else
      rm -f "$tmp"
      yellow "  ! Could not merge settings.json automatically. Add these keys manually:"
      printf '%s\n' "$FORGE_SETTINGS" >&2
    fi
  else
    yellow "  ! Existing .claude/settings.json is not valid JSON — left untouched. Add manually:"
    printf '%s\n' "$FORGE_SETTINGS" >&2
  fi
else
  printf '%s\n' "$FORGE_SETTINGS" > "$SETTINGS"
  green "  ✓ wrote .claude/settings.json (statusline + ctx-gate hook)"
fi

# ─── 9. summary ────────────────────────────────────────────────────────────────
BOARD_URL="$(jq -r '.url // empty' <<<"$PROJECT_VIEW")"
REPO_URL_HTTPS="https://github.com/$REPO_SLUG"
echo
bold "The Forge is lit."
echo
printf '%s\n' "${DIM}  Project folder: $OUTER${N}"
printf '%s\n' "${DIM}  App repo:       $REPO_SLUG ($VISIBILITY)  →  ${REPO_URL_HTTPS}${N}"
printf '%s\n' "${DIM}  App folder:     ./$APP_DIR_NAME${N}"
printf '%s\n' "${DIM}  Board:          ${BOARD_URL:-(number $PROJECT_NUMBER, owner $BOARD_OWNER)}${N}"
printf '%s\n' "${DIM}  Board field:    $FORGE_FIELD_NAME [$STATUS_OPTIONS]${N}"
echo
echo "  Outer folder (forge tooling, not pushed):"
echo "    .claude/skills, agents, hooks, statusline.sh, forge/{config,seed.md,run-state},"
echo "    .knowledge/lessons.md, CLAUDE.md, CONTEXT.md"
echo "  App repo (on GitHub):"
echo "    README.md, .gitignore, .github/workflows/sync-board.yml"
echo "  Labels:     status:{ready,forging,in-review,done,needs-human},"
echo "              verify:{test,visual}, needs-reslice, review-failed"
echo "  Variables:  FORGE_PROJECT_ID, FORGE_STATUS_FIELD_ID,"
echo "              FORGE_OPT_{READY,FORGING,IN_REVIEW,DONE,NEEDS_HUMAN}"
echo "  Secret:     FORGE_PROJECT_PAT (classic PAT for the sync workflow)"
echo
if [[ "${GROUPED_OK:-0}" -ne 1 ]]; then
  yellow "  ⚠ One-time UI step: open the board → the board/Kanban view → 'Group by' →"
  yellow "    select '$FORGE_FIELD_NAME' so the six columns appear."
  echo
fi
echo "  Next: open this folder in Claude Code and run  /ponder"
echo "        ($OUTER)"
echo

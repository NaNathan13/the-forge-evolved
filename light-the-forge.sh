#!/usr/bin/env bash
# light-the-forge.sh — stand up The Forge Evolved on a target repo, in one run.
#
# Installs the Claude Code kit (skills/agents/hooks/statusline/knowledge),
# fills the project templates, then provisions the GitHub side: a Projects v2
# board with the six Forge columns, the Forge label set, the labels->board sync
# workflow, and the repo variables + PAT secret that workflow reads.
#
# Usage:
#   # From a local checkout of the-forge-evolved (preferred):
#   ./light-the-forge.sh                 # install into current working dir
#   ./light-the-forge.sh <target-dir>    # install into the named dir
#
#   # One-liner (self-fetches the kit — repo URL is a PLACEHOLDER until publish):
#   curl -fsSL https://raw.githubusercontent.com/OWNER/the-forge-evolved/main/light-the-forge.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/OWNER/the-forge-evolved/main/light-the-forge.sh | bash -s -- <target-dir>
#
# Requirements: gh (authenticated, with `project` scope), git, jq, a target
# directory that is a GitHub repo (has an `origin` remote / `gh repo view` works).
#
# The script is idempotent where it can be: re-running won't clobber existing
# project docs, duplicate labels, or break an existing settings.json.

set -euo pipefail

# PLACEHOLDER repo URL — the-forge-evolved is not yet published. Update OWNER
# (and repo name if it changes) before relying on the curl|bash self-fetch path.
REPO_URL="https://github.com/OWNER/the-forge-evolved.git"

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
  case "$REPO_URL" in
    *OWNER/the-forge-evolved*)
      die "Not running from a the-forge-evolved checkout, and the self-fetch repo URL is still a PLACEHOLDER ($REPO_URL). Clone the repo and run ./light-the-forge.sh from inside it." ;;
  esac
  CLONE_DIR="$(mktemp -d)"
  trap 'rm -rf "$CLONE_DIR"' EXIT
  bold "Fetching The Forge Evolved…"
  git clone --depth 1 --quiet "$REPO_URL" "$CLONE_DIR" || die "Failed to clone $REPO_URL"
  SRC="$CLONE_DIR"
fi

# ─── resolve target ───────────────────────────────────────────────────────────
TARGET="${1:-$(pwd)}"
[[ -d "$TARGET" ]] || die "Target directory does not exist: $TARGET"
TARGET="$(cd -P "$TARGET" && pwd)"

if [[ "$SRC" == "$TARGET" ]]; then
  die "Source and target are the same directory ($SRC). Run from outside the kit, or pass a different target."
fi

bold "The Forge Evolved — installer"
printf '  Source: %s\n  Target: %s\n\n' "$SRC" "$TARGET"

# ─── resolve the GitHub repo for the target ───────────────────────────────────
# Prefer `gh repo view` run inside the target dir (honors its origin remote).
REPO_SLUG="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null \
  || (cd "$TARGET" && gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null) \
  || true)"
if [[ -z "$REPO_SLUG" ]]; then
  die "Could not resolve the GitHub repo for the target.
  The target must be a git repo with a GitHub 'origin' remote (so 'gh repo view' works).
  cd into the target's repo, push it to GitHub, then re-run."
fi
green "  ✓ Target repo: $REPO_SLUG"

# ─── 1. setup questions ───────────────────────────────────────────────────────
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

echo
bold "Setup questions"
default_owner="${REPO_SLUG%%/*}"
default_name="${REPO_SLUG##*/}"
ask PROJECT_NAME       "Project name"                                   "$default_name"
ask PROJECT_ONE_LINER  "One-line description"                           "A project built with The Forge Evolved."
ask TEST_CMD           "Test command (blank if N/A)"                    ""
ask TYPECHECK_CMD      "Type-check command (blank if N/A)"              ""
ask LINT_CMD           "Lint command (blank if N/A)"                    ""
ask BOARD_OWNER        "Board owner (GitHub user or org login)"         "$default_owner"

echo
cyan "  Project:     $PROJECT_NAME"
cyan "  One-liner:   $PROJECT_ONE_LINER"
cyan "  Test:        ${TEST_CMD:-<none>}"
cyan "  Type-check:  ${TYPECHECK_CMD:-<none>}"
cyan "  Lint:        ${LINT_CMD:-<none>}"
cyan "  Board owner: $BOARD_OWNER"
echo

# ─── 2. auth gate: require `project` scope ────────────────────────────────────
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
  yellow "  Fix it:  gh auth refresh -s project"
  echo   "" >&2
  echo   "  NOTE: a CLASSIC PAT with the 'project' scope is what the sync workflow" >&2
  echo   "        needs at runtime. Fine-grained PATs do NOT support Projects v2," >&2
  echo   "        and the Actions GITHUB_TOKEN cannot touch Projects v2 at all." >&2
  echo   "        (This auth check is for THIS install step; step 6 sets the PAT secret.)" >&2
  exit 1
fi
green "  ✓ gh is authenticated and has the 'project' scope"

# ─── 3. copy the kit into the target ──────────────────────────────────────────
echo
bold "Installing the kit into the target…"

copy_tree() {  # copy_tree <relpath> [label]
  local rel="$1" label="${2:-$1}"
  if [[ -d "$SRC/$rel" ]]; then
    mkdir -p "$TARGET/$rel"
    cp -R "$SRC/$rel/." "$TARGET/$rel/"
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
  mkdir -p "$TARGET/.claude"
  cp "$SRC/.claude/statusline.sh" "$TARGET/.claude/statusline.sh"
  chmod +x "$TARGET/.claude/statusline.sh" 2>/dev/null || true
  green "  ✓ .claude/statusline.sh"
fi
# make hooks executable
if [[ -d "$TARGET/.claude/hooks" ]]; then
  find "$TARGET/.claude/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi

# .knowledge (with lessons.md)
copy_tree ".knowledge" ".knowledge/ (lessons.md)"

# ephemeral run-state dir
mkdir -p "$TARGET/.claude/forge"
: > "$TARGET/.claude/forge/.gitkeep"
green "  ✓ .claude/forge/ (run-state, gitignored)"

# sync-board workflow — copied AS-IS (IDs are read from repo vars/secret, not
# string-substituted into the file).
if [[ -f "$SRC/templates/sync-board.yml" ]]; then
  mkdir -p "$TARGET/.github/workflows"
  cp "$SRC/templates/sync-board.yml" "$TARGET/.github/workflows/sync-board.yml"
  green "  ✓ .github/workflows/sync-board.yml"
else
  die "Source missing templates/sync-board.yml — cannot install the board sync workflow."
fi

# ─── gitignore the ephemeral run-state ───────────────────────────────────────
GI="$TARGET/.gitignore"
gi_lines=(
  ".claude/settings.local.json"
  ".claude/forge/.ctx"
  ".claude/forge/loop-state"
  ".claude/forge/handoff.md"
)
touch "$GI"
gi_added=0
for line in "${gi_lines[@]}"; do
  if ! grep -qxF "$line" "$GI" 2>/dev/null; then
    printf '%s\n' "$line" >> "$GI"
    gi_added=1
  fi
done
if [[ "$gi_added" -eq 1 ]]; then
  green "  ✓ .gitignore: ensured ephemeral run-state is ignored"
else
  yellow "  ! .gitignore already covers ephemeral run-state"
fi

# ─── fill CLAUDE.md / CONTEXT.md from templates (never overwrite) ─────────────
fill_doc() {  # fill_doc <template-relpath> <target-filename>
  local tpl="$SRC/$1" out="$TARGET/$2"
  [[ -f "$tpl" ]] || { yellow "  ! source missing $1 — skipped"; return; }
  if [[ -f "$out" ]]; then
    yellow "  ! $2 already exists in target — left untouched"
    return
  fi
  # Substitute placeholders. Use awk with literal env values to avoid sed
  # delimiter collisions with arbitrary command strings.
  PN="$PROJECT_NAME" POL="$PROJECT_ONE_LINER" TC="$TEST_CMD" TYC="$TYPECHECK_CMD" LC="$LINT_CMD" \
  awk '
    { line=$0
      gsub(/\{\{PROJECT_NAME\}\}/,      ENVIRON["PN"],  line)
      gsub(/\{\{PROJECT_ONE_LINER\}\}/, ENVIRON["POL"], line)
      gsub(/\{\{TEST_CMD\}\}/,          ENVIRON["TC"],  line)
      gsub(/\{\{TYPECHECK_CMD\}\}/,     ENVIRON["TYC"], line)
      gsub(/\{\{LINT_CMD\}\}/,          ENVIRON["LC"],  line)
      print line
    }' "$tpl" > "$out"
  green "  ✓ $2 (filled from template)"
}
fill_doc "templates/CLAUDE.md"  "CLAUDE.md"
fill_doc "templates/CONTEXT.md" "CONTEXT.md"

# ─── 4. create the Projects v2 board ──────────────────────────────────────────
echo
bold "Provisioning the GitHub board…"

BOARD_TITLE="$PROJECT_NAME — Forge"
STATUS_OPTIONS="Backlog,Ready,Forging,In Review,Done,Needs Human"

# Is a board with this title already linked/owned? (idempotency best-effort)
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

# Link the board to the target repo (idempotent — link of an already-linked
# repo is harmless; tolerate failure with a clear note).
if gh project link "$PROJECT_NUMBER" --owner "$BOARD_OWNER" --repo "$REPO_SLUG" >/dev/null 2>&1; then
  green "  ✓ Linked board to $REPO_SLUG"
else
  yellow "  ! Could not link board to $REPO_SLUG (may already be linked) — continuing"
fi

# ── the built-in-Status-field wrinkle ────────────────────────────────────────
# A new Projects v2 board ships a built-in single-select "Status" field with
# options Todo / In Progress / Done. We cannot rename/replace built-in options
# via the CLI, so we leave that field alone and create our OWN single-select
# field "Forge Status" carrying the six Forge options in order. THAT field is
# the one the sync workflow targets (FORGE_STATUS_FIELD_ID), keeping the install
# deterministic regardless of the built-in field's contents.
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

# ── group the Kanban view by "Forge Status" so the six columns appear ─────────
# A fresh Projects v2 board's default view is NOT grouped by our custom field,
# so the columns are invisible until grouping is set. Attempt it best-effort via
# GraphQL (updateProjectV2View). This is fragile (view ids vary; the API surface
# changes) so it must NEVER fail the install — on any error we fall back to the
# one-time manual instruction printed below.
GROUPED_OK=0
# shellcheck disable=SC2016  # $p is a GraphQL variable (passed via -F), not a shell var
view_resp="$(gh api graphql -f query='
  query($p: ID!) {
    node(id: $p) { ... on ProjectV2 {
      views(first: 1) { nodes { id } }
    } }
  }' -F p="$PROJECT_ID" 2>/dev/null || true)"
VIEW_ID="$(jq -r '.data.node.views.nodes[0].id // empty' <<<"$view_resp" 2>/dev/null || true)"
# resolve the field id now (also resolved again in step 6; harmless)
GROUP_FIELD_ID="$(field_json | jq -r --arg n "$FORGE_FIELD_NAME" \
  '.fields[]? | select(.name == $n) | .id' | head -n1 || true)"
if [[ -n "$VIEW_ID" && -n "$GROUP_FIELD_ID" && "$GROUP_FIELD_ID" != "null" ]]; then
  # shellcheck disable=SC2016  # $v/$f are GraphQL variables (passed via -F), not shell vars
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

# ─── 5. create labels (idempotent via --force) ────────────────────────────────
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

# ─── 6. fetch IDs and wire repo variables ─────────────────────────────────────
echo
bold "Resolving board IDs and wiring repo variables…"

PROJECT_VIEW="$(gh project view "$PROJECT_NUMBER" --owner "$BOARD_OWNER" --format json 2>/dev/null || true)"
PROJECT_ID="$(jq -r '.id // empty' <<<"$PROJECT_VIEW")"
[[ -n "$PROJECT_ID" ]] || die "Could not resolve the project node id (PVT_...) for board number $PROJECT_NUMBER."

# Pull the Forge Status field id + its option ids via the project field-list JSON.
FIELDS_JSON="$(field_json)"
FORGE_STATUS_FIELD_ID="$(jq -r --arg n "$FORGE_FIELD_NAME" \
  '.fields[]? | select(.name == $n) | .id' <<<"$FIELDS_JSON" | head -n1)"
[[ -n "$FORGE_STATUS_FIELD_ID" && "$FORGE_STATUS_FIELD_ID" != "null" ]] \
  || die "Could not resolve the '$FORGE_FIELD_NAME' field id."

opt_id() {  # opt_id <option-name>  — echoes the option id for the Forge Status field
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
if [[ -t 0 ]]; then
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

# ─── 7. register statusline + ctx-gate hook in target settings.json ───────────
echo
bold "Registering statusline + ctx-gate hook in .claude/settings.json…"
SETTINGS="$TARGET/.claude/settings.json"
mkdir -p "$TARGET/.claude"

# The fresh-install file (used verbatim when no settings.json exists yet).
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
  # MERGE additively into existing settings — never clobber the user's content:
  #   - .statusLine: only set if absent (keep theirs if present; warn).
  #   - .hooks.PreToolUse: APPEND our ctx-gate entry to the existing array,
  #     but only if an entry with the same command isn't already there (so a
  #     re-run doesn't stack duplicates). All other hook events + top-level
  #     keys (permissions, …) are preserved untouched.
  if jq -e . "$SETTINGS" >/dev/null 2>&1; then
    had_statusline=0
    jq -e 'has("statusLine")' "$SETTINGS" >/dev/null 2>&1 && had_statusline=1
    tmp="$(mktemp)"
    if jq '
          ($statusline_cmd) as $sl
        | ($ctxgate_cmd)    as $cg
          # statusLine only if absent
        | (if has("statusLine") then .
           else .statusLine = {"type":"command","command":$sl} end)
          # ensure .hooks and .hooks.PreToolUse exist
        | .hooks = (.hooks // {})
        | .hooks.PreToolUse = (.hooks.PreToolUse // [])
          # append our ctx-gate entry only if no existing entry references it
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

# ─── 8. summary ───────────────────────────────────────────────────────────────
BOARD_URL="$(jq -r '.url // empty' <<<"$PROJECT_VIEW")"
echo
bold "The Forge is lit."
echo
printf '%s\n' "${DIM}  Target repo:   $REPO_SLUG${N}"
printf '%s\n' "${DIM}  Install dir:   $TARGET${N}"
printf '%s\n' "${DIM}  Board:         ${BOARD_URL:-(number $PROJECT_NUMBER, owner $BOARD_OWNER)}${N}"
printf '%s\n' "${DIM}  Board field:   $FORGE_FIELD_NAME [$STATUS_OPTIONS]${N}"
echo
echo "  Installed:  .claude/skills, .claude/agents, .claude/hooks, .claude/statusline.sh,"
echo "              .claude/forge/ (run-state), .knowledge/lessons.md,"
echo "              .github/workflows/sync-board.yml, CLAUDE.md, CONTEXT.md"
echo "  Labels:     status:{ready,forging,in-review,done,needs-human},"
echo "              verify:{test,visual}, needs-reslice, review-failed"
echo "  Variables:  FORGE_PROJECT_ID, FORGE_STATUS_FIELD_ID,"
echo "              FORGE_OPT_{READY,FORGING,IN_REVIEW,DONE,NEEDS_HUMAN}"
echo "  Secret:     FORGE_PROJECT_PAT (classic PAT for the sync workflow)"
echo
if [[ "${GROUPED_OK:-0}" -ne 1 ]]; then
  yellow "  ⚠ One-time UI step: open the board → the board/Kanban view → 'Group by' →"
  yellow "    select '$FORGE_FIELD_NAME' so the six columns appear (card values are already set)."
  echo
fi
echo "  Next: open this project in Claude Code and run /ponder"
echo

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
#   └── <name>-app/                 ← a fresh local git repo (your code goes here)
#       ├── .github/workflows/sync-board.yml
#       └── README.md
#
# It installs the local kit and initializes the app repo locally. You set up the
# GitHub side yourself — see docs/github-setup.md for the steps (repo, Projects v2
# board, labels, repo variables, and the FORGE_PROJECT_PAT secret).
#
# Usage:
#   # One-liner (self-fetches the kit), from inside your empty project folder:
#   curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/light-the-forge.sh | bash
#
#   # Or from a local checkout of the-forge-evolved:
#   /path/to/light-the-forge.sh                 # scaffold into the current dir
#   /path/to/light-the-forge.sh <project-dir>   # scaffold into the named (outer) dir
#
# Requirements: git, jq.

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
# git initializes the app repo locally; jq merges settings.json.
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
# Guard the #1 user mistake: cloning the-forge-evolved and running from inside that clone.
# The outer project folder must NOT be a git repo (your code becomes a git repo in <name>-app/).
# If OUTER sits inside a checkout whose origin is the-forge-evolved, abort with a pointer.
if OUTER_TOP="$(git -C "$OUTER" rev-parse --show-toplevel 2>/dev/null)"; then
  OUTER_ORIGIN="$(git -C "$OUTER" remote get-url origin 2>/dev/null || true)"
  if [[ "$OUTER_ORIGIN" == *the-forge-evolved* ]]; then
    die "You're scaffolding inside a clone of The Forge Evolved ($OUTER_TOP).
  Don't clone this repo to use it — the one-liner fetches what it needs on its own.
  Make a NEW, empty folder and run from there:
      mkdir my-project && cd my-project
      curl -fsSL ${REPO_URL%.git}/raw/main/light-the-forge.sh | bash"
  fi
fi

bold "The Forge Evolved — new project scaffold"
printf '  Kit source:     %s\n  Project folder: %s\n\n' "$SRC" "$OUTER"

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

echo
bold "Tell me about the project"
ask PROJECT_NAME       "Project name (proper casing, e.g. Recipe Box)"   ""
[[ -n "$PROJECT_NAME" ]] || die "Project name is required."
# Owner pre-fills the REPO_SLUG/BOARD_OWNER coordinates in .claude/forge/config.
# Leave blank to fill it in later.
ask OWNER              "GitHub owner for the coordinates (optional, user/org)"  ""
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
# Coordinates for .claude/forge/config. With no owner, a placeholder is written
# for you to set when you create the repo (docs/github-setup.md).
if [[ -n "$OWNER" ]]; then
  REPO_SLUG="$OWNER/$SLUG"
  BOARD_OWNER="$OWNER"
else
  REPO_SLUG="<owner>/$SLUG"
  BOARD_OWNER="<owner>"
fi

# ─── confirm ───────────────────────────────────────────────────────────────────
echo
bold "── Confirm ─────────────────────────────────"
cyan  "  Display name : $PROJECT_NAME"
cyan  "  Repo coords  : $REPO_SLUG"
cyan  "  App folder   : ./$APP_DIR_NAME  (local git repo)"
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

# ─── collision check ──────────────────────────────────────────────────────────
echo
bold "Checking for collisions…"
if [[ -e "$APP_DIR" ]]; then
  die "App folder already exists: $APP_DIR
  Refusing to clobber it. Pick a different project name, or remove that folder, then re-run."
fi
green "  ✓ ./$APP_DIR_NAME is free"

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

# ship the manual GitHub-setup guide alongside the kit (so it's there to follow)
if [[ -f "$SRC/docs/github-setup.md" ]]; then
  mkdir -p "$OUTER/docs"
  cp "$SRC/docs/github-setup.md" "$OUTER/docs/github-setup.md"
  green "  ✓ docs/github-setup.md (manual GitHub setup steps)"
fi

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

# ─── 2. scaffold the app repo locally ─────────────────────────────────────────
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

# board sync workflow lives INSIDE the app repo (Actions run from the repo on GitHub).
# Installed now so it's ready once the repo and board are set up (docs/github-setup.md).
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

# init + initial commit, locally.
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
green "  ✓ git init + initial commit (local)"

# ─── 3. write the forge config the skills read (APP_DIR + REPO_SLUG) ──────────
echo
bold "Writing .claude/forge/config…"
cat > "$OUTER/.claude/forge/config" <<EOF
# Written by light-the-forge.sh — read by the forge skills (/forge, /inscribe, /scrub).
# Paths are relative to this OUTER project folder (where you launch Claude Code).
# All git operations target the app repo; all gh operations target the GitHub repo.
#
# After you create the repo + Projects board (docs/github-setup.md), confirm
# REPO_SLUG/BOARD_OWNER below and fill in PROJECT_NUMBER — the forge skills read
# these to find and move issues on the board.
APP_DIR="$APP_DIR_NAME"
REPO_SLUG="$REPO_SLUG"
BOARD_OWNER="$BOARD_OWNER"
PROJECT_NUMBER=""   # TODO: set to your Projects v2 board number (docs/github-setup.md)
EOF
green "  ✓ .claude/forge/config (APP_DIR=$APP_DIR_NAME, REPO_SLUG=$REPO_SLUG)"

# ─── 4. write the seed for /ponder (description + optional research note) ─────
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

# ─── 5. register statusline + ctx-gate hook in OUTER settings.json ────────────
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

# ─── 6. summary ────────────────────────────────────────────────────────────────
echo
bold "The kit is installed."
echo
printf '%s\n' "${DIM}  Project folder: $OUTER${N}"
printf '%s\n' "${DIM}  App folder:     ./$APP_DIR_NAME  (local git repo)${N}"
printf '%s\n' "${DIM}  Repo coords:    $REPO_SLUG  (in .claude/forge/config)${N}"
echo
echo "  Outer folder (forge tooling):"
echo "    .claude/skills, agents, hooks, statusline.sh, forge/{config,seed.md,run-state},"
echo "    .knowledge/lessons.md, CLAUDE.md, CONTEXT.md, docs/github-setup.md"
echo "  App repo (local):"
echo "    README.md, .gitignore, .github/workflows/sync-board.yml"
echo
bold "  Next — set up the GitHub side (docs/github-setup.md):"
echo   "    • create the repo and push ./$APP_DIR_NAME"
echo   "    • create the Projects v2 board (six Forge columns) + the label set"
echo   "    • set the repo variables (FORGE_PROJECT_ID, FORGE_STATUS_FIELD_ID, FORGE_OPT_*)"
echo   "    • set the FORGE_PROJECT_PAT secret (classic PAT, 'project' scope)"
echo   "    • fill PROJECT_NUMBER (and confirm REPO_SLUG/BOARD_OWNER) in .claude/forge/config"
echo
echo "  Then: open this folder in Claude Code and run  /ponder"
echo "        ($OUTER)"
echo

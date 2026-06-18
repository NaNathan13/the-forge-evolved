#!/usr/bin/env bash
# light-the-forge.sh — scaffold a brand-new Forge project, in one run.
#
# Run this from inside an empty (or nearly empty) PROJECT FOLDER. It asks a few
# questions, then stands up the SINGLE repo The Forge expects — code, the
# `.claude/` kit, and the `.forge/` build state all in ONE git repo:
#
#   project/                  ← you run this here; git init HERE; Claude Code opens HERE
#   ├── .claude/              skills, agents, hooks, statusline.sh, settings.json   (kit-owned)
#   ├── .knowledge/lessons.md (promoted durable codebase facts)
#   ├── .forge/               ALL build state (project-owned; never touched by forge-update)
#   │   ├── config            deploy + PM-hub coordinates
#   │   ├── seed.md           original-idea record (/prospect reads it)
#   │   ├── tasks/            the file-based queue (one file per task)
#   │   ├── research/         findings (projected to the PM hub if present)
#   │   ├── continue.md       continuity journal (Now / Next / Friction)
#   │   └── needs-human.md    escalation surface
#   ├── CLAUDE.md  CONTEXT.md
#   ├── .gitignore
#   └── README.md
#
# No GitHub. No split outer/app layout. No board/labels/PAT. Local `.forge/`
# files are the source of truth; the PM hub is an optional projection.
#
# Usage:
#   # One-liner (self-fetches the kit), from inside your empty project folder:
#   curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/light-the-forge.sh | bash
#
#   # Or from a local checkout of the-forge:
#   /path/to/light-the-forge.sh                 # scaffold into the current dir
#   /path/to/light-the-forge.sh <project-dir>   # scaffold into the named dir
#
# Requirements: git, jq.

set -euo pipefail

# Real published location of the kit (used by the curl|bash self-fetch path).
REPO_URL="https://github.com/NaNathan13/the-forge.git"

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
# git inits the single repo; jq merges settings.json.
command -v git >/dev/null 2>&1 || die "git is required and not on PATH."
command -v jq  >/dev/null 2>&1 || die "jq is required and not on PATH. Install: https://jqlang.github.io/jq/"

# ─── self-bootstrap: clone the kit if we're not running from a checkout ───────
is_forge_checkout() {
  [[ -n "$SRC" && -f "$SRC/light-the-forge.sh" && -d "$SRC/templates" && -d "$SRC/.claude/skills" ]]
}
if ! is_forge_checkout; then
  CLONE_DIR="$(mktemp -d)"
  trap 'rm -rf "$CLONE_DIR"' EXIT
  bold "Fetching The Forge…"
  git clone --depth 1 --quiet "$REPO_URL" "$CLONE_DIR" || die "Failed to clone $REPO_URL"
  SRC="$CLONE_DIR"
fi

# ─── resolve the project folder (the ONE repo; Claude Code runs here) ─────────
DIR="${1:-$(pwd)}"
[[ -d "$DIR" ]] || die "Project directory does not exist: $DIR"
DIR="$(cd -P "$DIR" && pwd)"
if [[ "$SRC" == "$DIR" ]]; then
  die "You're running this from inside the the-forge checkout itself. Run it from a NEW, empty project folder (or pass one as an argument)."
fi
# Guard the #1 mistake: cloning the-forge and running from inside that clone.
if DIR_ORIGIN="$(git -C "$DIR" remote get-url origin 2>/dev/null)"; then
  if [[ "$DIR_ORIGIN" == *the-forge* && "$DIR_ORIGIN" != *the-forge-* ]]; then
    die "You're scaffolding inside a clone of The Forge itself.
  Don't clone this repo to use it — the one-liner fetches what it needs on its own.
  Make a NEW, empty folder and run from there:
      mkdir my-project && cd my-project
      curl -fsSL ${REPO_URL%.git}/raw/main/light-the-forge.sh | bash"
  fi
fi
# A pre-existing repo here is fine (the kit can be added to an existing project),
# but warn so an accidental re-run is obvious.
if [[ -d "$DIR/.forge" ]]; then
  die "This folder already has a .forge/ — it looks forged already. Refusing to clobber it."
fi

bold "The Forge — new project scaffold"
printf '  Kit source:     %s\n  Project folder: %s\n\n' "$SRC" "$DIR"

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
ask PROJECT_ONE_LINER  "One-line description of what you're building"    "A project built with The Forge."
# Deploy tier — the homelab docker network this app attaches to (decision 2 / config).
ask DEPLOY_TYPE        "Deploy type — public | internal"                 "internal"
case "$DEPLOY_TYPE" in
  public|internal) ;;
  *) die "Deploy type must be 'public' or 'internal' (got '$DEPLOY_TYPE')." ;;
esac
ask DO_RESEARCH        "Kick off initial research before building? (y/N)" "N"
RESEARCH_NOTE=""
case "$DO_RESEARCH" in
  y|Y|yes|YES)
    ask RESEARCH_NOTE  "  What should /prospect research first?"         ""
    ;;
esac

# ─── derive names ─────────────────────────────────────────────────────────────
SLUG="$(slugify "$PROJECT_NAME")"
[[ -n "$SLUG" ]] || die "Could not derive a slug from '$PROJECT_NAME'. Use letters/numbers."

# ─── confirm ───────────────────────────────────────────────────────────────────
echo
bold "── Confirm ─────────────────────────────────"
cyan  "  Display name : $PROJECT_NAME"
cyan  "  Slug         : $SLUG"
cyan  "  Repo         : ./  (single git repo — code + .claude + .forge)"
cyan  "  Deploy type  : $DEPLOY_TYPE"
cyan  "  Description  : $PROJECT_ONE_LINER"
if [[ -n "$RESEARCH_NOTE" ]]; then
  cyan "  Research     : $RESEARCH_NOTE"
elif [[ "$DO_RESEARCH" =~ ^(y|Y|yes|YES)$ ]]; then
  cyan "  Research     : (yes — /prospect researches before you ponder)"
else
  cyan "  Research     : (none)"
fi
echo
ask CONFIRM "Proceed? (Y/n)" "Y"
case "$CONFIRM" in
  n|N|no|NO) die "Aborted — nothing was created." ;;
esac

# ─── 1. install the forge kit (.claude/, .knowledge/) ─────────────────────────
echo
bold "Installing the forge kit…"

copy_tree() {  # copy_tree <relpath> [label]
  local rel="$1" label="${2:-$1}"
  if [[ -d "$SRC/$rel" ]]; then
    mkdir -p "$DIR/$rel"
    cp -R "$SRC/$rel/." "$DIR/$rel/"
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
  mkdir -p "$DIR/.claude"
  cp "$SRC/.claude/statusline.sh" "$DIR/.claude/statusline.sh"
  chmod +x "$DIR/.claude/statusline.sh" 2>/dev/null || true
  green "  ✓ .claude/statusline.sh"
fi
# make hooks executable
if [[ -d "$DIR/.claude/hooks" ]]; then
  find "$DIR/.claude/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
fi

# .knowledge (with empty lessons.md)
copy_tree ".knowledge" ".knowledge/ (lessons.md)"

# ─── 2. scaffold the .forge/ state tree ───────────────────────────────────────
echo
bold "Scaffolding .forge/ (build state)…"
mkdir -p "$DIR/.forge/tasks" "$DIR/.forge/research"
: > "$DIR/.forge/tasks/.gitkeep"
: > "$DIR/.forge/research/.gitkeep"
green "  ✓ .forge/tasks/  .forge/research/"

# .forge/config — the single source the deploy/projection steps read.
cat > "$DIR/.forge/config" <<EOF
# .forge/config — written by light-the-forge.sh; read by /forge (deploy + PM-hub projection).
# Single repo: all git runs at repo root (bare \`git\`, no -C). Paths are repo-relative or absolute.
DEPLOY_TYPE="$DEPLOY_TYPE"   # public | internal      (homelab docker tier)
STACK_DIR=""                 # TODO: path to this app's compose stack (set once the stack exists)
CONTAINER_PORT=""            # TODO: port the health-check / UAT smoke hits
PM_SLUG=""                   # PM hub project slug      (optional projection; set if/when projecting)
PM_HUB_DIR="\$HOME/homelab/project-management/data"   # PM hub data repo (projection degrades to local files if absent)
EOF
green "  ✓ .forge/config (DEPLOY_TYPE=$DEPLOY_TYPE)"

# .forge/seed.md — the original-idea record /prospect reads.
{
  printf '%s\n' '---' 'status: todo' '---' ''
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
  printf '<!-- /prospect reads this on first run and flips status to done (it does not delete it).\n'
  printf '     /ponder falls back to this if /prospect was skipped. Keep it as the original-idea record. -->\n'
} > "$DIR/.forge/seed.md"
green "  ✓ .forge/seed.md"

# .forge/continue.md — the continuity journal skeleton (agent-authored from here on).
cat > "$DIR/.forge/continue.md" <<EOF
# Continue — $PROJECT_NAME

## Now
<!-- overwritten live: active command, cursor mirror, branch -->
(nothing in flight)

## Next
<!-- overwritten: the single next action -->
Run /prospect to warm the idea, then /ponder → /inscribe → /forge.

## Friction
<!-- rolling ~5 bullets: soft "this approach kept failing" memory. A note that proves durable
     gets promoted to .knowledge/lessons.md, then dropped from here. -->
(none yet)
EOF
green "  ✓ .forge/continue.md"

# .forge/needs-human.md — the escalation surface.
cat > "$DIR/.forge/needs-human.md" <<EOF
# Needs human — $PROJECT_NAME

<!-- /forge appends a line here when a task escalates (status: needs-human). Each line:
     - [ ] #NNN <reason>: <one-line summary>. Recover: <fix>, set status: ready, re-run /forge. -->

(nothing needed)
EOF
green "  ✓ .forge/needs-human.md"

# ─── 3. fill CLAUDE.md / CONTEXT.md from templates (never overwrite) ──────────
echo
bold "Writing CLAUDE.md / CONTEXT.md…"
fill_doc() {  # fill_doc <template-relpath> <target-filename>
  local tpl="$SRC/$1" out="$DIR/$2"
  [[ -f "$tpl" ]] || { yellow "  ! source missing $1 — skipped"; return; }
  if [[ -f "$out" ]]; then
    yellow "  ! $2 already exists — left untouched"
    return
  fi
  PN="$PROJECT_NAME" POL="$PROJECT_ONE_LINER" SL="$SLUG" DT="$DEPLOY_TYPE" \
  awk '
    { line=$0
      gsub(/\{\{PROJECT_NAME\}\}/,      ENVIRON["PN"],  line)
      gsub(/\{\{PROJECT_ONE_LINER\}\}/, ENVIRON["POL"], line)
      gsub(/\{\{SLUG\}\}/,              ENVIRON["SL"],  line)
      gsub(/\{\{DEPLOY_TYPE\}\}/,       ENVIRON["DT"],  line)
      print line
    }' "$tpl" > "$out"
  green "  ✓ $2 (filled from template)"
}
fill_doc "templates/CLAUDE.md"  "CLAUDE.md"
fill_doc "templates/CONTEXT.md" "CONTEXT.md"

# ─── 4. .gitignore + README ───────────────────────────────────────────────────
if [[ ! -f "$DIR/.gitignore" ]]; then
  cat > "$DIR/.gitignore" <<'EOF'
# ── .forge/ ephemeral run-state (never committed — a mid-run interruption must
#    never leave committed state lying about a task) ──
.forge/run-state
.forge/.ctx
.forge/envision.md
.forge/hook-probe.log
# ── local noise ──
.claude/settings.local.json
node_modules/
.DS_Store
.playwright-mcp/
EOF
  green "  ✓ .gitignore"
else
  yellow "  ! .gitignore already exists — left untouched"
fi

if [[ ! -f "$DIR/README.md" ]]; then
  cat > "$DIR/README.md" <<EOF
# $PROJECT_NAME

$PROJECT_ONE_LINER

> Built with [The Forge](https://github.com/NaNathan13/the-forge). One repo holds the code, the
> \`.claude/\` build kit, and the \`.forge/\` state. Plan and build via \`/prospect → /ponder →
> /inscribe → /forge\`.
EOF
  green "  ✓ README.md"
else
  yellow "  ! README.md already exists — left untouched"
fi

# ─── 5. register settings.json (statusline + ctx-gate + continuity hooks) ─────
echo
bold "Registering .claude/settings.json…"
SETTINGS="$DIR/.claude/settings.json"
mkdir -p "$DIR/.claude"

# The canonical Forge settings. ctx-gate enforces the 40-warn/50-deny rule. The continuity hooks are wired
# (the SessionStart/Stop hook-firing probe passed 2026-06-18): SessionStart injects .forge/continue.md,
# PreCompact/Stop auto-commit it (Stop guarded so no-op turns never commit). PreCompact is untested but
# harmless — it only fires on a compaction the 40/50 rule avoids. _probe.sh ships as an optional diagnostic.
read -r -d '' FORGE_SETTINGS <<'JSON' || true
{
  "statusLine": { "type": "command", "command": ".claude/statusline.sh" },
  "hooks": {
    "PreToolUse": [
      { "matcher": "*", "hooks": [ { "type": "command", "command": ".claude/hooks/ctx-gate.sh" } ] }
    ],
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": ".claude/hooks/continuity-inject.sh" } ] }
    ],
    "PreCompact": [
      { "hooks": [ { "type": "command", "command": ".claude/hooks/continuity-commit.sh" } ] }
    ],
    "Stop": [
      { "hooks": [ { "type": "command", "command": ".claude/hooks/continuity-commit.sh" } ] }
    ]
  },
  "permissions": {
    "allow": [
      "Bash(git status:*)",
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git branch:*)",
      "Bash(git show:*)",
      "Bash(git rev-parse:*)",
      "Bash(git ls-files:*)",
      "Bash(ls:*)",
      "Bash(cat:*)",
      "Bash(head:*)",
      "Bash(tail:*)",
      "Bash(wc:*)",
      "Bash(find:*)",
      "Bash(grep:*)",
      "Bash(rg:*)",
      "Bash(bash -n:*)",
      "Bash(mkdir:*)",
      "Bash(touch:*)",
      "Bash(git add:*)",
      "Bash(git commit:*)",
      "Bash(git merge:*)",
      "Bash(git checkout:*)",
      "Bash(git switch:*)",
      "Bash(docker compose:*)",
      "Bash(curl:*)"
    ]
  }
}
JSON

if [[ -f "$SETTINGS" ]] && jq -e . "$SETTINGS" >/dev/null 2>&1; then
  # Deep-merge into the existing (valid) settings; the Forge keys win on conflict.
  # Note: array keys (hooks, permissions.allow) are REPLACED by the Forge set — fine for a
  # near-empty new project; on a populated one, eyeball the result.
  tmp="$(mktemp)"
  if printf '%s\n' "$FORGE_SETTINGS" | jq -s '.[0] * .[1]' "$SETTINGS" - > "$tmp" 2>/dev/null && jq -e . "$tmp" >/dev/null 2>&1; then
    mv "$tmp" "$SETTINGS"
    green  "  ✓ merged Forge keys into existing settings.json"
    yellow "    (hooks/permissions arrays were replaced — verify if you had custom ones)"
  else
    rm -f "$tmp"
    yellow "  ! Could not merge settings.json automatically. Add these keys manually:"
    printf '%s\n' "$FORGE_SETTINGS" >&2
  fi
else
  printf '%s\n' "$FORGE_SETTINGS" > "$SETTINGS"
  green "  ✓ wrote .claude/settings.json"
fi

# ─── 6. git init + initial commit (the ONE repo) ──────────────────────────────
echo
bold "Initializing the git repo…"
if [[ -d "$DIR/.git" ]]; then
  yellow "  ! already a git repo — skipping git init"
else
  git -C "$DIR" init -q
  green "  ✓ git init"
fi
git -C "$DIR" add -A
# Respect the user's git identity; fall back to a neutral one only if none is set.
COMMIT_IDENT=()
if ! git -C "$DIR" config user.email >/dev/null 2>&1; then
  COMMIT_IDENT=(-c user.name="Forge" -c user.email="forge@local")
fi
git -C "$DIR" ${COMMIT_IDENT[@]+"${COMMIT_IDENT[@]}"} commit -q -m "chore: initial scaffold (The Forge)" \
  || die "Failed to create the initial commit in $DIR."
# Force the default branch to `main` — the forge loop squash-merges into `main` regardless of
# the machine's git init.defaultBranch (which may be `master`).
git -C "$DIR" branch -M main 2>/dev/null || true
green "  ✓ initial commit (on main)"

# ─── 7. summary ────────────────────────────────────────────────────────────────
echo
bold "The forge is lit."
echo
printf '%s\n' "${DIM}  Project folder (the one repo): $DIR${N}"
printf '%s\n' "${DIM}  Deploy type:                   $DEPLOY_TYPE  (in .forge/config)${N}"
echo
echo "  In this repo:"
echo "    .claude/  — skills, agents, hooks, statusline.sh, settings.json"
echo "    .forge/   — config, seed.md, tasks/, research/, continue.md, needs-human.md"
echo "    .knowledge/lessons.md, CLAUDE.md, CONTEXT.md, .gitignore, README.md"
echo
bold "  Next:"
echo   "    • Fill STACK_DIR / CONTAINER_PORT in .forge/config once the app's stack exists."
echo   "    • Continuity hooks are wired: SessionStart injects .forge/continue.md, Stop auto-commits it."
echo
echo "  Then: open this folder in Claude Code and run  /prospect"
echo "        (researches + warms the idea, then sends you into /ponder)"
echo

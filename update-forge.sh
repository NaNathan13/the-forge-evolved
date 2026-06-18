#!/usr/bin/env bash
# update-forge.sh — pull the latest Forge kit into an ALREADY-installed project.
#
# Run this from the root of an installed project (the single repo that holds
# .forge/config — where you launch Claude Code). It fetches the kit from GitHub and
# refreshes the KIT-OWNED files, while leaving every PROJECT-OWNED file untouched:
#
#   Overwritten (the kit itself):
#     .claude/skills/   .claude/agents/   .claude/hooks/   .claude/statusline.sh
#   Never touched (your state):
#     .forge/  (config, tasks, research, continue.md, needs-human.md, run-state, …)
#     .claude/settings.json   CLAUDE.md   CONTEXT.md   .knowledge/lessons.md
#
# It never DELETES local files — a skill you added yourself survives. Files removed
# upstream are reported, not removed. There is no GitHub workflow to refresh anymore.
#
# Usage (from your project root):
#   curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge/main/update-forge.sh | bash
#   curl -fsSL .../update-forge.sh | bash -s -- --dry-run        # preview only, change nothing
#   curl -fsSL .../update-forge.sh | bash -s -- --ref v0.2       # pin a branch/tag/SHA
#
#   # or from a local checkout of the-forge:
#   /path/to/update-forge.sh [--dry-run] [--ref <ref>]
#
# Requirements: git, rsync (falls back to cp if rsync is absent).

set -euo pipefail

REPO_URL="https://github.com/NaNathan13/the-forge.git"
REF="main"
DRY_RUN=0

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

# ─── parse args ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n)     DRY_RUN=1; shift ;;
    --ref)            REF="${2:-}"; [[ -n "$REF" ]] || die "--ref needs a value (branch/tag/SHA)."; shift 2 ;;
    --ref=*)          REF="${1#--ref=}"; shift ;;
    -h|--help)
      sed -n '2,24p' "$0" 2>/dev/null || true
      exit 0 ;;
    *) die "Unknown argument: $1  (see --help)" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is required and not on PATH."
HAVE_RSYNC=0; command -v rsync >/dev/null 2>&1 && HAVE_RSYNC=1

# ─── must be run from an installed forge project (single repo) ────────────────
ROOT="$(pwd)"
if [[ ! -f "$ROOT/.forge/config" ]]; then
  die "This isn't an installed Forge project (no ./.forge/config here).
  Run update-forge.sh from your project root — the one where you launch Claude Code.
  To scaffold a NEW project instead, use light-the-forge.sh."
fi

# ─── fetch the kit (GitHub @ ref), unless we're already in a checkout ─────────
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
SRC=""
if [[ -n "$SCRIPT_PATH" && "$SCRIPT_PATH" != "bash" ]]; then
  while [[ -L "$SCRIPT_PATH" ]]; do
    _d="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"; SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$_d/$SCRIPT_PATH"
  done
  _cand="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd 2>/dev/null || true)"
  # Only treat it as a local source if it's a real forge checkout AND the user didn't pin a non-default ref.
  if [[ "$REF" == "main" && -n "$_cand" && -f "$_cand/light-the-forge.sh" && -d "$_cand/.claude/skills" ]]; then
    SRC="$_cand"
  fi
fi

if [[ -z "$SRC" ]]; then
  CLONE_DIR="$(mktemp -d)"
  trap 'rm -rf "$CLONE_DIR"' EXIT
  bold "Fetching The Forge kit (${REF})…"
  if ! git clone --depth 1 --branch "$REF" --quiet "$REPO_URL" "$CLONE_DIR" 2>/dev/null; then
    # --branch only accepts branches/tags; fall back to a full clone + checkout for an arbitrary SHA.
    git clone --quiet "$REPO_URL" "$CLONE_DIR" || die "Failed to clone $REPO_URL"
    git -C "$CLONE_DIR" checkout --quiet "$REF" || die "ref not found in $REPO_URL: $REF"
  fi
  SRC="$CLONE_DIR"
fi
[[ -d "$SRC/.claude/skills" ]] || die "Fetched source doesn't look like the forge kit (no .claude/skills): $SRC"

SRC_DESC="$REF"
if SHA="$(git -C "$SRC" rev-parse --short HEAD 2>/dev/null)"; then SRC_DESC="$REF @ $SHA"; fi
# Show where the kit actually came from — the local checkout when we used one, else the GitHub URL.
if [[ "$SRC" == "${CLONE_DIR:-/nonexistent}" ]]; then SRC_LABEL="$REPO_URL"; else SRC_LABEL="$SRC (local checkout)"; fi

echo
bold "The Forge — update an installed project"
printf '  Kit source:  %s (%s)\n  Project:     %s\n' "$SRC_LABEL" "$SRC_DESC" "$ROOT"
[[ "$DRY_RUN" -eq 1 ]] && yellow "  DRY RUN — nothing will be written."
echo

# ─── plan + apply one kit item (dir or single file) ───────────────────────────
CHANGES=0
plan_and_apply() {  # plan_and_apply <relpath> [is_file]
  local rel="$1" is_file="${2:-0}"
  local src="$SRC/$rel" dst="$ROOT/$rel"

  if [[ ! -e "$src" ]]; then
    yellow "  ! source missing $rel — skipped"; return
  fi

  bold "  $rel"
  if [[ "$HAVE_RSYNC" -eq 1 ]]; then
    local src_arg="$src" dst_arg="$dst"
    [[ "$is_file" -eq 0 ]] && { src_arg="$src/"; dst_arg="$dst/"; }
    # Dry-run itemize first → human-readable plan. No --delete: we never remove local files.
    local plan; plan="$(rsync -ain --out-format='%i|%n' "$src_arg" "$dst_arg" 2>/dev/null || true)"
    if [[ -z "$plan" ]]; then
      printf '%s\n' "${DIM}    up to date${N}"
    else
      while IFS='|' read -r flags name; do
        [[ -z "$name" ]] && continue
        case "$flags" in
          \>f*+++*) green "    + $name (new)";     CHANGES=$((CHANGES+1)) ;;  # all-'+' attrs = newly created
          \>f*)     cyan  "    ~ $name (changed)"; CHANGES=$((CHANGES+1)) ;;  # '.st...' etc = updated
          *) : ;;  # dir entries / metadata-only — don't report
        esac
      done <<< "$plan"
    fi
    if [[ "$DRY_RUN" -eq 0 ]]; then
      mkdir -p "$(dirname "$dst")"
      rsync -a "$src_arg" "$dst_arg"
    fi
  else
    # Fallback: cp -R, coarser report (can't itemize precisely without rsync).
    if [[ "$is_file" -eq 0 ]] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
      printf '%s\n' "${DIM}    up to date${N}"
    elif [[ "$is_file" -eq 1 ]] && cmp -s "$src" "$dst" 2>/dev/null; then
      printf '%s\n' "${DIM}    up to date${N}"
    else
      cyan "    ~ changed (install rsync for a per-file plan)"; CHANGES=$((CHANGES+1))
      if [[ "$DRY_RUN" -eq 0 ]]; then
        mkdir -p "$(dirname "$dst")"
        if [[ "$is_file" -eq 1 ]]; then cp "$src" "$dst"; else mkdir -p "$dst"; cp -R "$src/." "$dst/"; fi
      fi
    fi
  fi

  # Report local-only files (not in upstream) as informational — never deleted.
  if [[ "$is_file" -eq 0 && -d "$dst" ]]; then
    while IFS= read -r line; do
      [[ "$line" == "Only in $dst"* ]] || continue
      local d="${line#Only in }"; d="${d%%:*}"; local f="${line##*: }"
      local p="${d#$ROOT/}/$f"
      yellow "    · $p (local-only — kept, not in upstream)"
    done < <(diff -rq "$src" "$dst" 2>/dev/null || true)
  fi
}

# ─── refresh the kit-owned files ONLY (never .claude/settings.json — it's yours) ─
plan_and_apply ".claude/skills"
plan_and_apply ".claude/agents"
plan_and_apply ".claude/hooks"
plan_and_apply ".claude/statusline.sh" 1

# keep hooks / statusline executable
if [[ "$DRY_RUN" -eq 0 ]]; then
  [[ -d "$ROOT/.claude/hooks" ]] && find "$ROOT/.claude/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  [[ -f "$ROOT/.claude/statusline.sh" ]] && chmod +x "$ROOT/.claude/statusline.sh" 2>/dev/null || true
fi

# ─── wiring check (advisory) — catch gaps in project-owned files we don't touch ─
# The updater never edits settings.json / config / .forge state (they're yours). But a
# project scaffolded by an OLD kit can be missing wiring the current kit expects. We
# don't fix it — we just tell you, so new skills don't silently lack their plumbing.
echo
bold "Wiring check (project-owned files — not modified, just verified):"
WIRING_WARN=0

SETTINGS="$ROOT/.claude/settings.json"
if [[ -f "$SETTINGS" ]]; then
  grep -q 'statusline\.sh' "$SETTINGS" || { yellow "  ! settings.json doesn't register .claude/statusline.sh (statusLine) — the context gauge won't show."; WIRING_WARN=$((WIRING_WARN+1)); }
  grep -q 'ctx-gate\.sh'   "$SETTINGS" || { yellow "  ! settings.json doesn't register .claude/hooks/ctx-gate.sh (PreToolUse) — the 50% hard-stop backstop is OFF."; WIRING_WARN=$((WIRING_WARN+1)); }
  grep -q 'continuity-inject\.sh' "$SETTINGS" || { yellow "  ! settings.json doesn't register .claude/hooks/continuity-inject.sh (SessionStart) — continue.md won't auto-inject on resume."; WIRING_WARN=$((WIRING_WARN+1)); }
  grep -q 'continuity-commit\.sh' "$SETTINGS" || { yellow "  ! settings.json doesn't register .claude/hooks/continuity-commit.sh (PreCompact/Stop) — continue.md won't auto-commit."; WIRING_WARN=$((WIRING_WARN+1)); }
else
  yellow "  ! no .claude/settings.json — statusline + ctx-gate + continuity hooks are unregistered."; WIRING_WARN=$((WIRING_WARN+1))
fi

CFG="$ROOT/.forge/config"
for key in DEPLOY_TYPE STACK_DIR CONTAINER_PORT PM_SLUG PM_HUB_DIR; do
  grep -Eq "^[[:space:]]*${key}=" "$CFG" || { yellow "  ! .forge/config is missing the ${key} key — /forge reads it for deploy + projection."; WIRING_WARN=$((WIRING_WARN+1)); }
done

if [[ "$WIRING_WARN" -eq 0 ]]; then
  printf '%s\n' "${DIM}    ok — settings.json + .forge/config have the keys the current kit expects.${N}"
else
  yellow "  ↳ $WIRING_WARN gap(s). The updater won't change project-owned files — compare against a fresh"
  yellow "    scaffold (light-the-forge.sh) and add the missing wiring by hand."
fi

# ─── summary ──────────────────────────────────────────────────────────────────
echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$CHANGES" -eq 0 ]]; then green "Already up to date — nothing to apply."; else
    bold "Dry run complete — $CHANGES kit file(s) would change. Re-run without --dry-run to apply."; fi
else
  if [[ "$CHANGES" -eq 0 ]]; then green "Already up to date."; else
    green "Updated — $CHANGES kit file(s) refreshed. Project-owned files (.forge/ state, CLAUDE.md, CONTEXT.md, settings.json, lessons.md) were left untouched."; fi
  echo
  printf '%s\n' "${DIM}  If a forge run is mid-flight, let it finish (or /clear and re-run /forge) before relying on the new skills.${N}"
fi

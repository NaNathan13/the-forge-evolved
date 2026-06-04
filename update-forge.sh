#!/usr/bin/env bash
# update-forge.sh — pull the latest Forge Evolved kit into an ALREADY-installed project.
#
# Run this from inside an installed project's OUTER folder (the one that holds
# .claude/forge/config — where you launch Claude Code). It fetches the kit from
# GitHub and refreshes the KIT-OWNED files, while leaving every PROJECT-OWNED file
# untouched:
#
#   Overwritten (the workflow itself):
#     .claude/skills/   .claude/agents/   .claude/hooks/   .claude/statusline.sh
#     docs/github-setup.md
#   Never touched (your state):
#     .claude/forge/{config,loop-state,seed.md}   .claude/settings.json
#     CLAUDE.md   CONTEXT.md   .knowledge/lessons.md
#
# It never DELETES local files — a skill you added yourself survives. Files removed
# upstream are reported, not removed.
#
# The app repo's .github/workflows/sync-board.yml is kit-owned but version-controlled,
# so it's opt-in (--with-workflow) and you commit it yourself.
#
# Usage (from your project's outer folder):
#   curl -fsSL https://raw.githubusercontent.com/NaNathan13/the-forge-evolved/main/update-forge.sh | bash
#   curl -fsSL .../update-forge.sh | bash -s -- --dry-run        # preview only, change nothing
#   curl -fsSL .../update-forge.sh | bash -s -- --ref v0.2       # pin a branch/tag/SHA
#   curl -fsSL .../update-forge.sh | bash -s -- --with-workflow  # also refresh sync-board.yml
#
#   # or from a local checkout of the-forge-evolved:
#   /path/to/update-forge.sh [--dry-run] [--ref <ref>] [--with-workflow]
#
# Requirements: git, rsync (falls back to cp if rsync is absent).

set -euo pipefail

REPO_URL="https://github.com/NaNathan13/the-forge-evolved.git"
REF="main"
DRY_RUN=0
WITH_WORKFLOW=0

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
    --with-workflow)  WITH_WORKFLOW=1; shift ;;
    --ref)            REF="${2:-}"; [[ -n "$REF" ]] || die "--ref needs a value (branch/tag/SHA)."; shift 2 ;;
    --ref=*)          REF="${1#--ref=}"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0" 2>/dev/null || true
      exit 0 ;;
    *) die "Unknown argument: $1  (see --help)" ;;
  esac
done

command -v git >/dev/null 2>&1 || die "git is required and not on PATH."
HAVE_RSYNC=0; command -v rsync >/dev/null 2>&1 && HAVE_RSYNC=1

# ─── must be run from an installed forge project ──────────────────────────────
OUTER="$(pwd)"
if [[ ! -f "$OUTER/.claude/forge/config" ]]; then
  die "This isn't an installed Forge project (no ./.claude/forge/config here).
  Run update-forge.sh from your project's OUTER folder — the one where you launch Claude Code.
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
  bold "Fetching The Forge Evolved kit (${REF})…"
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

echo
bold "The Forge Evolved — update an installed project"
printf '  Kit source:  %s (%s)\n  Project:     %s\n' "$REPO_URL" "$SRC_DESC" "$OUTER"
[[ "$DRY_RUN" -eq 1 ]] && yellow "  DRY RUN — nothing will be written."
echo

# ─── plan + apply one kit item (dir or single file) ───────────────────────────
CHANGES=0
plan_and_apply() {  # plan_and_apply <relpath> [is_file]
  local rel="$1" is_file="${2:-0}"
  local src="$SRC/$rel" dst="$OUTER/$rel"

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
      local p="${d#$OUTER/}/$f"
      yellow "    · $p (local-only — kept, not in upstream)"
    done < <(diff -rq "$src" "$dst" 2>/dev/null || true)
  fi
}

# ─── refresh the kit-owned files ──────────────────────────────────────────────
plan_and_apply ".claude/skills"
plan_and_apply ".claude/agents"
plan_and_apply ".claude/hooks"
plan_and_apply ".claude/statusline.sh" 1
plan_and_apply "docs/github-setup.md"  1

# keep hooks / statusline executable
if [[ "$DRY_RUN" -eq 0 ]]; then
  [[ -d "$OUTER/.claude/hooks" ]] && find "$OUTER/.claude/hooks" -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true
  [[ -f "$OUTER/.claude/statusline.sh" ]] && chmod +x "$OUTER/.claude/statusline.sh" 2>/dev/null || true
fi

# ─── opt-in: refresh the app repo's board-sync workflow (version-controlled) ──
echo
# shellcheck disable=SC1090
source "$OUTER/.claude/forge/config" 2>/dev/null || true
WF_SRC="$SRC/templates/sync-board.yml"
WF_DST="$OUTER/${APP_DIR:-}/.github/workflows/sync-board.yml"
if [[ -n "${APP_DIR:-}" && -f "$WF_SRC" ]]; then
  if [[ -f "$WF_DST" ]] && cmp -s "$WF_SRC" "$WF_DST"; then
    printf '%s\n' "${DIM}  sync-board.yml — up to date${N}"
  elif [[ "$WITH_WORKFLOW" -eq 1 ]]; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
      mkdir -p "$(dirname "$WF_DST")"; cp "$WF_SRC" "$WF_DST"
      green  "  + ${APP_DIR}/.github/workflows/sync-board.yml refreshed"
      yellow "    ↳ it's version-controlled — review & commit it in the app repo:"
      printf  '      git -C "%s" add .github/workflows/sync-board.yml && git -C "%s" commit -m "chore: update board-sync workflow"\n' "$APP_DIR" "$APP_DIR"
    else
      cyan "  ~ ${APP_DIR}/.github/workflows/sync-board.yml would be refreshed (--with-workflow)"
    fi
  else
    yellow "  · ${APP_DIR}/.github/workflows/sync-board.yml differs from upstream — re-run with --with-workflow to refresh it (then commit it in the app repo)."
  fi
fi

# ─── permission baseline (additive merge — only the ABSENT keys) ──────────────
# settings.json is project-owned and we never override your edits. But the
# bypass+deny permission baseline is kit policy, so we add defaultMode/deny ONLY
# when they're missing — an existing defaultMode or a custom deny list is left
# exactly as you set it (jq's has() guards each key independently).
SETTINGS="$OUTER/.claude/settings.json"
if [[ -f "$SETTINGS" ]] && command -v jq >/dev/null 2>&1 && jq -e . "$SETTINGS" >/dev/null 2>&1; then
  if ! jq -e '(.permissions.defaultMode != null) and (.permissions.deny | type == "array")' "$SETTINGS" >/dev/null 2>&1; then
    if [[ "$DRY_RUN" -eq 0 ]]; then
      tmp="$(mktemp)"
      if jq '
            .permissions = (.permissions // {})
          | (if (.permissions | has("defaultMode")) then . else .permissions.defaultMode = "bypassPermissions" end)
          | (if (.permissions | has("deny"))        then . else .permissions.deny = $deny end)
          ' \
          --argjson deny '["Bash(git push --force:*)","Bash(git push -f:*)","Bash(git reset --hard:*)","Bash(git clean -f:*)"]' \
          "$SETTINGS" > "$tmp" 2>/dev/null; then
        mv "$tmp" "$SETTINGS"
        green "  + permission baseline (defaultMode/deny) added to settings.json (your other settings untouched)"; CHANGES=$((CHANGES+1))
      else
        rm -f "$tmp"; yellow "  ! couldn't merge the permission baseline into settings.json — add defaultMode/deny by hand."
      fi
    else
      cyan "  ~ permission baseline (defaultMode/deny) would be added to settings.json"; CHANGES=$((CHANGES+1))
    fi
  fi
fi

# ─── wiring check (advisory) — catch gaps in project-owned files we don't touch ─
# The updater never overrides settings.json / config (they're yours; it only adds
# the absent permission baseline above). A project scaffolded by an OLD kit can be
# missing wiring the current kit expects. We don't fix the rest — we just tell you.
echo
bold "Wiring check (project-owned files — not modified, just verified):"
WIRING_WARN=0

if [[ -f "$SETTINGS" ]]; then
  grep -q 'statusline\.sh'   "$SETTINGS" || { yellow "  ! settings.json doesn't register .claude/statusline.sh (statusLine) — the context gauge won't show."; WIRING_WARN=$((WIRING_WARN+1)); }
  grep -q 'ctx-gate\.sh'     "$SETTINGS" || { yellow "  ! settings.json doesn't register .claude/hooks/ctx-gate.sh (PreToolUse) — the 40% hard-stop gate is OFF."; WIRING_WARN=$((WIRING_WARN+1)); }
  grep -q 'bypassPermissions' "$SETTINGS" || { yellow "  ! settings.json has no bypassPermissions baseline — you'll keep getting permission prompts (install jq so the updater can add it)."; WIRING_WARN=$((WIRING_WARN+1)); }
else
  yellow "  ! no .claude/settings.json — statusline + ctx-gate hook are unregistered."; WIRING_WARN=$((WIRING_WARN+1))
fi

CFG="$OUTER/.claude/forge/config"
for key in APP_DIR REPO_SLUG BOARD_OWNER PROJECT_NUMBER; do
  grep -Eq "^[[:space:]]*${key}=" "$CFG" || { yellow "  ! .claude/forge/config is missing the ${key} key — the forge skills read it."; WIRING_WARN=$((WIRING_WARN+1)); }
done

if [[ "$WIRING_WARN" -eq 0 ]]; then
  printf '%s\n' "${DIM}    ok — settings.json + config have the keys the current kit expects.${N}"
else
  yellow "  ↳ $WIRING_WARN gap(s). The updater won't change project-owned files — compare against a fresh"
  yellow "    scaffold (light-the-forge.sh) or docs/github-setup.md and add the missing wiring by hand."
fi

# ─── summary ──────────────────────────────────────────────────────────────────
echo
if [[ "$DRY_RUN" -eq 1 ]]; then
  if [[ "$CHANGES" -eq 0 ]]; then green "Already up to date — nothing to apply."; else
    bold "Dry run complete — $CHANGES kit file(s) would change. Re-run without --dry-run to apply."; fi
else
  if [[ "$CHANGES" -eq 0 ]]; then green "Already up to date."; else
    green "Updated — $CHANGES kit file(s) refreshed. Project-owned files (config, loop-state, CLAUDE.md, CONTEXT.md, settings.json, lessons.md) were left untouched."; fi
  echo
  printf '%s\n' "${DIM}  If a forge run is mid-flight, finish or /scrub it before relying on the new skills.${N}"
fi

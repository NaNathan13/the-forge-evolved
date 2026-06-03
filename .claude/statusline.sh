#!/usr/bin/env bash
# Forge statusline. Leads with the session name (set via Remote Control / --name / /rename),
# then model, git branch, PR badge, rate limits, and the context gauge.
# LOAD-BEARING: writes the live context % to .claude/forge/.ctx each turn so the ctx-gate
# PreToolUse hook can enforce the 30/40 rule. (D10) Do not remove the .ctx write.
input=$(cat)

# --- context % (load-bearing: drives the ctx-gate hook) ---
pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
echo "$pct" > .claude/forge/.ctx 2>/dev/null

# --- fields ---
name=$(printf '%s'   "$input" | jq -r '.session_name // empty')
model=$(printf '%s'  "$input" | jq -r '.model.display_name // "?"')
cwd=$(printf '%s'    "$input" | jq -r '.workspace.current_dir // .cwd // empty')
branch=$(git -C "${cwd:-.}" --no-optional-locks rev-parse --abbrev-ref HEAD 2>/dev/null)
pr=$(printf '%s'       "$input" | jq -r '.pr.number // empty')
pr_state=$(printf '%s' "$input" | jq -r '.pr.review_state // empty')
five=$(printf '%s'   "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week=$(printf '%s'   "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# --- ANSI ---
B='\033[1m'; DIM='\033[2m'; RST='\033[0m'
CYAN='\033[36m'; BLUE='\033[34m'; MAG='\033[35m'; GRN='\033[32m'
sep=" ${DIM}·${RST} "

# --- session name first (Remote Control label), bold cyan ---
if [ -n "$name" ]; then out="${B}${CYAN}▎${name}${RST}"; else out="${DIM}▎unnamed${RST}"; fi

# --- model ---
out="${out}${sep}${model}"

# --- git branch ---
[ -n "$branch" ] && out="${out}${sep}${BLUE}⎇ ${branch}${RST}"

# --- PR badge with review-state glyph ---
if [ -n "$pr" ]; then
  case "$pr_state" in
    approved)          g='✓' ;;
    changes_requested) g='✗' ;;
    draft)             g='◌' ;;
    *)                 g='•' ;;
  esac
  out="${out}${sep}${MAG}PR #${pr} ${g}${RST}"
fi

# --- rate limits (useful across long autonomous forge runs) ---
rl=''
[ -n "$five" ] && rl="5h:$(printf '%.0f' "$five")%"
[ -n "$week" ] && rl="${rl:+$rl }7d:$(printf '%.0f' "$week")%"
[ -n "$rl" ] && out="${out}${sep}${DIM}${rl}${RST}"

# --- context gauge last, with the load-bearing WARN/HARD coloring (30/40 per CLAUDE.md) ---
if   [ "$pct" -ge 40 ]; then ctx="\033[1;41m HARD ${pct}% \033[0m"
elif [ "$pct" -ge 30 ]; then ctx="\033[1;43m WARN ${pct}% \033[0m"
else                         ctx="ctx ${GRN}${pct}%${RST} ${DIM}▸ warn 30/hard 40${RST}"
fi
out="${out}${sep}${ctx}"

printf '%b\n' "$out"

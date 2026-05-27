#!/usr/bin/env bash
# PreToolUse hard stop: deny all tool calls once context >=40% (D10). The
# statusline writes the live % to .claude/forge/.ctx each turn; we read it here.
pct=$(cat .claude/forge/.ctx 2>/dev/null || echo 0)
if [ "${pct:-0}" -ge 40 ]; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Context >=40% (hard stop). Stop now: write/refresh the handoff, then /clear and re-run the command — state is in GitHub + git + loop-state."}}
JSON
else echo '{}'; fi

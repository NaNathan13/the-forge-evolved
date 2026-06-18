#!/usr/bin/env bash
# PreToolUse backstop: deny all tool calls once context >=50% used (hard stop). The 40% WARN
# is delivered visually by the statusline (no deny) — so the checkpoint write the warn asks for
# is never blocked by the gate itself. Deny only ever catches a runaway past 50%.
# The statusline writes the live % to .forge/.ctx each turn; we read it here.
pct=$(cat .forge/.ctx 2>/dev/null || echo 0)
if [ "${pct:-0}" -ge 50 ]; then
  cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Context ≥50% (backstop). /clear and re-run — state is in .forge/ files + git."}}
JSON
else echo '{}'; fi

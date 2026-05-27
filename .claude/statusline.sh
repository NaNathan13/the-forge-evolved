#!/usr/bin/env bash
# Renders the context gauge AND writes the live context % to .claude/forge/.ctx
# each turn, so the ctx-gate PreToolUse hook can enforce the 30/40 rule. (D10)
input=$(cat)
pct=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
echo "$pct" > .claude/forge/.ctx 2>/dev/null
model=$(printf '%s' "$input" | jq -r '.model.display_name // "?"')
if   [ "$pct" -ge 40 ]; then printf '\033[41m HARD %s%% \033[0m %s' "$pct" "$model"
elif [ "$pct" -ge 30 ]; then printf '\033[43m WARN %s%% \033[0m %s' "$pct" "$model"
else printf 'ctx %s%% ▸ warn 30/hard 40  %s' "$pct" "$model"; fi

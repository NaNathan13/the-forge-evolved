#!/usr/bin/env bash
# _probe.sh — passive hook-firing probe. Registered on SessionStart / PreCompact / Stop.
# Appends "<event> <ISO-ts>" to .forge/hook-probe.log so Nate can confirm the web Claude Code
# harness actually fires these three events BEFORE the real continuity hooks (continue.md
# auto-inject + auto-commit) are trusted. Pure: no side effects beyond the gitignored log,
# always exits 0, never emits a permission decision. See TODO-FOR-NATE.md for the probe gate.
input=$(cat 2>/dev/null)
event=$(printf '%s' "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
[ -z "$event" ] && event="unknown"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
printf '%s %s\n' "$event" "$ts" >> .forge/hook-probe.log 2>/dev/null
exit 0

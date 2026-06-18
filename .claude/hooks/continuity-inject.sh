#!/usr/bin/env bash
# continuity-inject.sh — SessionStart continuity hook. PROBE-GATED: NOT wired in settings.json
# until Nate's hook-firing probe confirms SessionStart fires under the web harness (see
# TODO-FOR-NATE.md). To wire it, add to settings.json hooks.SessionStart alongside _probe.sh:
#   { "type": "command", "command": ".claude/hooks/continuity-inject.sh" }
#
# Injects the continuity journal (Now / Next / Friction) into the new session's context so a
# resumed session picks up the active command, next action, and soft friction memory.
[ -f .forge/continue.md ] || exit 0
ctx=$(cat .forge/continue.md 2>/dev/null)
[ -z "$ctx" ] && exit 0
jq -n --arg c "$ctx" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}' 2>/dev/null \
  || exit 0

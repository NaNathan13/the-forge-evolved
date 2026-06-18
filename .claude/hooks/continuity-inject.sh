#!/usr/bin/env bash
# continuity-inject.sh — SessionStart continuity hook. WIRED by default (the SessionStart/Stop
# hook-firing probe passed 2026-06-18 under the web harness). Registered in settings.json
# hooks.SessionStart by the installer.
#
# Injects the continuity journal (Now / Next / Friction) into the new session's context so a
# resumed session picks up the active command, next action, and soft friction memory.
[ -f .forge/continue.md ] || exit 0
ctx=$(cat .forge/continue.md 2>/dev/null)
[ -z "$ctx" ] && exit 0
jq -n --arg c "$ctx" \
  '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}' 2>/dev/null \
  || exit 0

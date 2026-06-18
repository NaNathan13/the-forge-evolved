#!/usr/bin/env bash
# continuity-commit.sh — PreCompact / Stop continuity hook. WIRED by default (the Stop hook-firing
# probe passed 2026-06-18 under the web harness; PreCompact is untested but harmless — it only fires
# on a compaction the 40/50 rule avoids). Registered in settings.json hooks.PreCompact + hooks.Stop
# by the installer.
#
# Auto-commits .forge/continue.md so the continuity journal is durably checkpointed. Guarded by
# `git diff --quiet` so a no-op turn (nothing changed in continue.md) never creates an empty
# commit — important on Stop, which fires every turn.
[ -f .forge/continue.md ] || exit 0
# Nothing changed in continue.md (working tree AND index clean)? Skip.
if git diff --quiet -- .forge/continue.md 2>/dev/null \
   && git diff --cached --quiet -- .forge/continue.md 2>/dev/null; then
  exit 0
fi
# Respect the user's git identity; fall back to a neutral one only if none is set.
ident=()
git config user.email >/dev/null 2>&1 || ident=(-c user.name="Forge" -c user.email="forge@local")
git add .forge/continue.md 2>/dev/null || exit 0
git ${ident[@]+"${ident[@]}"} commit -q -m "chore(continue): checkpoint continuity journal" \
  -- .forge/continue.md 2>/dev/null || true
exit 0

#!/bin/bash
# Clears all Claude Code plugin caches for ai-agent-toolbox.
# Run this after pushing updates to force Claude Code to re-fetch on next session.

DIRS=(
  "$HOME/.claude/plugins/marketplaces/ai-agent-toolbox"
  "$HOME/.claude/plugins/marketplaces/agent-toolbox"
  "$HOME/.claude/plugins/cache/ai-agent-toolbox"
)

cleared=0
for dir in "${DIRS[@]}"; do
  if [ -d "$dir" ]; then
    rm -rf "$dir"
    echo "Cleared: $dir"
    cleared=1
  fi
done

if [ "$cleared" -eq 0 ]; then
  echo "No cache found (already clean)."
else
  echo "Done. Restart Claude Code to pick up the latest version."
fi

#!/bin/bash
# Clears Claude Code plugin caches for this marketplace.
# Run this after pushing updates to force Claude Code to re-fetch on next session.

MARKETPLACE="ai-agent-toolbox"

DIRS=(
  "$HOME/.claude/plugins/marketplaces/$MARKETPLACE"
  "$HOME/.claude/plugins/cache/$MARKETPLACE"
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

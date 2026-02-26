#!/bin/bash
# Clears the Claude Code plugin cache for the MV digital marketplace.
# Run this after pushing updates to force Claude Code to re-fetch on next session.

CACHE_DIR="$HOME/.claude/plugins/marketplaces/mv-digital-marketplace"

if [ -d "$CACHE_DIR" ]; then
  rm -rf "$CACHE_DIR"
  echo "Plugin cache cleared."
else
  echo "No cache found (already clean)."
fi

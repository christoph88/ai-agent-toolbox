# CLAUDE.md

This file provides context for Claude Code when working in this repository.

## What This Repo Is

Claude Code plugin — a general-purpose toolbox for macOS automation, scheduled tasks, and multi-agent systems. Distributed as a GitHub-based marketplace plugin — the repo **is** the distribution, no build step needed. Pushing to `master` auto-updates all users on their next session.

## Skills

| Skill | Purpose |
|-------|---------|
| `/mv-launchd-manager` | Manages macOS scheduled tasks (LaunchAgents) via launchd — list, add, and remove jobs |
| `/agent-factory` | Design and generate multi-agent collaboration systems — describe a task, get a ready-to-run TypeScript project with collaborating AI agents |

Skill definitions live in `.claude/skills/{skill-name}/SKILL.md`. Registration in `.claude-plugin/plugin.json`.

## File Structure

```
.claude/skills/          — Skill definitions (SKILL.md per skill)
.claude-plugin/          — plugin.json (skill registry) + marketplace.json (distribution)
clear-plugin-cache.sh    — Clears Claude Code plugin cache for manual refresh
```

## Plugin Config

- `.claude-plugin/plugin.json` — Registers all skills, defines plugin metadata
- `.claude-plugin/marketplace.json` — Marketplace definition for distribution
- `.claude/settings.local.json` — User-specific permissions (gitignored)

## Maintenance

When adding or modifying skills, update both this file and `README.md` to keep documentation consistent.

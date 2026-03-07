# CLAUDE.md

This file provides context for Claude Code when working in this repository.

## What This Repo Is

Claude Code plugin — a general-purpose toolbox for macOS automation and scheduled tasks. Distributed as a GitHub-based marketplace plugin — the repo **is** the distribution, no build step needed. Pushing to `master` auto-updates all users on their next session.

## Skills

| Skill | Purpose |
|-------|---------|
| `/launchd` | Manages macOS scheduled tasks (LaunchAgents) via launchd — list, add, and remove jobs |
| `/mv-digital-performance-analysis` | Analyse Mobile Vikings digital campaign performance using funnel framework, GA4, HubSpot, and Budskap data |
| `/agent-security-auditor` | Audit AI agent setups, skill files, configs, and architectures for security and safety issues |

Skill definitions live in `.claude/skills/{skill-name}/SKILL.md`. Registration in `.claude-plugin/plugin.json`.

## File Structure

```
.claude/skills/          — Skill definitions (SKILL.md per skill)
.claude-plugin/          — plugin.json (skill registry) + marketplace.json (distribution)
```

## Plugin Config

- `.claude-plugin/plugin.json` — Registers all skills, defines plugin metadata
- `.claude-plugin/marketplace.json` — Marketplace definition for distribution
- `.claude/settings.local.json` — User-specific permissions (gitignored)

## Maintenance

When adding or modifying skills, update both this file and `README.md` to keep documentation consistent.

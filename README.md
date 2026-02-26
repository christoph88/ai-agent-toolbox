# Digital Toolbox

Private Claude Code plugin for the Mobile Vikings digital team. A general-purpose toolbox for macOS automation and system management utilities.

## Installation

### 1. Authenticate with GitHub

The plugin installs via `git clone`, so git needs access to this private repo. The easiest way:

```bash
gh auth login
```

This configures git credentials automatically for both HTTPS and `gh` commands.

### 2. Add the marketplace

In Claude Code, run:

```
/plugin marketplace add https://github.com/vikingco/digital-toolbox
```

### 3. Install the plugin

```
/plugin install digital-toolbox@mv-digital-marketplace
```

### 4. Verify

Run `/plugin` in Claude Code to open the plugin manager. You should see `digital-toolbox` under the "Installed" tab.

## Skills

### `/mv-launchd-manager`

Manages macOS scheduled tasks (LaunchAgents) via `launchd`. Supports three actions:

- **List jobs** — scans `~/Library/LaunchAgents/`, shows label, command, schedule, loaded status, and log paths
- **Add a job** — accepts natural-language schedules ("every day at 9am", "every 5 minutes"), generates and validates the plist, loads it via `launchctl`
- **Remove a job** — unloads and/or deletes a plist after confirmation

Always asks for explicit confirmation before any write or delete operation. Only manages user-level agents — never touches system daemons.

## Adding More Skills

This plugin is designed as a general-purpose toolbox. To add new utility skills:

1. Create a folder: `.claude/skills/my-new-skill/`
2. Add a `SKILL.md` with frontmatter:
   ```markdown
   ---
   name: my-new-skill
   description: What it does
   ---

   Instructions for the skill...
   ```
3. Register it in `.claude-plugin/plugin.json`:
   ```json
   "skills": [
     ".claude/skills/my-new-skill",
     ...existing skills
   ]
   ```

## Staying Up to Date

The plugin stays in sync with the GitHub repo automatically:

- **Automatic updates** — Claude Code checks for plugin updates at the start of each session. When changes are pushed to the repo, teammates get them on their next session.
- **Manual refresh** — Open `/plugin` in Claude Code, go to the "Installed" tab, and refresh the plugin to pull the latest version immediately.
- **No reinstall needed** — You only run `/plugin marketplace add` and `/plugin install` once. After that, updates flow through automatically.

### Cache clearing

If you're not seeing the latest changes, run the included cache-clearing script:

```bash
./clear-plugin-cache.sh
```

Then restart Claude Code.

## Documentation

This repo has two documentation files that should be kept in sync:

- **`README.md`** — Human-facing documentation (installation, usage, adding skills)
- **`CLAUDE.md`** — Claude Code context file. Claude reads this automatically when working in the repo.

When adding or modifying skills, update both files.

## Requirements

- Claude Code CLI
- GitHub access token with repo read permissions (for private repo)
- macOS (for launchd-based skills)

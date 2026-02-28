# AI Agent Toolbox

Claude Code plugin with general-purpose utilities for macOS automation, scheduled tasks, and multi-agent systems.

## Installation

### 1. Add the marketplace

In Claude Code, run:

```
/plugin marketplace add https://github.com/christoph88/ai-agent-toolbox
```

### 2. Install the plugin

```
/plugin install ai-agent-toolbox@ai-agent-toolbox
```

### 3. Verify

Run `/plugin` in Claude Code to open the plugin manager. You should see `ai-agent-toolbox` under the "Installed" tab.

## Skills

### `/launchd`

Manages macOS scheduled tasks (LaunchAgents) via `launchd`. Supports three actions:

- **List jobs** — scans `~/Library/LaunchAgents/`, shows label, command, schedule, loaded status, and log paths
- **Add a job** — accepts natural-language schedules ("every day at 9am", "every 5 minutes"), generates and validates the plist, loads it via `launchctl`
- **Remove a job** — unloads and/or deletes a plist after confirmation

Always asks for explicit confirmation before any write or delete operation. Only manages user-level agents — never touches system daemons.

### `/factory`

Designs and generates multi-agent collaboration systems. Describe a task or problem, and it creates a standalone TypeScript project where multiple AI agents collaborate to solve it.

**Two modes:**
- **Assisted** — describe your problem, the skill designs the agent team for you
- **Expert** — manually define agents, roles, tools, and patterns

**Features:**
- **Three collaboration patterns:** Orchestrator + Workers (delegation), Pipeline (sequential stages), Debate (parallel proposals + judge)
- **Per-agent sandboxing** — restrict tools, filesystem access, and network per agent
- **Real-time terminal dashboard** — live activity stream with color-coded events, estimated cost tracking in EUR
- **Interactive messaging `[M]`** — interrupt a running agent and inject a human message; it resumes with full context
- **Agent-to-human questions** — agents can ask the human for help when stuck; answerable via Discord buttons or terminal input; first response wins
- **Log tailing `[T]`** — view any agent's conversation transcript live, Tab to cycle between agents, `_stream.log` for unified view
- **Recap view `[R]`** — filtered view of important events only (milestones, questions, errors, decisions — no THINK/TOOL noise)
- **Agent conversation logging** — full timestamped transcripts saved to `workspace/logs/`
- **Configurable stop conditions** — max iterations, estimated cost cap, time limit, validation checks, checkpoint prompts
- **Shared workspace** — agents communicate via a filesystem directory
- **Discord integration** — three modes:
  - **Off** — terminal only
  - **Status updates** — webhook-based notifications for run start/completion
  - **Interactive control** — full bot with thread-based conversations, message routing to orchestrator, agent question prompts with buttons, error escalation (Retry/Skip/Stop), confidence review, and post-message reaction summaries

**Generated projects:**
- Run with `npx tsx src/run.ts`
- Use your existing Claude Code subscription (no API keys needed)
- Fully editable — tweak `src/config.ts` and rerun
- Include `README.md` and `CLAUDE.md` documentation

**Requirements:** Node.js 18+, Claude Code CLI installed and authenticated

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

- **Automatic updates** — Claude Code checks for plugin updates at the start of each session. When changes are pushed to the repo, users get them on their next session.
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
- macOS (for launchd-based skills)

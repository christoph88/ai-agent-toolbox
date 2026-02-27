# Design: `/mv-agent-factory` Skill

**Date:** 2026-02-27
**Status:** Approved
**Plugin:** digital-toolbox

## Purpose

A skill that helps users design and generate multi-agent collaboration systems. Given a task or problem description, it decomposes the work into specialized agents, generates a standalone TypeScript project using the `@anthropic-ai/claude-agent-sdk`, and provides a persistent runner with real-time monitoring.

The skill leverages the user's existing Claude Code subscription — no API keys or separate billing required.

## Invocation Modes

### Assisted Mode (recommended for most users)

User describes their problem in natural language. The skill analyzes the task and proposes an optimal agent configuration: which pattern, how many agents, what roles, tools, and stop conditions.

Example: "Our landing page loads too slowly. I need someone to audit performance, figure out what's wrong, fix it, and verify the fixes actually work."

The skill proposes a Pipeline with 4 agents (auditor → analyst → fixer → verifier), the user reviews/tweaks, and the project is generated.

### Expert Mode

User manually defines agents, roles, tools, and patterns. For users who know exactly what agent setup they want.

## Collaboration Patterns

### Orchestrator + Workers

One lead agent breaks down the task and delegates sub-tasks to specialized worker agents. The lead reviews results and either assigns more work or declares the task done.

Flow: Orchestrator writes tasks to `workspace/tasks/` → Workers pick up and write results to `workspace/results/` → Orchestrator reviews → loops or finishes.

### Pipeline

Agents run sequentially, each handling a stage. Each stage validates the previous stage's output before proceeding.

Flow: Agent 1 → `workspace/stage-1/` → Agent 2 → `workspace/stage-2/` → ... → final output.

### Debate / Consensus

Multiple agents independently tackle the same problem in parallel. A judge agent reads all proposals and picks the best or synthesizes a combined solution.

Flow: All agents receive task → write to `workspace/proposals/` → Judge evaluates → final decision.

## Agent Configuration

Each agent is defined with:

| Property | Description |
|----------|-------------|
| `id` | Unique identifier (e.g., `"architect"`) |
| `role` | Human-readable role name |
| `systemPrompt` | Instructions for this agent's behavior |
| `allowedTools` | Whitelist of Claude Code tools this agent can use |
| `disallowedTools` | Optional blacklist |
| `sandbox` | Per-agent sandbox settings (filesystem, network) |
| `model` | Model choice: `"opus"`, `"sonnet"`, or `"haiku"` |
| `maxTurns` | Optional per-agent turn limit |

### Security

Each agent runs in its own sandboxed Claude Code session via the SDK. Security is configurable per agent:

- **Filesystem sandboxing:** restrict read/write to specific paths via `sandbox.filesystem.allowWrite` and `sandbox.filesystem.denyRead`
- **Network sandboxing:** allowlist domains via `sandbox.network.allowedDomains`
- **Tool restrictions:** `allowedTools` / `disallowedTools` per agent
- **Custom permission handler:** `canUseTool` callback for fine-grained runtime control
- **Permission modes:** `default`, `acceptEdits`, `dontAsk`, or `bypassPermissions`

Read-only agents (e.g., reviewers) get only `Read`, `Glob`, `Grep` — they cannot modify code.

## Inter-Agent Communication

Agents communicate via a shared filesystem directory:

```
workspace/
├── tasks/       — Task assignments (orchestrator → workers)
├── results/     — Agent outputs (workers → orchestrator)
└── messages/    — Inter-agent messages and status updates
```

Each file is a JSON or Markdown document. Agents read and write to this directory as part of their normal tool usage. The orchestrator coordinates by reading results and writing new tasks.

## Safety & Stop Conditions

All stop conditions are optional — the user picks which ones to enable at project generation time.

| Condition | Description |
|-----------|-------------|
| Max iterations | Pipeline cycles or orchestrator rounds — stops at N |
| Estimated cost cap (EUR) | Tracks `total_cost_usd` from SDK, converts to EUR, stops when exceeded |
| Time limit | Wall-clock timeout — stops after N minutes/hours |
| Validation check | A validation agent evaluates whether the task is actually done |
| Checkpoint prompts | Every N iterations, pauses and asks the user: "Continue?" with a summary |
| Manual stop | Ctrl+C or press `S` in the dashboard — graceful shutdown |

**Estimated cost note:** Since users are on Claude Code subscription (not API billing), cost figures are informational estimates based on API pricing. Displayed in EUR with `~€` prefix to indicate they are estimates.

**Graceful shutdown:** When any stop condition triggers:
1. Let the currently active agent finish its current turn
2. Save all state to `workspace/`
3. Write a summary of what was accomplished
4. Exit cleanly

## Terminal Dashboard

The generated project includes a real-time terminal UI:

### Overview Mode

Shows all agents, their status, turn count, estimated cost, and last activity. Includes total estimated cost and budget remaining.

Keyboard controls: `[P]ause`, `[S]top`, `[D]etail view`, `[L]ogs`

### Detail Mode

Live stream of what a specific agent is doing — tool calls, thinking excerpts, file changes, command outputs. Switch between agents with arrow keys.

This uses the SDK's streaming (`for await` on `query()`) to capture real-time agent activity.

## Generated Project Structure

```
{project-name}/
├── CLAUDE.md              — Project context for Claude Code
├── README.md              — Usage instructions, how to customize
├── package.json           — @anthropic-ai/claude-agent-sdk, tsx
├── tsconfig.json
├── .env.example           — Configuration template
├── src/
│   ├── run.ts             — CLI entry point
│   ├── config.ts          — Agent definitions, limits, patterns
│   ├── orchestrator.ts    — Main loop + coordination logic
│   ├── agents/
│   │   ├── types.ts       — Agent interfaces & types
│   │   └── factory.ts     — Spawns agents via SDK query()
│   ├── patterns/
│   │   ├── orchestrator-workers.ts
│   │   ├── pipeline.ts
│   │   └── debate.ts
│   ├── safety/
│   │   ├── limits.ts      — Token/time/iteration tracking
│   │   ├── sandbox.ts     — Per-agent sandbox configuration
│   │   └── checkpoints.ts — User confirmation prompts
│   ├── comms/
│   │   └── shared-fs.ts   — Shared workspace read/write utilities
│   └── dashboard/
│       └── terminal-ui.ts — Real-time terminal dashboard
└── workspace/             — Shared agent communication directory
    ├── tasks/
    ├── results/
    └── messages/
```

## Skill Location

```
digital-toolbox/
├── .claude/skills/
│   ├── mv-launchd-manager/SKILL.md   (existing)
│   └── mv-agent-factory/SKILL.md     (new)
├── .claude-plugin/plugin.json         (update: add new skill path)
├── CLAUDE.md                          (update: add skill to table)
└── README.md                          (update: add skill docs)
```

## Technology

- **Runtime:** TypeScript via `tsx` (no build step)
- **Core dependency:** `@anthropic-ai/claude-agent-sdk`
- **Auth:** Uses existing Claude Code subscription (no API key needed)
- **Terminal UI:** Built with Node.js stdout manipulation (or `ink` if richer UI needed)
- **Target platform:** macOS (matches digital-toolbox scope)

## Out of Scope

- Web UI / browser dashboard (terminal only)
- Persistent agent memory across separate project runs
- Template library files in the plugin repo (patterns are knowledge in SKILL.md)
- API key management (subscription only)

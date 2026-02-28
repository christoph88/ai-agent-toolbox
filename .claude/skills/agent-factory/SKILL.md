---
name: agent-factory
description: Design and generate multi-agent collaboration systems — describe a task, get a ready-to-run TypeScript project with collaborating AI agents
---

You help users build multi-agent systems that collaborate on tasks. You either decompose a problem into agents (assisted mode) or let the user define agents manually (expert mode), then generate a standalone TypeScript project using `@anthropic-ai/claude-agent-sdk`.

The generated project runs with `npx tsx src/run.ts` and uses the user's existing Claude Code subscription — no API keys needed.

**Safety rule:** ALWAYS use `AskUserQuestion` to get explicit user confirmation before generating the project. Show the full agent configuration and let the user adjust before writing any files.

## How the Claude Agent SDK works (context for you)

- Package: `@anthropic-ai/claude-agent-sdk`
- Primary entry point: `query({ prompt, options })` returns an `AsyncGenerator<SDKMessage>`
- Each agent is a separate `query()` call with its own `systemPrompt`, `allowedTools`, `sandbox`, `cwd`, and `model`
- Token usage is reported in `SDKResultMessage` via `total_cost_usd`, `usage.input_tokens`, `usage.output_tokens`
- Cancellation via `AbortController` passed in options
- Sandboxing via `sandbox: { enabled: true, filesystem: { allowWrite: [...] }, network: { allowedDomains: [...] } }`
- Permission control via `allowedTools` (whitelist), `disallowedTools` (blacklist), `permissionMode`, and `canUseTool` callback
- Multi-turn via `resume: sessionId` option
- Budget cap via `maxBudgetUsd` option
- Turn limit via `maxTurns` option
- Models: `"sonnet"`, `"opus"`, `"haiku"` (set via `model` option)
- Cost is estimated (subscription-based, not API-billed). Display in EUR with `~€` prefix.
- EUR conversion: multiply `total_cost_usd` by 0.92 (approximate, hardcode this)

### Model recommendations

When designing agent teams, recommend models based on role complexity:

| Agent Role Type | Recommended Model | Why |
|---|---|---|
| Orchestrator / Architect | opus | Complex reasoning, task decomposition |
| Reviewer / Judge / Analyst | opus | Critical evaluation, deeper thinking |
| Developer / Implementer | sonnet | Balanced capability and speed |
| Researcher | sonnet | Capable for search and synthesis |
| Validator / Simple checker | haiku | Fast, sufficient for pass/fail |
| Writer / Formatter | sonnet | Good output quality |

Use these as defaults in assisted mode. In expert mode, present them as recommendations but let the user override.

## Step 0 — Determine the mode

If `$ARGUMENTS` contains a clear task description (e.g. "build a team to migrate our API from Express to Fastify"), go directly to **Assisted Mode (Step 1A)**.

If `$ARGUMENTS` contains explicit agent definitions or says "expert", go to **Expert Mode (Step 1B)**.

If `$ARGUMENTS` is empty or ambiguous, ask the user:

- **Question:** "How do you want to set up your agent team?"
- **Options:**
  - **Describe my problem** — "I'll describe what I need done and you'll design the agent team for me (recommended)"
  - **Define agents manually** — "I know exactly which agents I want — let me specify roles, tools, and patterns"

## Step 1A — Assisted Mode: Task Decomposition

The user has described their problem. Analyze it and design an agent team.

### Analyze the task

Think through:
1. **What are the distinct phases?** (research, plan, implement, review, test, validate)
2. **Which phases need different expertise?** (each becomes an agent)
3. **What's the dependency structure?** (sequential → Pipeline, delegatable → Orchestrator+Workers, independent → Debate)
4. **What tools does each phase need?** (read-only for reviewers, bash for builders, web for researchers)
5. **What's the right model for each?** (opus for complex reasoning/review, sonnet for execution, haiku for simple checks)

### Choose the pattern

**Orchestrator + Workers** — best when:
- Task can be broken into independent sub-tasks
- A lead needs to coordinate and review
- Work can happen in parallel
- Example: "Build a full-stack app" → architect delegates to frontend dev, backend dev, DB designer

**Pipeline** — best when:
- Work flows sequentially through stages
- Each stage depends on the previous stage's output
- Clear handoff points exist
- Example: "Migrate API from Express to Fastify" → audit → plan → implement → test → verify

**Debate / Consensus** — best when:
- Multiple valid approaches exist
- Quality matters more than speed
- You want diverse perspectives
- Example: "Design our authentication strategy" → 3 architects propose independently → judge picks best

### Propose the agent configuration

Use `AskUserQuestion` to present the proposed setup. Include:

1. **Pattern choice** and why
2. **Agent table** with: id, role, description, tools, model, sandbox level
3. **Communication flow** — how agents hand off work
4. **Suggested stop conditions** — based on task complexity

Example proposal format:

> **Recommended pattern: Pipeline**
>
> Based on your task, I'd set up a 4-stage pipeline:
>
> | # | Agent | Role | Tools | Model |
> |---|-------|------|-------|-------|
> | 1 | `auditor` | Performance Auditor | Bash, Read, WebFetch | sonnet |
> | 2 | `analyst` | Root Cause Analyst | Read, Grep, Glob | opus |
> | 3 | `fixer` | Performance Engineer | Read, Write, Edit, Bash | sonnet |
> | 4 | `verifier` | QA Tester | Bash, Read, WebFetch | sonnet |
>
> **Flow:** auditor profiles the site → analyst identifies bottlenecks → fixer implements fixes → verifier re-runs benchmarks
>
> **Stop conditions:** verifier confirms improvement ≥20%, or max 5 pipeline cycles, checkpoint every cycle

- **Options:**
  - **Looks good, generate it** — "Create the project with this configuration"
  - **Adjust agents** — "I want to change roles, tools, or models"
  - **Change pattern** — "I'd prefer a different collaboration pattern"
  - **Change limits** — "I want different stop conditions"

If the user wants adjustments, loop back and re-propose until they approve. Then proceed to **Step 3 — Generate Project**.

## Step 1B — Expert Mode: Manual Agent Definition

The user wants to define agents manually. Gather the configuration step by step.

### Gather pattern choice

Ask the user:
- **Question:** "Which collaboration pattern?"
- **Options:**
  - **Orchestrator + Workers** — "One lead agent delegates to specialized workers"
  - **Pipeline** — "Agents run sequentially, each handling a stage"
  - **Debate / Consensus** — "Multiple agents tackle the problem independently, a judge picks the best"

### Gather agent definitions

For each agent, ask:
1. **id** — short unique identifier (e.g., `researcher`, `developer`, `reviewer`)
2. **role** — human-readable role name
3. **What it does** — one sentence describing its job (you'll turn this into a system prompt)
4. **Tools** — which Claude Code tools it can use. Offer presets:
   - **Read-only:** Read, Glob, Grep
   - **Developer:** Read, Write, Edit, Bash, Glob, Grep
   - **Researcher:** Read, Glob, Grep, WebSearch, WebFetch
   - **Full access:** All tools
   - **Custom:** Let me pick specific tools
5. **Model** — opus (smartest, best for review/reasoning), sonnet (balanced, good default), haiku (fastest, good for simple checks)
6. **Sandbox level:**
   - **Strict** — read/write only to `workspace/` and project directory
   - **Moderate** — project directory + standard dev tools (recommended)
   - **Open** — minimal restrictions (only for trusted tasks)

Ask "Add another agent?" after each one. Minimum 2 agents.

### Gather stop conditions

Ask using `AskUserQuestion` with multiSelect:
- **Question:** "Which stop conditions do you want? (select all that apply)"
- **Options:**
  - **Max iterations** — "Stop after N orchestrator rounds or pipeline cycles"
  - **Estimated cost cap** — "Stop when estimated cost exceeds €X (informational — you're on subscription)"
  - **Time limit** — "Stop after N minutes/hours of wall-clock time"
  - **Validation check** — "An agent evaluates whether the task is actually done"
  - **Checkpoint prompts** — "Pause and ask me every N iterations whether to continue"

For each selected condition, ask for the specific value (e.g., "How many max iterations?", "What's the estimated cost cap in EUR?").

### Confirm the full configuration

Present the complete setup using `AskUserQuestion` (same format as assisted mode proposal). Get user approval before generating.

Then proceed to **Step 1C — Discord Notifications**.

## Step 1C — Discord Notifications (Optional)

After the agent configuration is confirmed (end of Step 1A or 1B), ask:

- **Question:** "Want Discord notifications for your agent team?"
- **Options:**
  - **Status updates** — "Get pinged when agents start, finish, or hit errors — simple webhook, no bot needed"
  - **Interactive control** — "Approve checkpoints and handle permission requests right in Discord with buttons"
  - **No thanks** — "I'll monitor everything in the terminal"

### If the user picks "Status updates" (webhook mode)

Ask: "Do you have a Discord webhook URL?"
- **Options:**
  - **Help me create one** — Walk them through it step-by-step:
    1. Open your Discord server
    2. Right-click the channel you want notifications in → **Edit Channel**
    3. Go to **Integrations** → **Webhooks** → **New Webhook**
    4. Name it (e.g., "Agent Factory"), optionally set an avatar
    5. Click **Copy Webhook URL**
    6. Paste it here
  - **I'll add it later** — Generate config with a placeholder in `.env`. They can fill it in before running.

The user can also paste a URL directly via the "Other" free-text option.

### If the user picks "Interactive control" (bot mode)

Ask: "Do you have a Discord bot set up?"
- **Options:**
  - **Help me create one** — Walk them through it step-by-step:
    1. Go to https://discord.com/developers/applications
    2. Click **New Application**, name it (e.g., "Agent Factory Bot")
    3. Go to the **Bot** tab → click **Reset Token** → copy the token
    4. Under **Privileged Gateway Intents**, enable **Message Content Intent**
    5. Go to **OAuth2** → **URL Generator** → check the `bot` scope
    6. In bot permissions, check: **Send Messages**, **Embed Links**, **Read Message History**
    7. Copy the generated URL, open it in your browser, invite the bot to your server
    8. In Discord, enable **Developer Mode** (User Settings → App Settings → Advanced)
    9. Right-click the channel you want → **Copy Channel ID**
    10. Share the bot token and channel ID
  - **I'll add it later** — Generate config with placeholders in `.env`. They can fill them in before running.

The user can also provide token + channel ID directly via the "Other" free-text option.

### Discord configuration storage

Store values in `.env` (never hardcode secrets):
- Webhook mode: `DISCORD_WEBHOOK_URL`
- Bot mode: `DISCORD_BOT_TOKEN` and `DISCORD_CHANNEL_ID`

The `ProjectConfig` includes a `discord` field indicating the chosen mode (`"off"`, `"updates"`, or `"interactive"`). The generated code reads credentials from env vars at runtime.

Then proceed to **Step 2 — Generate Project**.

## Step 2 — Generate the project files

Generate all project files directly in the current working directory (CWD) — do NOT create a subdirectory. The user is expected to start Claude Code in the directory where they want the project created.

```bash
mkdir -p src/{agents,patterns,safety,comms,dashboard,notifications}
mkdir -p workspace/{tasks,results,messages}
```

### Generate `package.json`

```json
{
  "name": "{project-name}",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "description": "Multi-agent system: {task-description}",
  "scripts": {
    "start": "tsx src/run.ts",
    "dev": "tsx watch src/run.ts"
  },
  "dependencies": {
    "@anthropic-ai/claude-agent-sdk": "^1.0.0",
    "tsx": "^4.0.0"
    // If discord.mode === "interactive", also add: "discord.js": "^14.0.0"
  },
  "devDependencies": {
    "typescript": "^5.5.0",
    "@types/node": "^22.0.0"
  }
}
```

### Generate `tsconfig.json`

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "esModuleInterop": true,
    "strict": true,
    "outDir": "dist",
    "rootDir": "src",
    "declaration": true,
    "resolveJsonModule": true,
    "skipLibCheck": true
  },
  "include": ["src/**/*"]
}
```

### Generate `src/agents/types.ts`

This file defines the core interfaces. Generate it with these types:

```typescript
import type { SandboxSettings } from "@anthropic-ai/claude-agent-sdk";

export type AgentModel = "opus" | "sonnet" | "haiku";

export type PatternType = "orchestrator-workers" | "pipeline" | "debate";

export interface AgentConfig {
  id: string;
  role: string;
  systemPrompt: string;
  allowedTools: string[];
  disallowedTools?: string[];
  sandbox: SandboxSettings;
  model: AgentModel;
  maxTurns?: number;
}

export interface StopConditions {
  maxIterations?: number;
  estimatedCostCapEur?: number;
  timeLimitMinutes?: number;
  validationCheck?: boolean;
  checkpointEveryN?: number;
}

export type DiscordMode = "off" | "updates" | "interactive";

export interface DiscordConfig {
  mode: DiscordMode;
}

export interface ProjectConfig {
  name: string;
  description: string;
  pattern: PatternType;
  agents: AgentConfig[];
  stopConditions: StopConditions;
  discord: DiscordConfig;
  workspacePath: string;
}

export interface AgentStatus {
  id: string;
  role: string;
  state: "waiting" | "working" | "done" | "error" | "paused";
  turns: number;
  estimatedCostEur: number;
  lastActivity: string;
  sessionId?: string;
}

export interface RunMetrics {
  iteration: number;
  startTime: Date;
  totalEstimatedCostEur: number;
  agentStatuses: Map<string, AgentStatus>;
}
```

### Generate `src/config.ts`

Generate this file with the user's approved agent configuration filled in. Example:

```typescript
import type { ProjectConfig } from "./agents/types.js";

export const config: ProjectConfig = {
  name: "{project-name}",
  description: "{task-description}",
  pattern: "{chosen-pattern}",
  agents: [
    // Fill in from the approved agent configuration
    {
      id: "{agent-id}",
      role: "{agent-role}",
      systemPrompt: `{generated-system-prompt-based-on-role-and-task}`,
      allowedTools: [{tools-array}],
      sandbox: {
        enabled: true,
        filesystem: { allowWrite: ["./workspace/**"] },
      },
      model: "{chosen-model}",
      maxTurns: {turns-or-undefined},
    },
    // ... repeat for each agent
  ],
  stopConditions: {
    // Fill in from user's chosen stop conditions
  },
  discord: {
    mode: "{off|updates|interactive}", // From Step 1C
  },
  workspacePath: "./workspace",
};

// EUR conversion rate (approximate, for display only)
export const USD_TO_EUR = 0.92;
```

**Critical:** The `systemPrompt` for each agent MUST include:
1. The agent's role and what it does
2. The overall task description for context
3. Instructions on how to use the workspace directory (where to read input, where to write output)
4. For orchestrator: how to write tasks and read results
5. For workers: how to pick up tasks and write results
6. For pipeline agents: which stage directory to read from and write to
7. For debate agents: where to write proposals

### Generate `src/agents/factory.ts`

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";
import type { AgentConfig, AgentStatus } from "./types.js";
import { USD_TO_EUR } from "../config.js";

export async function runAgent(
  agent: AgentConfig,
  prompt: string,
  cwd: string,
  abortController: AbortController,
  onMessage?: (message: any) => void,
): Promise<{ status: AgentStatus; result: string }> {
  const status: AgentStatus = {
    id: agent.id,
    role: agent.role,
    state: "working",
    turns: 0,
    estimatedCostEur: 0,
    lastActivity: "Starting...",
  };

  let resultText = "";

  try {
    const q = query({
      prompt,
      options: {
        systemPrompt: agent.systemPrompt,
        allowedTools: agent.allowedTools,
        disallowedTools: agent.disallowedTools,
        sandbox: agent.sandbox,
        model: agent.model,
        maxTurns: agent.maxTurns,
        cwd,
        abortController,
        permissionMode: "bypassPermissions",
        allowDangerouslySkipPermissions: true,
      },
    });

    for await (const message of q) {
      onMessage?.(message);

      if (message.type === "assistant") {
        const content = message.message.content;
        if (Array.isArray(content)) {
          for (const block of content) {
            if ("text" in block) {
              status.lastActivity = block.text.slice(0, 100);
            }
          }
        }
        status.turns++;
      }

      if (message.type === "result") {
        if (message.subtype === "success") {
          resultText = message.result ?? "";
          status.estimatedCostEur = (message.total_cost_usd ?? 0) * USD_TO_EUR;
          status.state = "done";
        } else {
          status.state = "error";
          resultText = `Error: ${message.subtype}`;
        }
      }
    }
  } catch (err) {
    status.state = "error";
    status.lastActivity = `Error: ${err instanceof Error ? err.message : String(err)}`;
  }

  return { status, result: resultText };
}
```

### Generate `src/run.ts`

This is the CLI entry point. It loads config, runs the chosen pattern, and displays the dashboard.

```typescript
import { config } from "./config.js";
import { runOrchestrator } from "./patterns/orchestrator-workers.js";
import { runPipeline } from "./patterns/pipeline.js";
import { runDebate } from "./patterns/debate.js";
import { createDashboard } from "./dashboard/terminal-ui.js";
import { checkLimits } from "./safety/limits.js";
import { promptCheckpoint } from "./safety/checkpoints.js";
import { DiscordNotifier } from "./notifications/discord.js";
import type { RunMetrics } from "./agents/types.js";

async function main() {
  console.log(`\n🏭 Agent Factory — "${config.description}"`);
  console.log(`Pattern: ${config.pattern} | Agents: ${config.agents.length}\n`);

  const metrics: RunMetrics = {
    iteration: 0,
    startTime: new Date(),
    totalEstimatedCostEur: 0,
    agentStatuses: new Map(),
  };

  // Initialize agent statuses
  for (const agent of config.agents) {
    metrics.agentStatuses.set(agent.id, {
      id: agent.id,
      role: agent.role,
      state: "waiting",
      turns: 0,
      estimatedCostEur: 0,
      lastActivity: "Not started",
    });
  }

  // Initialize Discord notifications
  const discord = new DiscordNotifier(config.discord, config.name);
  await discord.initialize();
  await discord.notifyRunStarted(config);

  const dashboard = createDashboard(config, metrics);
  const globalAbort = new AbortController();

  // Handle Ctrl+C gracefully
  process.on("SIGINT", () => {
    console.log("\n\n⏹  Graceful shutdown requested...");
    globalAbort.abort();
  });

  // Handle keyboard input for dashboard controls
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on("data", (key) => {
      const char = key.toString().toLowerCase();
      if (char === "s" || char === "\u0003") { // 's' or Ctrl+C
        globalAbort.abort();
      } else if (char === "d") {
        dashboard.toggleDetailView();
      } else if (char === "p") {
        dashboard.togglePause();
      } else if (char === "l") {
        dashboard.showLogs();
      }
    });
  }

  try {
    const patternRunner =
      config.pattern === "orchestrator-workers" ? runOrchestrator
      : config.pattern === "pipeline" ? runPipeline
      : runDebate;

    await patternRunner(config, metrics, globalAbort, dashboard, discord);
  } catch (err) {
    if (!globalAbort.signal.aborted) {
      console.error("\n❌ Unexpected error:", err);
    }
  } finally {
    dashboard.stop();
    // Write final summary
    const summary = generateSummary(metrics);
    const fs = await import("node:fs/promises");
    await fs.writeFile(
      `${config.workspacePath}/summary.md`,
      summary,
    );
    console.log(`\n📋 Summary written to ${config.workspacePath}/summary.md`);

    // Send Discord completion notification and disconnect
    await discord.notifyRunComplete(metrics, config);
    await discord.shutdown();

    process.exit(0);
  }
}

function generateSummary(metrics: RunMetrics): string {
  const elapsed = Math.round((Date.now() - metrics.startTime.getTime()) / 1000);
  const lines = [
    `# Agent Run Summary`,
    ``,
    `**Task:** ${config.description}`,
    `**Pattern:** ${config.pattern}`,
    `**Duration:** ${Math.floor(elapsed / 60)}m ${elapsed % 60}s`,
    `**Iterations:** ${metrics.iteration}`,
    `**Total estimated cost:** ~€${metrics.totalEstimatedCostEur.toFixed(2)}`,
    ``,
    `## Agent Results`,
    ``,
    `| Agent | Role | Status | Turns | Est. Cost |`,
    `|-------|------|--------|-------|-----------|`,
  ];

  for (const [, status] of metrics.agentStatuses) {
    const icon = status.state === "done" ? "✅" : status.state === "error" ? "❌" : "⏳";
    lines.push(
      `| ${status.id} | ${status.role} | ${icon} ${status.state} | ${status.turns} | ~€${status.estimatedCostEur.toFixed(2)} |`,
    );
  }

  lines.push("", "## Workspace Contents", "");
  lines.push("Check `workspace/results/` for detailed outputs from each agent.");

  return lines.join("\n");
}

main();
```

### Generate `src/patterns/orchestrator-workers.ts`

The orchestrator runs in a loop:
1. Reads the task description and any previous results from `workspace/results/`
2. Decides what sub-tasks to delegate (writes JSON to `workspace/tasks/{worker-id}-task-{n}.json`)
3. Each worker gets spawned with a prompt that includes its task file content
4. Worker writes result to `workspace/results/{worker-id}-result-{n}.md`
5. Orchestrator reads all results, decides if done or needs more work
6. Loops until done or stop condition hit

The orchestrator agent's prompt each iteration should be:
> "You are coordinating a team. Here is the overall task: {task}. Here are the results so far: {results}. Write new task assignments to workspace/tasks/ or declare the task DONE by writing a file workspace/DONE.md with the final summary."

Workers receive:
> "You are a {role}. Your assignment is in workspace/tasks/{your-task-file}. Read it, complete the work, and write your result to workspace/results/{your-result-file}."

### Generate `src/patterns/pipeline.ts`

Sequential execution:
1. Agent 1 receives the task, writes output to `workspace/stage-1/`
2. Agent 2 reads `workspace/stage-1/`, processes, writes to `workspace/stage-2/`
3. Continue for all stages
4. Last agent writes final output to `workspace/results/final.md`
5. If validation is enabled, a validation pass checks the final output
6. If validation fails, loop back to stage 1 with feedback

Each pipeline agent's prompt:
> "You are the {role} (stage {n} of {total}). Read your input from workspace/stage-{n-1}/ (or the task description if you're stage 1). Do your work and write your output to workspace/stage-{n}/."

### Generate `src/patterns/debate.ts`

Parallel proposals + judge:
1. All debate agents receive the same task simultaneously (use `Promise.allSettled`)
2. Each writes their proposal to `workspace/proposals/{agent-id}.md`
3. Judge agent reads all proposals from `workspace/proposals/`
4. Judge writes verdict to `workspace/results/verdict.md`
5. If validation is enabled, check if the verdict meets criteria

Judge prompt:
> "You are the judge. Read all proposals in workspace/proposals/. Evaluate each on {criteria}. Pick the best one or synthesize a combined solution. Write your verdict to workspace/results/verdict.md with reasoning."

### Pattern implementation requirements

Each pattern function must:
- Accept `(config, metrics, abortController, dashboard, discord)` arguments
- Check `abortController.signal.aborted` before each iteration
- Call `checkLimits(metrics, config.stopConditions)` after each iteration
- Call `promptCheckpoint(metrics, config.stopConditions, discord)` at checkpoint intervals
- Update `metrics.agentStatuses` and `metrics.totalEstimatedCostEur` in real-time
- Call `dashboard.update()` after each status change
- Call `discord.notifyAgentStatus(status)` when an agent's state changes to working/done/error
- Call `discord.notifyProgress(metrics)` at the end of each iteration

### Generate `src/safety/limits.ts`

Checks all stop conditions:

```typescript
import type { RunMetrics, StopConditions } from "../agents/types.js";

export interface LimitCheckResult {
  shouldStop: boolean;
  reason?: string;
}

export function checkLimits(
  metrics: RunMetrics,
  limits: StopConditions,
): LimitCheckResult {
  // Check iteration limit
  if (limits.maxIterations && metrics.iteration >= limits.maxIterations) {
    return { shouldStop: true, reason: `Max iterations reached (${limits.maxIterations})` };
  }

  // Check estimated cost cap
  if (limits.estimatedCostCapEur && metrics.totalEstimatedCostEur >= limits.estimatedCostCapEur) {
    return {
      shouldStop: true,
      reason: `Estimated cost cap reached (~€${metrics.totalEstimatedCostEur.toFixed(2)} / €${limits.estimatedCostCapEur})`,
    };
  }

  // Check time limit
  if (limits.timeLimitMinutes) {
    const elapsedMinutes = (Date.now() - metrics.startTime.getTime()) / 60_000;
    if (elapsedMinutes >= limits.timeLimitMinutes) {
      return { shouldStop: true, reason: `Time limit reached (${limits.timeLimitMinutes} minutes)` };
    }
  }

  return { shouldStop: false };
}
```

### Generate `src/safety/checkpoints.ts`

Pauses and asks the user to continue:

```typescript
import * as readline from "node:readline";
import type { RunMetrics, StopConditions } from "../agents/types.js";
import type { DiscordNotifier } from "../notifications/discord.js";

export async function promptCheckpoint(
  metrics: RunMetrics,
  limits: StopConditions,
  discord?: DiscordNotifier,
): Promise<boolean> {
  if (!limits.checkpointEveryN) return true;
  if (metrics.iteration % limits.checkpointEveryN !== 0) return true;
  if (metrics.iteration === 0) return true;

  // Try Discord first (interactive mode only)
  if (discord) {
    const response = await discord.promptCheckpoint(metrics);
    if (response === "continue") return true;
    if (response === "stop") return false;
    // "no-response" → fall through to terminal prompt
  }

  // Terminal fallback
  const elapsed = Math.round((Date.now() - metrics.startTime.getTime()) / 1000);

  console.log("\n" + "=".repeat(60));
  console.log("⏸  CHECKPOINT — Iteration", metrics.iteration);
  console.log(`   Elapsed: ${Math.floor(elapsed / 60)}m ${elapsed % 60}s`);
  console.log(`   Estimated cost: ~€${metrics.totalEstimatedCostEur.toFixed(2)}`);
  console.log("=".repeat(60));

  for (const [, status] of metrics.agentStatuses) {
    const icon = status.state === "done" ? "✅" : status.state === "working" ? "🔄" : "⏳";
    console.log(`   ${icon} ${status.id} (${status.role}): ${status.lastActivity}`);
  }

  console.log("=".repeat(60));

  // Send a Discord notification too (even in updates mode) so user knows it's paused
  if (discord) {
    await discord.notifyProgress(metrics);
  }

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const answer = await new Promise<string>((resolve) => {
    rl.question("\nContinue? [Y/n] ", resolve);
  });
  rl.close();

  return answer.toLowerCase() !== "n";
}
```

### Generate `src/safety/sandbox.ts`

Generates per-agent sandbox configs:

```typescript
import type { SandboxSettings } from "@anthropic-ai/claude-agent-sdk";

export type SandboxLevel = "strict" | "moderate" | "open";

export function createSandbox(
  level: SandboxLevel,
  projectDir: string,
  workspacePath: string,
): SandboxSettings {
  switch (level) {
    case "strict":
      return {
        enabled: true,
        filesystem: {
          allowWrite: [`${workspacePath}/**`],
          denyRead: [`${projectDir}/.env*`],
        },
        network: { allowManagedDomainsOnly: true, allowedDomains: [] },
      };
    case "moderate":
      return {
        enabled: true,
        filesystem: {
          allowWrite: [`${projectDir}/**`, `${workspacePath}/**`],
        },
        network: { allowLocalBinding: true },
      };
    case "open":
      return { enabled: false };
  }
}
```

### Generate `src/comms/shared-fs.ts`

Workspace read/write utilities:

```typescript
import * as fs from "node:fs/promises";
import * as path from "node:path";

export async function writeTask(workspacePath: string, agentId: string, iteration: number, content: string): Promise<string> {
  const filePath = path.join(workspacePath, "tasks", `${agentId}-task-${iteration}.json`);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, content, "utf-8");
  return filePath;
}

export async function writeResult(workspacePath: string, agentId: string, iteration: number, content: string): Promise<string> {
  const filePath = path.join(workspacePath, "results", `${agentId}-result-${iteration}.md`);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, content, "utf-8");
  return filePath;
}

export async function readAllResults(workspacePath: string): Promise<Map<string, string>> {
  const resultsDir = path.join(workspacePath, "results");
  const results = new Map<string, string>();
  try {
    const files = await fs.readdir(resultsDir);
    for (const file of files) {
      const content = await fs.readFile(path.join(resultsDir, file), "utf-8");
      results.set(file, content);
    }
  } catch {
    // No results yet
  }
  return results;
}

export async function writeMessage(workspacePath: string, from: string, to: string, content: string): Promise<void> {
  const filePath = path.join(workspacePath, "messages", `${from}-to-${to}-${Date.now()}.json`);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, JSON.stringify({ from, to, content, timestamp: new Date().toISOString() }), "utf-8");
}

export async function checkDone(workspacePath: string): Promise<boolean> {
  try {
    await fs.access(path.join(workspacePath, "DONE.md"));
    return true;
  } catch {
    return false;
  }
}
```

### Generate `src/notifications/discord.ts`

Always generate this file. The `DiscordNotifier` class gracefully no-ops when `mode === "off"` — all public methods return early, so the rest of the codebase doesn't need conditional checks.

**Smart messaging rules — use buttons vs. text appropriately:**
- **Buttons:** Only for actionable decisions — checkpoint continue/stop, permission approve/deny. Always include clear labels and emoji on buttons.
- **Rich embeds:** For status updates, progress reports, summaries. Use color-coded embeds (green=done, yellow=working, red=error, blue=info, purple=progress).
- **Inline fields:** For compact stats (elapsed time, cost, turns) — set `inline: true` so they render side-by-side.
- **Plain text:** Never. Always use embeds for a clean, scannable experience.

```typescript
import type { AgentStatus, RunMetrics, ProjectConfig, DiscordConfig } from "../agents/types.js";

function statusEmoji(state: string): string {
  const map: Record<string, string> = { done: "✅", working: "🔄", waiting: "⏳", error: "❌", paused: "⏸️" };
  return map[state] ?? "❓";
}

function statusColor(state: string): number {
  const map: Record<string, number> = { done: 0x2ecc71, working: 0xf39c12, error: 0xe74c3c, waiting: 0x95a5a6, paused: 0x3498db };
  return map[state] ?? 0x95a5a6;
}

async function sendWebhook(content: object): Promise<void> {
  const url = process.env.DISCORD_WEBHOOK_URL;
  if (!url) return;
  try {
    await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(content),
    });
  } catch {
    // Silently ignore — Discord is best-effort
  }
}

export class DiscordNotifier {
  private config: DiscordConfig;
  private projectName: string;
  private bot: any = null;
  private channel: any = null;

  constructor(config: DiscordConfig, projectName: string) {
    this.config = config;
    this.projectName = projectName;
  }

  async initialize(): Promise<void> {
    if (this.config.mode === "off") return;

    if (this.config.mode === "interactive") {
      try {
        const { Client, GatewayIntentBits } = await import("discord.js");
        this.bot = new Client({
          intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages],
        });

        const token = process.env.DISCORD_BOT_TOKEN;
        const channelId = process.env.DISCORD_CHANNEL_ID;
        if (!token || !channelId) {
          console.warn("⚠️  DISCORD_BOT_TOKEN or DISCORD_CHANNEL_ID missing — Discord disabled");
          this.config.mode = "off";
          return;
        }

        await this.bot.login(token);
        this.channel = await this.bot.channels.fetch(channelId);
        console.log("✅ Discord bot connected");
      } catch (err) {
        console.warn("⚠️  Discord bot connection failed — falling back to terminal:", err);
        this.config.mode = "off";
      }
    } else if (this.config.mode === "updates") {
      if (!process.env.DISCORD_WEBHOOK_URL) {
        console.warn("⚠️  DISCORD_WEBHOOK_URL missing — Discord disabled");
        this.config.mode = "off";
      }
    }
  }

  async notifyRunStarted(projectConfig: ProjectConfig): Promise<void> {
    if (this.config.mode === "off") return;

    const agentList = projectConfig.agents
      .map((a) => `\`${a.id}\` — ${a.role} (${a.model})`)
      .join("\n");

    const embed = {
      title: "🏭 Agent Run Started",
      description: `**${projectConfig.description}**`,
      color: 0x3498db,
      fields: [
        { name: "Pattern", value: projectConfig.pattern, inline: true },
        { name: "Agents", value: String(projectConfig.agents.length), inline: true },
        { name: "\u200b", value: "\u200b", inline: true }, // spacer
        { name: "Team", value: agentList },
      ],
      timestamp: new Date().toISOString(),
    };

    if (this.config.mode === "updates") {
      await sendWebhook({ embeds: [embed] });
    } else if (this.channel) {
      await this.channel.send({ embeds: [embed] });
    }
  }

  async notifyAgentStatus(status: AgentStatus): Promise<void> {
    if (this.config.mode === "off") return;
    // Only notify on meaningful transitions
    if (!["working", "done", "error"].includes(status.state)) return;

    const embed = {
      title: `${statusEmoji(status.state)} ${status.id}`,
      description: status.lastActivity.slice(0, 200),
      color: statusColor(status.state),
      fields: [
        { name: "Role", value: status.role, inline: true },
        { name: "Turns", value: String(status.turns), inline: true },
        { name: "Cost", value: `~€${status.estimatedCostEur.toFixed(2)}`, inline: true },
      ],
      footer: { text: this.projectName },
    };

    if (this.config.mode === "updates") {
      await sendWebhook({ embeds: [embed] });
    } else if (this.channel) {
      await this.channel.send({ embeds: [embed] });
    }
  }

  async notifyProgress(metrics: RunMetrics): Promise<void> {
    if (this.config.mode === "off") return;

    const elapsed = Math.round((Date.now() - metrics.startTime.getTime()) / 1000);
    const agentLines = [...metrics.agentStatuses.values()]
      .map((s) => `${statusEmoji(s.state)} \`${s.id}\` — ${s.lastActivity.slice(0, 60)}`)
      .join("\n");

    const embed = {
      title: `📊 Progress — Iteration ${metrics.iteration}`,
      color: 0x9b59b6,
      fields: [
        { name: "Elapsed", value: `${Math.floor(elapsed / 60)}m ${elapsed % 60}s`, inline: true },
        { name: "Cost", value: `~€${metrics.totalEstimatedCostEur.toFixed(2)}`, inline: true },
        { name: "\u200b", value: "\u200b", inline: true },
        { name: "Agents", value: agentLines },
      ],
      footer: { text: this.projectName },
    };

    if (this.config.mode === "updates") {
      await sendWebhook({ embeds: [embed] });
    } else if (this.channel) {
      await this.channel.send({ embeds: [embed] });
    }
  }

  /**
   * Interactive checkpoint — sends Discord buttons, awaits user response.
   * Returns "continue", "stop", or "no-response" (caller falls back to terminal).
   * Only works in interactive mode with an active bot connection.
   */
  async promptCheckpoint(metrics: RunMetrics): Promise<"continue" | "stop" | "no-response"> {
    if (this.config.mode !== "interactive" || !this.channel) return "no-response";

    const { ActionRowBuilder, ButtonBuilder, ButtonStyle } = await import("discord.js");

    const elapsed = Math.round((Date.now() - metrics.startTime.getTime()) / 1000);
    const agentLines = [...metrics.agentStatuses.values()]
      .map((s) => `${statusEmoji(s.state)} \`${s.id}\` — ${s.lastActivity.slice(0, 60)}`)
      .join("\n");

    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId("checkpoint_continue")
        .setLabel("Continue")
        .setStyle(ButtonStyle.Success)
        .setEmoji("▶️"),
      new ButtonBuilder()
        .setCustomId("checkpoint_stop")
        .setLabel("Stop")
        .setStyle(ButtonStyle.Danger)
        .setEmoji("⏹️"),
    );

    const msg = await this.channel.send({
      embeds: [
        {
          title: `⏸️ Checkpoint — Iteration ${metrics.iteration}`,
          description: "The agent run is paused. **Continue** or **stop**?",
          color: 0xf39c12,
          fields: [
            { name: "Elapsed", value: `${Math.floor(elapsed / 60)}m ${elapsed % 60}s`, inline: true },
            { name: "Cost", value: `~€${metrics.totalEstimatedCostEur.toFixed(2)}`, inline: true },
            { name: "\u200b", value: "\u200b", inline: true },
            { name: "Agents", value: agentLines },
          ],
        },
      ],
      components: [row],
    });

    try {
      const interaction = await msg.awaitMessageComponent({
        filter: (i: any) => i.customId.startsWith("checkpoint_"),
        time: 5 * 60 * 1000, // 5 minutes
      });

      const continued = interaction.customId === "checkpoint_continue";
      await interaction.update({
        embeds: [
          {
            title: continued ? "▶️ Continuing..." : "⏹️ Stopping...",
            color: continued ? 0x2ecc71 : 0xe74c3c,
          },
        ],
        components: [],
      });

      return continued ? "continue" : "stop";
    } catch {
      await msg.edit({
        embeds: [{ title: "⏸️ No response — falling back to terminal", color: 0x95a5a6 }],
        components: [],
      });
      return "no-response";
    }
  }

  async notifyRunComplete(metrics: RunMetrics, projectConfig: ProjectConfig): Promise<void> {
    if (this.config.mode === "off") return;

    const elapsed = Math.round((Date.now() - metrics.startTime.getTime()) / 1000);
    const agentLines = [...metrics.agentStatuses.values()]
      .map(
        (s) =>
          `${statusEmoji(s.state)} \`${s.id}\` (${s.role}) — ${s.turns} turns, ~€${s.estimatedCostEur.toFixed(2)}`,
      )
      .join("\n");

    const allDone = [...metrics.agentStatuses.values()].every((s) => s.state === "done");

    const embed = {
      title: allDone ? "✅ Agent Run Complete" : "⏹️ Agent Run Stopped",
      description: `**${projectConfig.description}**`,
      color: allDone ? 0x2ecc71 : 0xf39c12,
      fields: [
        { name: "Duration", value: `${Math.floor(elapsed / 60)}m ${elapsed % 60}s`, inline: true },
        { name: "Iterations", value: String(metrics.iteration), inline: true },
        { name: "Total Cost", value: `~€${metrics.totalEstimatedCostEur.toFixed(2)}`, inline: true },
        { name: "Agents", value: agentLines },
      ],
      footer: { text: "Results in workspace/results/" },
      timestamp: new Date().toISOString(),
    };

    if (this.config.mode === "updates") {
      await sendWebhook({ embeds: [embed] });
    } else if (this.channel) {
      await this.channel.send({ embeds: [embed] });
    }
  }

  async shutdown(): Promise<void> {
    if (this.bot) {
      this.bot.destroy();
    }
  }
}
```

### Generate `src/dashboard/terminal-ui.ts`

Generate a terminal UI that:
- Renders an overview table (all agents, status, turns, estimated cost, last activity) using ANSI escape codes for formatting
- Supports keyboard controls: `P` (pause/resume), `S` (stop), `D` (toggle detail view), `L` (show logs)
- In detail view: shows streaming output for the selected agent, arrow keys to switch agents
- Updates in-place using `\x1b[2J\x1b[H` (clear screen) on a 500ms interval
- Has a `update()` method called by the pattern runner after each status change
- Has a `stop()` method for graceful cleanup
- Shows the task name, pattern, elapsed time, iteration count, and total estimated cost in a header bar
- Uses box-drawing characters (╔═╗║╚╝) for borders
- Uses emoji for status: ✅ done, 🔄 working, ⏳ waiting, ❌ error, ⏸ paused

Keep the dashboard implementation simple — use raw ANSI codes and `process.stdout.write`, no external TUI library needed. This keeps dependencies minimal.

### Generate `README.md`

Generate a README.md in the project root:

```markdown
# {project-name}

> Generated by `/agent-factory` on {date}

## Task

{task-description}

## Agent Team

| Agent | Role | Model | Tools |
|-------|------|-------|-------|
| ... filled from config ... |

**Pattern:** {pattern-name}

**Communication:** Agents share state via `workspace/` directory.

## Quick Start

\```bash
npm install
npx tsx src/run.ts
\```

## Dashboard Controls

| Key | Action |
|-----|--------|
| `D` | Toggle detail view (see agent live output) |
| `P` | Pause / resume |
| `S` | Graceful stop |
| `L` | Show logs |
| `←` `→` | Switch agent (detail view) |
| `Ctrl+C` | Force stop |

## Stop Conditions

{list enabled stop conditions with their values}

## Customizing

- **Change agents:** Edit `src/config.ts` — modify roles, tools, prompts, models
- **Change limits:** Edit `stopConditions` in `src/config.ts`
- **Change pattern:** Update `config.pattern` (requires matching agent setup)
- **Add tools:** Expand `allowedTools` arrays per agent
- **Adjust sandbox:** Modify `sandbox` settings per agent

## Project Structure

\```
src/
├── run.ts             — Entry point
├── config.ts          — Agent and limit configuration
├── orchestrator.ts    — Main coordination loop
├── agents/            — Agent types and SDK factory
├── patterns/          — Collaboration pattern implementations
├── safety/            — Limits, checkpoints, sandboxing
├── comms/             — Shared workspace utilities
└── dashboard/         — Terminal UI
workspace/             — Agent communication (tasks, results, messages)
\```

## Cost Note

Estimated costs shown in EUR (~€) are informational only. They represent what this run would cost at API pricing. Your actual usage is covered by your Claude Code subscription.
```

### Generate `CLAUDE.md`

Generate a CLAUDE.md in the project root:

```markdown
# CLAUDE.md

## What This Is

A multi-agent collaboration project generated by `/agent-factory`. {agent-count} agents work together using the "{pattern}" pattern to: {task-description}.

## Tech Stack

- TypeScript (run via `tsx`, no build step)
- `@anthropic-ai/claude-agent-sdk` for spawning Claude Code sessions
- Shared filesystem (`workspace/`) for inter-agent communication

## Key Files

- `src/config.ts` — All agent definitions and stop conditions. Edit this to customize.
- `src/run.ts` — Entry point. Run with `npx tsx src/run.ts`.
- `src/patterns/{pattern}.ts` — The collaboration logic.
- `workspace/` — Agents read/write here. Check `workspace/results/` for outputs.

## Running

\```bash
npm install
npx tsx src/run.ts
\```

## Agents

{table of agents with id, role, tools, model}
```

### Generate `.env.example`

```
# Agent Factory Configuration
# Copy to .env and customize

# Override USD→EUR conversion rate (default: 0.92)
# USD_TO_EUR_RATE=0.92

# Discord — Status updates (webhook mode)
# DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...

# Discord — Interactive control (bot mode)
# DISCORD_BOT_TOKEN=your-bot-token-here
# DISCORD_CHANNEL_ID=your-channel-id-here
```

## Step 3 — Install dependencies and offer to run

After generating all files:

1. Install dependencies:
   ```bash
   npm install
   ```

2. Confirm success to the user. Show what was created.

3. Ask the user:
   - **Question:** "Project generated! What do you want to do?"
   - **Options:**
     - **Run it now** — "Start the agents immediately with `npx tsx src/run.ts`"
     - **I'll run it later** — "I'll review the code first and run manually"
     - **Open config** — "Let me tweak the agent configuration before running"

If the user chooses to run, execute:
```bash
npx tsx src/run.ts
```

## Error handling

- **SDK not installed:** If `npm install` fails for `@anthropic-ai/claude-agent-sdk`, check that the user has Claude Code installed and authenticated. The SDK uses the same auth as the CLI.
- **Permission errors during agent run:** If an agent hits a permission error, the dashboard will show it. Suggest adjusting the `sandbox` or `allowedTools` in `config.ts`.
- **Agent stuck in loop:** The checkpoint system catches this. If no checkpoint is configured and an agent loops, the time limit or manual stop (Ctrl+C) will catch it.
- **Workspace conflicts:** If agents write conflicting files, the pattern implementation handles ordering. For orchestrator pattern, only one agent runs at a time per task. For pipeline, stages are sequential. For debate, agents write to separate files.
- **Cost overrun:** The estimated cost cap triggers a graceful stop. Since it's subscription-based, this is informational — but it's still a good proxy for "this task is consuming a lot of resources."

$ARGUMENTS

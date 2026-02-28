---
name: factory
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
    6. In bot permissions, check: **Send Messages**, **Embed Links**, **Read Message History**, **Add Reactions**, **Create Public Threads**, **Send Messages in Threads**
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
mkdir -p workspace/{tasks,results,messages,logs,questions}
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
  currentPipelineStage?: number; // 0-indexed, set by pipeline pattern runner
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
8. **Asking the human for help:** When you are stuck, uncertain, or need a decision, run the helper script: `bash workspace/ask-human.sh --from "{your-id}" --question "Your question here"`. Optionally add `--options "Option A,Option B"` for multiple-choice. The script writes the question file for you. The human will answer and you'll receive the answer as a `[Human answer]: ...` message. Only ask when genuinely stuck — don't ask for things you can figure out yourself.
9. **Confidence signals:** When you are uncertain about a decision or output, prefix the relevant workspace file content with `[LOW CONFIDENCE]` on the first line. This flags the output for human review. Use this sparingly — only when you genuinely think a human should validate your work.
10. For orchestrator/lead agent: When you receive messages prefixed with `[Human via Discord (username)]:` or `[Human answer]:`, treat them as high-priority guidance from the human operator. Acknowledge what you received, explain how it changes your approach, and adapt your strategy accordingly. The username tells you who sent the message. These messages come from the team managing you.

### Generate `src/agents/factory.ts`

This file includes:
- **Agent message logging** — writes timestamped conversations to `{logDir}/{agentId}.log`
- **Active agent registry** — tracks running agents so the input bar can send messages to them
- **Interrupt + resume** — when a human sends a message, the agent's query is interrupted and resumed with the message injected into the conversation

```typescript
import { query } from "@anthropic-ai/claude-agent-sdk";
import * as crypto from "node:crypto";
import * as fs from "node:fs/promises";
import * as path from "node:path";
import type { AgentConfig, AgentStatus } from "./types.js";
import { USD_TO_EUR } from "../config.js";
import { appendStream } from "../comms/shared-fs.js";

function timestamp(): string {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}:${String(d.getSeconds()).padStart(2, "0")}`;
}

async function appendLog(logFile: string, text: string): Promise<void> {
  try {
    await fs.appendFile(logFile, text);
  } catch {
    // Ignore log write failures
  }
}

// Registry of currently running agents — used by the input bar to send messages
export interface ActiveAgent {
  readonly id: string;
  readonly role: string;
  sendMessage(text: string): Promise<void>;
}
export const activeAgents = new Map<string, ActiveAgent>();

export async function runAgent(
  agent: AgentConfig,
  prompt: string,
  cwd: string,
  abortController: AbortController,
  onMessage?: (message: any) => void,
  logDir?: string,
  workspacePath?: string,
  onQuestionDetected?: (agentId: string) => void,
): Promise<{ status: AgentStatus; result: string }> {
  const status: AgentStatus = {
    id: agent.id,
    role: agent.role,
    state: "working",
    turns: 0,
    estimatedCostEur: 0,
    lastActivity: "Starting...",
  };

  // Helper to write to both per-agent log and unified stream
  const stream = (line: string) => {
    if (workspacePath) appendStream(workspacePath, line);
  };

  let resultText = "";
  const logFile = logDir ? path.join(logDir, `${agent.id}.log`) : null;
  const sessionId = crypto.randomUUID();
  let pendingMessage: string | null = null;
  let currentQuery: ReturnType<typeof query> | null = null;

  // Register in active agents registry
  activeAgents.set(agent.id, {
    id: agent.id,
    role: agent.role,
    async sendMessage(text: string) {
      pendingMessage = text;
      if (currentQuery) {
        try { await currentQuery.interrupt(); } catch {}
      }
    },
  });

  stream(`[${timestamp()}] START ${agent.id} (${agent.role}) — model: ${agent.model}\n`);

  try {
    let currentPrompt = prompt;
    let isResume = false;

    while (!abortController.signal.aborted) {
      currentQuery = query({
        prompt: currentPrompt,
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
          ...(isResume ? { resume: sessionId } : { sessionId }),
        },
      });

      if (logFile && isResume) {
        appendLog(logFile, `[${timestamp()}] === HUMAN MESSAGE ===\n${currentPrompt}\n\n`);
        stream(`[${timestamp()}] HMSG  ${agent.id} <- human: ${currentPrompt.slice(0, 120).replace(/\n/g, " ")}\n`);
      }

      for await (const message of currentQuery) {
        onMessage?.(message);

        if (message.type === "assistant") {
          const content = message.message.content;
          if (Array.isArray(content)) {
            for (const block of content) {
              if ("text" in block) {
                status.lastActivity = block.text.slice(0, 100);
                if (logFile) {
                  appendLog(logFile, `[${timestamp()}] === ASSISTANT (turn ${status.turns + 1}) ===\n${block.text}\n\n`);
                }
                stream(`[${timestamp()}] THINK ${agent.id}: ${block.text.slice(0, 150).replace(/\n/g, " ")}\n`);
              }
              if ("type" in block && block.type === "tool_use") {
                if (logFile) {
                  const input = JSON.stringify(block.input).slice(0, 500);
                  appendLog(logFile, `[${timestamp()}] === TOOL CALL: ${block.name} ===\n${input}\n\n`);
                }
                stream(`[${timestamp()}] TOOL  ${agent.id} -> ${block.name}\n`);

                // Detect question file writes for instant notification
                if (onQuestionDetected) {
                  const inputStr = JSON.stringify(block.input);
                  if (inputStr.includes("workspace/questions/") || inputStr.includes("ask-human.sh")) {
                    onQuestionDetected(agent.id);
                  }
                }
              }
              if ("type" in block && block.type === "tool_result") {
                if (logFile) {
                  const output = typeof block.content === "string"
                    ? block.content.slice(0, 300)
                    : JSON.stringify(block.content).slice(0, 300);
                  appendLog(logFile, `[${timestamp()}] === TOOL RESULT ===\n${output}\n\n`);
                }
              }
            }
          }
          status.turns++;
        }

        if (message.type === "result") {
          if (message.subtype === "success") {
            resultText = message.result ?? "";
            status.estimatedCostEur = (message.total_cost_usd ?? 0) * USD_TO_EUR;
            status.sessionId = message.session_id;
            status.state = "done";
            if (logFile) {
              appendLog(logFile, `[${timestamp()}] === RESULT: success | Cost: $${(message.total_cost_usd ?? 0).toFixed(2)} | Session: ${message.session_id ?? "n/a"} ===\n\n`);
            }
            stream(`[${timestamp()}] END   ${agent.id} — success | cost: $${(message.total_cost_usd ?? 0).toFixed(2)}\n`);
          } else {
            status.state = "error";
            resultText = `Error: ${message.subtype}`;
            if (logFile) {
              appendLog(logFile, `[${timestamp()}] === RESULT: ${message.subtype} ===\n\n`);
            }
            stream(`[${timestamp()}] ERROR ${agent.id} — ${message.subtype}\n`);
          }
        }
      }

      // After query ends, check for pending human message
      if (pendingMessage && !abortController.signal.aborted) {
        currentPrompt = pendingMessage;
        pendingMessage = null;
        isResume = true;
        status.state = "working";
        status.lastActivity = "Processing human message...";
        continue;
      }

      break; // Normal completion
    }
  } catch (err) {
    status.state = "error";
    status.lastActivity = `Error: ${err instanceof Error ? err.message : String(err)}`;
    stream(`[${timestamp()}] ERROR ${agent.id} — ${err instanceof Error ? err.message : String(err)}\n`);
  } finally {
    activeAgents.delete(agent.id);
    currentQuery = null;
  }

  return { status, result: resultText };
}
```

### Generate `src/run.ts`

This is the CLI entry point. It loads config, runs the chosen pattern, and displays the dashboard. It includes:
- **Force quit** — double-press S or Ctrl+C for immediate exit
- **SIGTERM handler** — graceful shutdown on SIGTERM
- **Inline message input** — always-visible input bar at the bottom; type `@agent: message` and press Enter to interrupt and inject a human message; `@all:` broadcasts to all active agents; Tab autocompletes agent IDs
- **Logs directory** — `workspace/logs/` created alongside other workspace dirs
- **Keyboard routing** — all keystrokes go through `dashboard.handleInput(key)` which routes to either the input bar or navigation controls depending on context

```typescript
import * as path from "node:path";
import * as fs from "node:fs/promises";
import { config } from "./config.js";
import { runOrchestrator } from "./patterns/orchestrator-workers.js";
import { runPipeline } from "./patterns/pipeline.js";
import { runDebate } from "./patterns/debate.js";
import { createDashboard } from "./dashboard/terminal-ui.js";
import { checkLimits } from "./safety/limits.js";
import { promptCheckpoint } from "./safety/checkpoints.js";
import { DiscordNotifier } from "./notifications/discord.js";
import type { AgentQuestion } from "./notifications/discord.js";
import { activeAgents } from "./agents/factory.js";
import { appendStream } from "./comms/shared-fs.js";
import type { RunMetrics } from "./agents/types.js";

/** Determine which agent should receive human messages based on pattern */
function getLeadAgentId(): string {
  if (config.pattern === "orchestrator-workers") {
    return config.agents[0].id; // orchestrator is always first
  } else if (config.pattern === "pipeline") {
    // Use tracked pipeline stage if available, otherwise fall back to first
    const stage = metrics?.currentPipelineStage;
    if (stage !== undefined && stage >= 0 && stage < config.agents.length) {
      return config.agents[stage].id;
    }
    return config.agents[0].id;
  } else {
    // debate — judge is last agent
    return config.agents[config.agents.length - 1].id;
  }
}

// Module-level reference so getLeadAgentId can access it
let metrics: RunMetrics;

async function main() {
  console.log(`\n🏭 Agent Factory — "${config.description}"`);
  console.log(`Pattern: ${config.pattern} | Agents: ${config.agents.length}\n`);

  metrics = {
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

  // Create workspace dirs
  for (const dir of ["tasks", "results", "messages", ".state", "logs", "questions"]) {
    await fs.mkdir(path.join(config.workspacePath, dir), { recursive: true });
  }

  // Initialize Discord notifications
  const discord = new DiscordNotifier(config.discord, config.name);
  await discord.initialize();

  const workspacePath = path.resolve(config.workspacePath);

  // Route Discord messages to the lead agent
  discord.setMessageHandler(async (text: string, username: string) => {
    const leadId = getLeadAgentId();
    const agent = activeAgents.get(leadId);
    if (agent) {
      await agent.sendMessage(`[Human via Discord (${username})]: ${text}`);
      appendStream(workspacePath, `[${ts()}] HMSG  ${username} (discord) -> ${leadId}: ${text.slice(0, 120)}\n`);
      await discord.notifyHumanMessageDelivered(leadId, text);

      // Watch for agent acknowledgment + reaction summary
      // Check every 5s for agent activity, cap at 60s
      const deliveryLineCount = await getStreamLineCount();
      let ackSent = false;
      let checks = 0;
      const ackInterval = setInterval(async () => {
        checks++;
        if (checks > 12) { // 60s max
          clearInterval(ackInterval);
          return;
        }
        try {
          const streamFile = path.join(workspacePath, "logs", "_stream.log");
          const content = await fs.readFile(streamFile, "utf-8");
          const lines = content.split("\n").filter(Boolean);
          const newLines = lines.slice(deliveryLineCount);

          // Look for the agent's first THINK after our message
          if (!ackSent) {
            const agentThink = newLines.find((l) => l.includes(`THINK ${leadId}:`));
            if (agentThink) {
              const thinkText = agentThink.replace(/.*THINK \S+: /, "");
              await discord.notifyAgentAcknowledgment(leadId, thinkText);
              ackSent = true;
            }
          }

          // Once we have activity, wait 5s more for settling, then send summary
          if (ackSent && checks >= 2) {
            const importantLines = newLines.filter((l) =>
              !l.includes("THINK") && !l.includes("TOOL ")
            );
            if (importantLines.length > 0 || checks > 6) {
              await discord.notifyReactionSummary(leadId, newLines.slice(-15));
              clearInterval(ackInterval);
            }
          }
        } catch {}
      }, 5_000);

      async function getStreamLineCount(): Promise<number> {
        try {
          const streamFile = path.join(workspacePath, "logs", "_stream.log");
          const content = await fs.readFile(streamFile, "utf-8");
          return content.split("\n").filter(Boolean).length;
        } catch { return 0; }
      }
    }
  });

  await discord.notifyRunStarted(config);

  const dashboard = createDashboard(config, metrics, workspacePath);
  const globalAbort = new AbortController();
  let shutdownRequested = false;

  function handleShutdown() {
    if (shutdownRequested) {
      dashboard.stop();
      console.log("\nForce quit!");
      process.exit(1);
    }
    shutdownRequested = true;
    appendStream(workspacePath, `[${ts()}] SYS   Graceful shutdown requested...\n`);
    globalAbort.abort();
  }

  // Handle Ctrl+C and SIGTERM
  process.on("SIGINT", handleShutdown);
  process.on("SIGTERM", handleShutdown);

  // Send message from input bar to target agent(s)
  async function sendInputMessage(target: string, message: string): Promise<void> {
    if (target === "all") {
      for (const a of activeAgents.values()) {
        await a.sendMessage(message);
      }
      appendStream(workspacePath, `[${ts()}] HMSG  human -> all: ${message.slice(0, 120)}\n`);
    } else {
      const agent = activeAgents.get(target);
      if (agent) {
        await agent.sendMessage(message);
        appendStream(workspacePath, `[${ts()}] HMSG  human -> ${target}: ${message.slice(0, 120)}\n`);
      }
    }
  }

  // Answer an agent question from the terminal
  async function answerQuestion(agentId: string, answer: string): Promise<void> {
    const agent = activeAgents.get(agentId);
    if (agent) {
      await agent.sendMessage(`[Human answer]: ${answer}`);
      appendStream(workspacePath, `[${ts()}] HMSG  human -> ${agentId} (answer): ${answer.slice(0, 120)}\n`);
    }
  }

  // Watch workspace/results/ for [LOW CONFIDENCE] outputs
  const seenResults = new Set<string>();
  const confidenceWatcher = setInterval(async () => {
    if (globalAbort.signal.aborted) return;
    try {
      const resultsDir = path.join(workspacePath, "results");
      const files = await fs.readdir(resultsDir);
      for (const file of files) {
        if (seenResults.has(file)) continue;
        seenResults.add(file);
        const filePath = path.join(resultsDir, file);
        const content = await fs.readFile(filePath, "utf-8");
        if (content.startsWith("[LOW CONFIDENCE]")) {
          const agentId = file.split("-")[0]; // e.g. "researcher-result-1.md" → "researcher"
          appendStream(workspacePath, `[${ts()}] WARN  ${agentId} flagged low confidence on ${file}\n`);
          const response = await discord.promptConfidenceReview(agentId, content.slice(0, 2000));
          if (response === "review") {
            // Show in terminal and ask for guidance
            const guidance = await dashboard.showQuestion({
              from: agentId,
              question: `Low confidence output in ${file}. Review and provide guidance:`,
            });
            if (guidance) {
              const agent = activeAgents.get(agentId);
              if (agent) {
                await agent.sendMessage(`[Human review]: Your output in ${file} was flagged for review. Guidance: ${guidance}`);
                appendStream(workspacePath, `[${ts()}] HMSG  human -> ${agentId} (review): ${guidance.slice(0, 120)}\n`);
              }
            }
          }
        }
      }
    } catch {}
  }, 5000);

  // Watch workspace/questions/ for new question files from agents
  const questionsDir = path.join(workspacePath, "questions");
  const seenQuestions = new Set<string>();

  const questionWatcher = setInterval(async () => {
    if (globalAbort.signal.aborted) return;
    try {
      const files = await fs.readdir(questionsDir);
      for (const file of files) {
        if (seenQuestions.has(file)) continue;
        if (!file.endsWith(".json")) continue;
        seenQuestions.add(file);

        const filePath = path.join(questionsDir, file);
        const raw = await fs.readFile(filePath, "utf-8");
        const question: AgentQuestion = JSON.parse(raw);
        if (question.answered) continue;

        appendStream(workspacePath, `[${ts()}] QUEST ${question.from}: ${question.question.slice(0, 120)}\n`);

        // Race: Discord prompt vs terminal prompt — first answer wins
        // Use an AbortController so the loser can clean up its listener
        const raceAbort = new AbortController();
        const discordPromise = discord.promptQuestion(question, raceAbort.signal);
        const terminalPromise = dashboard.showQuestion(question, raceAbort.signal);

        const result = await Promise.race([
          discordPromise.then((a) => ({ answer: a, source: "discord" as const })),
          terminalPromise.then((a) => ({ answer: a, source: "terminal" as const })),
        ]);

        // Signal the loser to stop listening
        raceAbort.abort();

        const finalAnswer = result.answer;
        const source = result.source;

        if (finalAnswer) {
          // Update question file
          question.answered = true;
          question.answer = finalAnswer;
          await fs.writeFile(filePath, JSON.stringify(question, null, 2));

          // Inject answer into the asking agent
          await answerQuestion(question.from, finalAnswer);
          appendStream(workspacePath, `[${ts()}] HMSG  human -> ${question.from} (${source}): ${finalAnswer.slice(0, 120)}\n`);
        } else {
          // Both timed out — inject fallback so the agent isn't blocked forever
          const fallback = "No response received. Proceed with your best judgment.";
          question.answered = true;
          question.answer = fallback;
          await fs.writeFile(filePath, JSON.stringify(question, null, 2));
          await answerQuestion(question.from, fallback);
          appendStream(workspacePath, `[${ts()}] HMSG  human -> ${question.from} (timeout): ${fallback}\n`);
        }
      }
    } catch {
      // Best effort — questions dir may not exist yet
    }
  }, 2000);

  // All keyboard input goes through the dashboard's handleInput method
  if (process.stdin.isTTY) {
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.on("data", (key) => {
      const bytes = key as Buffer;

      // Ctrl+C always triggers shutdown regardless of input state
      if (bytes[0] === 0x03) {
        handleShutdown();
        return;
      }

      // Route all input through dashboard
      dashboard.handleInput(bytes, {
        onShutdown: handleShutdown,
        onSendMessage: sendInputMessage,
        getActiveAgentIds: () => [...activeAgents.keys()],
        getAllAgentIds: () => config.agents.map((a) => a.id),
      });
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
    clearInterval(questionWatcher);
    clearInterval(confidenceWatcher);
    dashboard.stop();

    // Write final summary
    const summary = generateSummary(metrics);
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

function ts(): string {
  return new Date().toTimeString().slice(0, 8);
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
  lines.push("Check `workspace/logs/` for full agent conversation transcripts.");
  lines.push("Check `workspace/logs/_stream.log` for the unified activity stream.");

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

**Pipeline stage tracking:** Before running each stage agent, set `metrics.currentPipelineStage = stageIndex` (0-indexed). This ensures human Discord messages route to the currently active pipeline agent.

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
- Compute `const logDir = path.join(config.workspacePath, "logs")` at the top
- Pass `logDir`, `config.workspacePath`, and an `onQuestionDetected` callback as the last three arguments to every `runAgent()` call (after `onMessage`) — both dirs are needed for per-agent logs and the unified stream, and the callback logs a QUEST event early (the question watcher picks up the file on its next 2s poll)
- Check `abortController.signal.aborted` before each iteration
- Call `checkLimits(metrics, config.stopConditions)` after each iteration
- Call `promptCheckpoint(metrics, config.stopConditions, discord)` at checkpoint intervals
- Update `metrics.agentStatuses` and `metrics.totalEstimatedCostEur` in real-time
- Call `dashboard.update()` after each status change
- Call `discord.notifyAgentStatus(status)` when an agent's state changes to working/done/error
- **Error escalation:** When an agent finishes with `state === "error"`, call `discord.promptErrorEscalation(agentId, errorMessage)`. Based on the response:
  - `"retry"` → re-run the agent with the same prompt
  - `"skip"` → continue to the next agent/iteration without this agent's result
  - `"stop"` → abort the entire run via `abortController.abort()`
  - `"no-response"` → default behavior (skip for orchestrator workers, stop for pipeline)
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

function ts(): string {
  const d = new Date();
  return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}:${String(d.getSeconds()).padStart(2, "0")}`;
}

// Unified stream log — all agents + inter-agent comms in one chronological file
export async function appendStream(workspacePath: string, line: string): Promise<void> {
  try {
    const streamFile = path.join(workspacePath, "logs", "_stream.log");
    await fs.appendFile(streamFile, line);
  } catch {
    // Best-effort logging
  }
}

export async function writeTask(workspacePath: string, agentId: string, iteration: number, content: string): Promise<string> {
  const filePath = path.join(workspacePath, "tasks", `${agentId}-task-${iteration}.json`);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, content, "utf-8");
  const preview = content.slice(0, 120).replace(/\n/g, " ");
  appendStream(workspacePath, `[${ts()}] TASK  ${agentId} <- task-${iteration}: ${preview}\n`);
  return filePath;
}

export async function writeResult(workspacePath: string, agentId: string, iteration: number, content: string): Promise<string> {
  const filePath = path.join(workspacePath, "results", `${agentId}-result-${iteration}.md`);
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  await fs.writeFile(filePath, content, "utf-8");
  const preview = content.slice(0, 120).replace(/\n/g, " ");
  appendStream(workspacePath, `[${ts()}] DONE  ${agentId} -> result-${iteration}: ${preview}\n`);
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
  const preview = content.slice(0, 120).replace(/\n/g, " ");
  appendStream(workspacePath, `[${ts()}] MSG   ${from} -> ${to}: ${preview}\n`);
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
import * as fs from "node:fs/promises";
import * as path from "node:path";
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

export interface AgentQuestion {
  from: string;
  question: string;
  options?: string[];
  answered?: boolean;
  answer?: string;
}

export class DiscordNotifier {
  private config: DiscordConfig;
  private projectName: string;
  private bot: any = null;
  private channel: any = null;
  private thread: any = null;
  private messageHandler: ((text: string, username: string) => void) | null = null;
  private questionPending = false; // Suppress messageCreate during question prompts

  constructor(config: DiscordConfig, projectName: string) {
    this.config = config;
    this.projectName = projectName;
  }

  /** Register a handler for incoming Discord messages → orchestrator. Receives (text, username). */
  setMessageHandler(handler: (text: string, username: string) => void): void {
    this.messageHandler = handler;
  }

  async initialize(): Promise<void> {
    if (this.config.mode === "off") return;

    if (this.config.mode === "interactive") {
      try {
        const { Client, GatewayIntentBits } = await import("discord.js");
        this.bot = new Client({
          intents: [
            GatewayIntentBits.Guilds,
            GatewayIntentBits.GuildMessages,
            GatewayIntentBits.MessageContent,
          ],
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

        // Create a thread for this run — keeps the main channel clean
        const threadName = `🏭 ${this.projectName} — ${new Date().toLocaleString()}`;
        this.thread = await this.channel.threads.create({
          name: threadName.slice(0, 100),
          autoArchiveDuration: 1440, // 24 hours
          reason: "Agent Factory run",
        });

        // Post thread link in main channel
        await this.channel.send({
          embeds: [{
            title: "🏭 Agent run started",
            description: `Follow along in the thread: ${this.thread}`,
            color: 0x3498db,
          }],
        });

        // Listen for messages in the thread
        this.bot.on("messageCreate", (msg: any) => {
          if (msg.author.bot) return;
          // Only listen in our thread
          if (this.thread && msg.channel.id !== this.thread.id) return;
          // Skip routing when a question prompt is active — let awaitMessages handle it
          if (this.questionPending) return;
          // React to confirm receipt
          msg.react("👂").catch(() => {});
          // Route to handler with username for attribution
          if (this.messageHandler) {
            const username = msg.author.displayName || msg.author.username;
            this.messageHandler(msg.content, username);
          }
        });

        console.log(`✅ Discord bot connected — thread: ${threadName}`);
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

  /** Send to the thread (interactive mode) or channel (updates mode) */
  private async send(content: object): Promise<any> {
    if (this.config.mode === "updates") {
      await sendWebhook(content);
      return null;
    }
    const target = this.thread ?? this.channel;
    if (target) {
      return target.send(content);
    }
    return null;
  }

  async notifyRunStarted(projectConfig: ProjectConfig): Promise<void> {
    if (this.config.mode === "off") return;

    const agentList = projectConfig.agents
      .map((a) => `\`${a.id}\` — ${a.role} (${a.model})`)
      .join("\n");

    await this.send({
      embeds: [{
        title: "🏭 Agent Run Started",
        description: `**${projectConfig.description}**`,
        color: 0x3498db,
        fields: [
          { name: "Pattern", value: projectConfig.pattern, inline: true },
          { name: "Agents", value: String(projectConfig.agents.length), inline: true },
          { name: "\u200b", value: "\u200b", inline: true },
          { name: "Team", value: agentList },
        ],
        timestamp: new Date().toISOString(),
      }],
    });
  }

  async notifyAgentStatus(status: AgentStatus): Promise<void> {
    if (this.config.mode === "off") return;
    if (!["working", "done", "error"].includes(status.state)) return;

    await this.send({
      embeds: [{
        title: `${statusEmoji(status.state)} ${status.id}`,
        description: status.lastActivity.slice(0, 200),
        color: statusColor(status.state),
        fields: [
          { name: "Role", value: status.role, inline: true },
          { name: "Turns", value: String(status.turns), inline: true },
          { name: "Cost", value: `~€${status.estimatedCostEur.toFixed(2)}`, inline: true },
        ],
        footer: { text: this.projectName },
      }],
    });
  }

  /** Confirmation embed when a human Discord message is delivered to an agent */
  async notifyHumanMessageDelivered(agentId: string, text: string): Promise<void> {
    if (this.config.mode !== "interactive") return;
    await this.send({
      embeds: [{
        title: "💬 Message delivered",
        description: `Your message was sent to **${agentId}**:\n> ${text.slice(0, 200)}`,
        color: 0x3498db,
        footer: { text: "The agent will process this on its next turn" },
      }],
    });
  }

  /** Echo back what the agent said after receiving a human message */
  async notifyAgentAcknowledgment(agentId: string, response: string): Promise<void> {
    if (this.config.mode !== "interactive") return;
    await this.send({
      embeds: [{
        title: `💭 ${agentId} responded`,
        description: response.slice(0, 2000),
        color: 0x2ecc71,
      }],
    });
  }

  async notifyProgress(metrics: RunMetrics): Promise<void> {
    if (this.config.mode === "off") return;

    const elapsed = Math.round((Date.now() - metrics.startTime.getTime()) / 1000);
    const agentLines = [...metrics.agentStatuses.values()]
      .map((s) => `${statusEmoji(s.state)} \`${s.id}\` — ${s.lastActivity.slice(0, 60)}`)
      .join("\n");

    await this.send({
      embeds: [{
        title: `📊 Progress — Iteration ${metrics.iteration}`,
        color: 0x9b59b6,
        fields: [
          { name: "Elapsed", value: `${Math.floor(elapsed / 60)}m ${elapsed % 60}s`, inline: true },
          { name: "Cost", value: `~€${metrics.totalEstimatedCostEur.toFixed(2)}`, inline: true },
          { name: "\u200b", value: "\u200b", inline: true },
          { name: "Agents", value: agentLines },
        ],
        footer: { text: this.projectName },
      }],
    });
  }

  /**
   * Post an agent question to Discord. If options are provided, shows buttons.
   * Otherwise waits for a text reply. Returns the answer or null on timeout.
   */
  async promptQuestion(question: AgentQuestion, abortSignal?: AbortSignal): Promise<string | null> {
    if (this.config.mode !== "interactive") return null;
    const target = this.thread ?? this.channel;
    if (!target) return null;

    // If already aborted (terminal answered first), return immediately
    if (abortSignal?.aborted) return null;

    this.questionPending = true;
    const { ActionRowBuilder, ButtonBuilder, ButtonStyle } = await import("discord.js");

    const embed = {
      title: `❓ ${question.from} needs your input`,
      description: question.question,
      color: 0xe67e22, // orange
      footer: { text: "Reply in this thread or click a button" },
    };

    if (question.options && question.options.length > 0) {
      const row = new ActionRowBuilder();
      for (const opt of question.options.slice(0, 5)) {
        row.addComponents(
          new ButtonBuilder()
            .setCustomId(`question_${opt}`)
            .setLabel(opt.slice(0, 80))
            .setStyle(ButtonStyle.Primary),
        );
      }

      const msg = await target.send({ embeds: [embed], components: [row] });

      // Clean up on abort (terminal won the race)
      const cleanup = () => {
        msg.edit({ embeds: [{ title: "✅ Answered via terminal", color: 0x2ecc71 }], components: [] }).catch(() => {});
      };
      if (abortSignal) abortSignal.addEventListener("abort", cleanup, { once: true });

      try {
        const buttonPromise = msg.awaitMessageComponent({
          filter: (i: any) => i.customId.startsWith("question_"),
          time: 10 * 60 * 1000,
        }).then(async (interaction: any) => {
          const answer = interaction.customId.replace("question_", "");
          await interaction.update({
            embeds: [{ title: `✅ Answered: ${answer}`, color: 0x2ecc71 }],
            components: [],
          });
          return answer;
        });

        const replyPromise = target.awaitMessages({
          filter: (m: any) => !m.author.bot,
          max: 1,
          time: 10 * 60 * 1000,
        }).then((collected: any) => {
          const reply = collected.first();
          if (!reply) return null;
          msg.edit({ embeds: [{ title: `✅ Answered via reply`, color: 0x2ecc71 }], components: [] }).catch(() => {});
          return reply.content;
        });

        // Also race against the abort signal
        const abortPromise = abortSignal
          ? new Promise<null>((resolve) => abortSignal.addEventListener("abort", () => resolve(null), { once: true }))
          : new Promise<null>(() => {}); // never resolves

        return await Promise.race([buttonPromise, replyPromise, abortPromise]);
      } catch {
        await msg.edit({
          embeds: [{ title: "⏰ Question timed out", color: 0x95a5a6 }],
          components: [],
        });
        return null;
      } finally {
        this.questionPending = false;
        if (abortSignal) abortSignal.removeEventListener("abort", cleanup);
      }
    } else {
      const msg = await target.send({ embeds: [embed] });

      const cleanup = () => {
        msg.edit({ embeds: [{ title: "✅ Answered via terminal", color: 0x2ecc71 }] }).catch(() => {});
      };
      if (abortSignal) abortSignal.addEventListener("abort", cleanup, { once: true });

      try {
        const replyPromise = target.awaitMessages({
          filter: (m: any) => !m.author.bot,
          max: 1,
          time: 10 * 60 * 1000,
        }).then((collected: any) => {
          const reply = collected.first();
          if (!reply) return null;
          msg.edit({ embeds: [{ title: "✅ Answered", color: 0x2ecc71 }] }).catch(() => {});
          return reply.content;
        });

        const abortPromise = abortSignal
          ? new Promise<null>((resolve) => abortSignal.addEventListener("abort", () => resolve(null), { once: true }))
          : new Promise<null>(() => {});

        return await Promise.race([replyPromise, abortPromise]);
      } catch {
        await msg.edit({ embeds: [{ title: "⏰ Question timed out", color: 0x95a5a6 }] });
        return null;
      } finally {
        this.questionPending = false;
        if (abortSignal) abortSignal.removeEventListener("abort", cleanup);
      }
    }
  }

  /**
   * Post a reaction summary — shows what happened after a human message.
   * Called ~30s after a human message is delivered.
   */
  async notifyReactionSummary(agentId: string, recentLines: string[]): Promise<void> {
    if (this.config.mode === "off") return;
    if (recentLines.length === 0) return;

    const body = recentLines.slice(-10).map((l) => `\`${l.trim()}\``).join("\n");

    await this.send({
      embeds: [{
        title: `🔄 What happened after your message to ${agentId}`,
        description: body.slice(0, 4000),
        color: 0x9b59b6,
        footer: { text: `${recentLines.length} recent events` },
      }],
    });
  }

  /**
   * Error escalation — actionable embed with Retry/Skip/Stop buttons.
   * Returns the user's choice or "no-response" on timeout.
   */
  async promptErrorEscalation(
    agentId: string,
    error: string,
  ): Promise<"retry" | "skip" | "stop" | "no-response"> {
    if (this.config.mode !== "interactive") return "no-response";
    const target = this.thread ?? this.channel;
    if (!target) return "no-response";

    const { ActionRowBuilder, ButtonBuilder, ButtonStyle } = await import("discord.js");

    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId("error_retry")
        .setLabel("Retry")
        .setStyle(ButtonStyle.Primary)
        .setEmoji("🔄"),
      new ButtonBuilder()
        .setCustomId("error_skip")
        .setLabel("Skip")
        .setStyle(ButtonStyle.Secondary)
        .setEmoji("⏭️"),
      new ButtonBuilder()
        .setCustomId("error_stop")
        .setLabel("Stop")
        .setStyle(ButtonStyle.Danger)
        .setEmoji("⏹️"),
    );

    const msg = await target.send({
      embeds: [{
        title: `❌ Error in ${agentId}`,
        description: `\`\`\`\n${error.slice(0, 1000)}\n\`\`\``,
        color: 0xe74c3c,
        footer: { text: "Choose an action" },
      }],
      components: [row],
    });

    try {
      const interaction = await msg.awaitMessageComponent({
        filter: (i: any) => i.customId.startsWith("error_"),
        time: 5 * 60 * 1000,
      });

      const action = interaction.customId.replace("error_", "") as "retry" | "skip" | "stop";
      const labels: Record<string, string> = { retry: "🔄 Retrying...", skip: "⏭️ Skipping...", stop: "⏹️ Stopping..." };
      await interaction.update({
        embeds: [{ title: labels[action], color: action === "stop" ? 0xe74c3c : 0x3498db }],
        components: [],
      });
      return action;
    } catch {
      await msg.edit({
        embeds: [{ title: "⏰ No response — continuing", color: 0x95a5a6 }],
        components: [],
      });
      return "no-response";
    }
  }

  /**
   * Confidence signal — posts a review embed with Accept/Review buttons.
   * Returns "accept", "review", or "no-response".
   */
  async promptConfidenceReview(
    agentId: string,
    content: string,
  ): Promise<"accept" | "review" | "no-response"> {
    if (this.config.mode !== "interactive") return "no-response";
    const target = this.thread ?? this.channel;
    if (!target) return "no-response";

    const { ActionRowBuilder, ButtonBuilder, ButtonStyle } = await import("discord.js");

    const row = new ActionRowBuilder().addComponents(
      new ButtonBuilder()
        .setCustomId("confidence_accept")
        .setLabel("Accept")
        .setStyle(ButtonStyle.Success)
        .setEmoji("✅"),
      new ButtonBuilder()
        .setCustomId("confidence_review")
        .setLabel("Review")
        .setStyle(ButtonStyle.Primary)
        .setEmoji("🔍"),
    );

    const msg = await target.send({
      embeds: [{
        title: `⚠️ ${agentId} flagged low confidence`,
        description: content.slice(0, 2000),
        color: 0xf39c12,
        footer: { text: "Accept to continue, or Review to provide guidance" },
      }],
      components: [row],
    });

    try {
      const interaction = await msg.awaitMessageComponent({
        filter: (i: any) => i.customId.startsWith("confidence_"),
        time: 5 * 60 * 1000,
      });

      const action = interaction.customId.replace("confidence_", "") as "accept" | "review";
      await interaction.update({
        embeds: [{ title: action === "accept" ? "✅ Accepted" : "🔍 Reviewing...", color: 0x2ecc71 }],
        components: [],
      });
      return action;
    } catch {
      await msg.edit({
        embeds: [{ title: "⏰ No response — accepting", color: 0x95a5a6 }],
        components: [],
      });
      return "no-response";
    }
  }

  async promptCheckpoint(metrics: RunMetrics): Promise<"continue" | "stop" | "no-response"> {
    if (this.config.mode !== "interactive") return "no-response";
    const target = this.thread ?? this.channel;
    if (!target) return "no-response";

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

    const msg = await target.send({
      embeds: [{
        title: `⏸️ Checkpoint — Iteration ${metrics.iteration}`,
        description: "The agent run is paused. **Continue** or **stop**?",
        color: 0xf39c12,
        fields: [
          { name: "Elapsed", value: `${Math.floor(elapsed / 60)}m ${elapsed % 60}s`, inline: true },
          { name: "Cost", value: `~€${metrics.totalEstimatedCostEur.toFixed(2)}`, inline: true },
          { name: "\u200b", value: "\u200b", inline: true },
          { name: "Agents", value: agentLines },
        ],
      }],
      components: [row],
    });

    try {
      const interaction = await msg.awaitMessageComponent({
        filter: (i: any) => i.customId.startsWith("checkpoint_"),
        time: 5 * 60 * 1000,
      });

      const continued = interaction.customId === "checkpoint_continue";
      await interaction.update({
        embeds: [{
          title: continued ? "▶️ Continuing..." : "⏹️ Stopping...",
          color: continued ? 0x2ecc71 : 0xe74c3c,
        }],
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

    await this.send({
      embeds: [{
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
      }],
    });
  }

  async shutdown(): Promise<void> {
    if (this.bot) {
      this.bot.destroy();
    }
  }
}
```

### Generate `src/dashboard/terminal-ui.ts`

Generate a terminal UI with a **stream-first design**. The default view is the live activity stream (not the agent table). The layout has three sections: header, stream body, and input bar.

**Layout:**
```
╔══════════════════════════════════════════════════════════╗
║  🏭 PROJECT TITLE                                       ║
║  orchestrator-workers | 4 agents | ⏱ 3m 21s | ~€1.23   ║
╠══════════════════════════════════════════════════════════╣
║ [14:23:01] START orchestrator (coordinator) — sonnet    ║
║ [14:23:02] START researcher (research) — haiku          ║
║ [14:23:05] THINK orchestrator: Analyzing the task...    ║
║ [14:23:06] TOOL  researcher -> Read                     ║
║ [14:23:08] MSG   orchestrator -> researcher: Please...  ║
║ [14:23:10] TASK  worker-1 <- task-1: Implement the...   ║
║ [14:23:12] QUEST researcher: Which auth strategy?       ║
║ [14:23:15] DONE  researcher -> result-1: Found 12...    ║
║ [14:23:18] THINK worker-1: Working on the implement...  ║
║                                                          ║
╠══════════════════════════════════════════════════════════╣
║ > @orchestrator: _                                       ║
╚══════════════════════════════════════════════════════════╝
 [↑↓] scroll  [M] msg  [T] logs  [R] recap  [D] detail  [S] stop
```

**Header section:**
- Project name displayed prominently (large text or bold ANSI)
- Status bar: pattern name, agent count, elapsed time, total estimated cost

**Stream body (default view):**
- Reads `workspace/logs/_stream.log` and renders as a live-updating chronological feed
- Auto-follow mode by default (shows latest entries at the bottom)
- Arrow up/down scrolls through history; scrolling up pauses auto-follow
- Scrolling back to the bottom (or pressing `End`) resumes auto-follow
- Event types are 5-char fixed-width labels for clean alignment:
  - `START` — agent started (yellow)
  - `END  ` — agent finished (green)
  - `ERROR` — agent error (red)
  - `THINK` — agent reasoning, truncated to fit terminal width (dim/gray)
  - `TOOL ` — agent tool call (dim/gray)
  - `HMSG ` — human message injected (bright cyan)
  - `MSG  ` — inter-agent message, from -> to (cyan, bold)
  - `TASK ` — task assignment (yellow)
  - `DONE ` — result submitted (green, bold)
  - `QUEST` — agent question awaiting human answer (orange, bold)
  - `WARN ` — low confidence flag or warning (yellow)
- Inter-agent messages (`MSG`, `TASK`, `DONE`) are visually prominent — they show the communication flow between agents
- `QUEST` events are highlighted in orange and bold — they indicate an agent is blocked and needs input

**Input bar (always visible at the bottom):**
- A persistent message input field: `> @{agent}: {message}_`
- Type `@` then Tab to cycle through available agent IDs (autocomplete)
- Type `@all` to broadcast to all active agents
- Press Enter to send the message (interrupts the target agent, injects human message)
- Press Escape to clear the input
- When the input bar is empty, the arrow keys control stream scrolling
- When typing, the input captures keystrokes (standard text editing: backspace, left/right arrows)
- **Question mode:** When an agent asks a question, the input bar changes to `? [agentId] question: _` — type the answer and press Enter

**Agent detail view (toggle with `D`):**
- Replaces the stream body with a single-agent detail view
- Shows streaming output from one agent
- Arrow keys switch between agents
- Agent selector at top: `< orchestrator | researcher | worker-1 >` with arrows to navigate

**Log tailing view (`T`):**
- Press `T` to open log view — shows agent picker first (inline selector)
- Select an agent to view its full conversation transcript from `workspace/logs/{agentId}.log`
- Press `T` again or Tab to cycle to the next agent's log
- Select `_stream.log` option to view the unified interleaved stream
- Arrow keys scroll, Escape returns to main stream view
- Each agent's log shows the full conversation: assistant turns, tool calls, tool results, human messages

**Recap view (`R`):**
- Shows a high-level summary of the run, filtering the activity stream to important events only
- Includes: `HMSG` (human messages), `QUEST` (questions), `DONE` (results), `ERROR` (errors), `WARN` (low confidence), `START`/`END` (agent lifecycle), `MSG` (inter-agent messages)
- Excludes: `THINK` and `TOOL` noise
- Displays milestones reached, questions asked/answered, key decisions, errors
- Press `R` again to return to the full stream view

**Inline selection (for any agent picker prompts):**
- When a selection is needed (e.g., picking an agent for log tailing), show an inline selector:
  - Arrow up/down to highlight an option
  - Type to filter/search (fuzzy match on agent ID and role)
  - Tab to autocomplete the first match
  - Enter to confirm selection
- This replaces the old readline-based prompt

**Methods:**
- `update()` — called by pattern runner after each status change
- `stop()` — graceful cleanup of intervals and raw mode
- `pauseRender()` / `resumeRender()` — pause/resume the render interval
- `toggleDetailView()` — switch between stream and detail views
- `toggleLogView(agentId?)` — open log tailing for a specific agent or show picker
- `toggleRecapView()` — switch between stream and recap view
- `showQuestion(question, abortSignal?)` — display agent question in input bar, returns a Promise<string|null> that resolves when answered or null if aborted (Discord answered first)
- `streamScrollUp()` / `streamScrollDown()` — scroll the stream feed
- `handleInput(key: Buffer, callbacks)` — route keystrokes to input bar, navigation, or control shortcuts (callbacks provide `onShutdown`, `onSendMessage`, `getActiveAgentIds`, `getAllAgentIds`)

**Footer (context-sensitive):**
- Stream view: `[↑↓] scroll  [M] msg  [T] logs  [R] recap  [D] detail  [P] pause  [S] stop`
- Detail view: `[←→] switch agent  [D] back  [P] pause  [S] stop`
- Log view: `[T/Tab] next agent  [↑↓] scroll  [Esc] back`
- Recap view: `[R] back to stream  [↑↓] scroll  [P] pause  [S] stop`

**Implementation notes:**
- Use raw ANSI codes and `process.stdout.write` — no external TUI library
- Updates in-place using `\x1b[2J\x1b[H` (clear screen) on a 500ms interval
- Uses box-drawing characters (╔═╗║╚╝) for borders
- Uses ANSI colors: `\x1b[1m` bold, `\x1b[2m` dim, `\x1b[31m` red, `\x1b[32m` green, `\x1b[33m` yellow, `\x1b[36m` cyan, `\x1b[33;1m` orange/bold (for QUEST), `\x1b[0m` reset
- Get terminal width/height from `process.stdout.columns` and `process.stdout.rows`
- Truncate lines to terminal width to prevent wrapping artifacts
- Emoji for status: ✅ done, 🔄 working, ⏳ waiting, ❌ error, ⏸ paused

**Exported function signature:**
```typescript
export function createDashboard(
  config: ProjectConfig,
  metrics: RunMetrics,
  workspacePath: string,  // needed to read workspace/logs/_stream.log and workspace/logs/{agentId}.log
): Dashboard;
```

**`handleInput` callback interface:**
```typescript
dashboard.handleInput(key: Buffer, callbacks: {
  onShutdown: () => void;
  onSendMessage: (target: string, message: string) => Promise<void>;
  getActiveAgentIds: () => string[];
  getAllAgentIds: () => string[];
});
```

The dashboard manages all input routing internally:
- When the input bar has focus (user is typing), keystrokes go to the input buffer
- When the input bar is empty, single-key shortcuts (`D`, `T`, `R`, `M`, `P`, `S`) trigger view/control actions
- Arrow keys go to stream scrolling when input bar is empty, or cursor movement when typing
- Tab triggers agent ID autocomplete (in message input) or cycles agents (in log view)
- Enter parses `@target: message` from the input buffer and calls `onSendMessage`
- `M` focuses the input bar for messaging (equivalent to clicking into it)
- `T` opens log tailing with agent picker, then Tab/T cycles between agents
- `R` toggles the recap view (filtered important events only)

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

## Dashboard

The dashboard shows a **live activity stream** by default — all agent events in chronological order with inter-agent communication highlighted. A message input bar is always visible at the bottom.

### Controls

| Key | Action |
|-----|--------|
| `↑` `↓` | Scroll stream feed up/down |
| `M` | Focus message input bar |
| `T` | Open log tailing (pick agent, Tab to cycle) |
| `R` | Toggle recap view (filtered important events) |
| `D` | Toggle detail view (single agent live output) |
| `P` | Pause / resume |
| `S` | Graceful stop (press twice to force quit) |
| `Tab` | Autocomplete agent ID / cycle log agent |
| `Enter` | Send message from input bar |
| `Esc` | Clear input / return to stream |
| `Ctrl+C` | Same as S (graceful stop, twice to force) |

### Messaging

Type directly in the input bar at the bottom: `@agent-id: your message` then Enter. Use `@all:` to broadcast. Tab autocompletes agent IDs. Messages go to the orchestrator by default when sent from Discord.

### Agent Questions

When an agent is stuck, it writes a question file. The question appears both in the terminal (input bar switches to question mode) and in Discord (embed with buttons). The first answer wins — race between Discord and terminal. The answer is injected back into the agent.

### Discord Integration

If configured with interactive mode, all run messages go to a dedicated Discord thread. You can:
- **Send messages** by typing in the thread — they route to the orchestrator
- **Answer agent questions** via buttons or text replies in the thread
- **Handle errors** with Retry/Skip/Stop buttons when an agent hits an error
- **Review low-confidence outputs** when an agent flags uncertainty

### Discord vs Terminal Feature Parity

| Feature | Discord | Terminal |
|---------|---------|---------|
| Send message to orchestrator | Type in thread | `[M]` input bar |
| Agent questions | Embed + buttons/reply | Inline prompt in input bar |
| Recap/overview | Periodic summary embed | `[R]` key |
| Full agent logs | Not needed | `[T]` with agent switching |
| Status updates | Embeds (filtered) | Activity stream (everything) |
| Checkpoint continue/stop | Buttons | Y/n prompt |
| Error escalation | Embed + Retry/Skip/Stop | Stream + prompt |
| Low confidence review | Embed + Accept/Review | Inline question |

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
├── agents/            — Agent types and SDK factory
├── patterns/          — Collaboration pattern implementations
├── safety/            — Limits, checkpoints, sandboxing
├── comms/             — Shared workspace utilities + unified stream
├── dashboard/         — Terminal UI (stream-first with input bar)
└── notifications/     — Discord integration (threads, questions, error escalation)
workspace/
├── tasks/             — Task assignments
├── results/           — Agent outputs
├── messages/          — Inter-agent messages
├── questions/         — Agent questions awaiting human answers
└── logs/
    ├── _stream.log    — Unified activity stream (all agents)
    └── {agent}.log    — Per-agent conversation transcripts
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
- `workspace/` — Agents read/write here. Check `workspace/results/` for outputs, `workspace/logs/` for transcripts, `workspace/logs/_stream.log` for the unified activity stream, `workspace/questions/` for agent questions.

## Dashboard & Controls

- The dashboard shows a **live activity stream** by default with all agent events chronologically
- Type `@agent-id: message` in the input bar at the bottom and press Enter to message agents
- Use Tab to autocomplete agent IDs, `@all:` to broadcast
- `↑↓` scroll, `M` message, `T` log tailing, `R` recap, `D` detail, `P` pause, `S` stop (2x = force)
- Agents can ask you questions — they appear in the input bar and in Discord (if connected)

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

### Generate `workspace/ask-human.sh`

A helper script that agents can call via Bash to ask the human a question. This is more reliable than having agents write JSON manually.

```bash
#!/bin/bash
# Usage: bash workspace/ask-human.sh --from "agent-id" --question "Your question" [--options "A,B,C"]

FROM=""
QUESTION=""
OPTIONS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --from) FROM="$2"; shift 2 ;;
    --question) QUESTION="$2"; shift 2 ;;
    --options) OPTIONS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [ -z "$FROM" ] || [ -z "$QUESTION" ]; then
  echo "Usage: bash workspace/ask-human.sh --from <agent-id> --question <question> [--options <A,B,C>]"
  exit 1
fi

TIMESTAMP=$(date +%s)$$
FILE="workspace/questions/${FROM}-${TIMESTAMP}.json"

if [ -n "$OPTIONS" ]; then
  # Convert comma-separated options to JSON array
  OPTIONS_JSON=$(echo "$OPTIONS" | sed 's/,/","/g' | sed 's/^/"/' | sed 's/$/"/')
  echo "{\"from\":\"${FROM}\",\"question\":\"${QUESTION}\",\"options\":[${OPTIONS_JSON}]}" > "$FILE"
else
  echo "{\"from\":\"${FROM}\",\"question\":\"${QUESTION}\"}" > "$FILE"
fi

echo "Question submitted: $FILE"
echo "Waiting for human answer..."
```

Make sure to set the executable bit: `chmod +x workspace/ask-human.sh`

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

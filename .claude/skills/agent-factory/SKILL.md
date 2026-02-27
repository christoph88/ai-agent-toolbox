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

Then proceed to **Step 3 — Generate Project**.

## Step 2 — Generate the project directory

Ask the user for a project name (suggest one based on the task, e.g. `perf-audit-team`). Create the directory in CWD.

```bash
mkdir -p {project-name}/src/{agents,patterns,safety,comms,dashboard}
mkdir -p {project-name}/workspace/{tasks,results,messages}
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

export interface ProjectConfig {
  name: string;
  description: string;
  pattern: PatternType;
  agents: AgentConfig[];
  stopConditions: StopConditions;
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

    await patternRunner(config, metrics, globalAbort, dashboard);
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
- Accept `(config, metrics, abortController, dashboard)` arguments
- Check `abortController.signal.aborted` before each iteration
- Call `checkLimits(metrics, config.stopConditions)` after each iteration
- Call `promptCheckpoint(metrics, config.stopConditions)` at checkpoint intervals
- Update `metrics.agentStatuses` and `metrics.totalEstimatedCostEur` in real-time
- Call `dashboard.update()` after each status change

$ARGUMENTS

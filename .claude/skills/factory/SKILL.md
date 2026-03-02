---
name: factory
description: Design and generate multi-agent collaboration systems — describe a task, get a ready-to-run TypeScript project with collaborating AI agents
---

This skill is invoked via `/factory`. When triggered, you receive the user's description of what they want their agent squad to do. Your job is to design the agent team, set up the project by cloning the framework repo, and generate only `src/config.ts` — the single file that defines the entire squad.

All framework code (dashboard, Discord, orchestrator, agent runner, patterns) ships in the `agents-factory` repo and stays updatable via git. The user's squad is just a config file on top of a shared framework.

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

| Agent Role Type | Recommended Model | Why |
|---|---|---|
| Orchestrator / Architect | opus | Complex reasoning, task decomposition |
| Reviewer / Judge / Analyst | opus | Critical evaluation, deeper thinking |
| Developer / Implementer | sonnet | Balanced capability and speed |
| Researcher | sonnet | Capable for search and synthesis |
| Validator / Simple checker | haiku | Fast, sufficient for pass/fail |
| Writer / Formatter | sonnet | Good output quality |

### Agent count guidance

- **2-3 agents**: Most tasks. One planner/orchestrator + 1-2 workers. Don't over-staff.
- **4-5 agents**: Complex tasks with distinct phases (research, code, review). Add a dedicated reviewer.
- **6+ agents**: Rarely needed. Only if the task has genuinely independent workstreams.

Default to fewer agents. A 3-agent squad that works well beats a 6-agent squad with coordination overhead.

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
6. **How many agents?** (prefer fewer — see agent count guidance above)

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
4. **Suggested stop conditions** — based on task complexity (see cost cap guidance below)

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
> **Stop conditions:** verifier confirms improvement ≥20%, or max 5 pipeline cycles, checkpoint every 3 iterations

- **Options:**
  - **Looks good, generate it** — "Create the project with this configuration"
  - **Adjust agents** — "I want to change roles, tools, or models"
  - **Change pattern** — "I'd prefer a different collaboration pattern"
  - **Change limits** — "I want different stop conditions"

If the user wants adjustments, loop back and re-propose until they approve. Then proceed to **Step 1C — Discord Notifications**.

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
   - **Strict** — read/write only to `workspace/`
   - **Moderate** — project-wide write access (recommended)
   - **Open** — minimal restrictions (only for trusted tasks)

Ask "Add another agent?" after each one. Minimum 2 agents.

### Gather stop conditions

Ask using `AskUserQuestion` with multiSelect:
- **Question:** "Which stop conditions do you want? (select all that apply)"
- **Options:**
  - **Max iterations** — "Stop after N orchestrator rounds or pipeline cycles"
  - **Estimated cost cap** — "Stop when estimated cost exceeds €X (informational — you're on subscription)"
  - **Time limit** — "Stop after N minutes/hours of wall-clock time"
  - **Checkpoint prompts** — "Pause and ask me every N iterations whether to continue"

For each selected condition, ask for the specific value.

### Confirm the full configuration

Present the complete setup using `AskUserQuestion` (same format as assisted mode proposal). Get user approval before generating.

Then proceed to **Step 1C — Discord Notifications**.

## Step 1C — Discord Notifications (Optional)

After the agent configuration is confirmed (end of Step 1A or 1B), ask:

- **Question:** "Want Discord notifications for your agent team?"
- **Options:**
  - **Interactive control** — "Full two-way Discord control: start/stop/pause, answer agent questions, approve checkpoints via buttons. Recommended for most squads."
  - **Status updates** — "Get pinged when agents start, finish, or hit errors — simple webhook, no bot needed. Good for monitoring."
  - **No thanks** — "I'll monitor everything in the terminal"

### Discord mode reference

- `"off"` — No Discord integration. Dashboard only.
- `"updates"` — Posts status updates to Discord via webhook (read-only). Good for monitoring.
- `"interactive"` — Full two-way Discord control: start/stop/pause, answer agent questions, approve checkpoints. Recommended for most squads.

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
  - **I'll add it later** — Generate config with discord mode set. They can add the webhook URL to `.env` before running.

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
  - **I'll add it later** — Generate config with discord mode set. They can add credentials to `.env` before running.

The user can also provide token + channel ID directly via the "Other" free-text option.

### Discord configuration storage

Store values in `.env` (never hardcode secrets):
- Webhook mode: `DISCORD_WEBHOOK_URL`
- Bot mode: `DISCORD_BOT_TOKEN` and `DISCORD_CHANNEL_ID`

Then proceed to **Step 2 — Set up the project**.

## Step 2 — Set up the project

The `agents-factory` repo contains all framework code. The user's squad is just `src/config.ts` on top of it.

### 2a. Get the repo

Ask the user:
- **Question:** "How do you want to set up the project?"
- **Options:**
  - **Fork and clone** — "Fork agents-factory on GitHub so I can push my config and pull framework updates (recommended)"
  - **I already have a fork** — "I'll give you the URL to clone"
  - **Just clone it** — "Clone the upstream repo directly (quick start, no push)"

If forking: guide the user to fork manually on GitHub, or use `gh repo fork` if they have the GitHub CLI. Then clone their fork.

If cloning directly:
```bash
git clone https://github.com/{owner}/agents-factory.git ~/Agents/{squad-name}
```

### 2b. Install dependencies

```bash
cd ~/Agents/{squad-name}
npm install
```

### 2c. Generate `src/config.ts`

Generate **only** this one file based on the approved agent configuration. See the Config Generation Reference below for type definitions, system prompt guidelines, and all reference material.

### 2d. Create `.env` (if Discord is configured)

If the user provided Discord credentials, create `.env`:
```
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/...
# or
DISCORD_BOT_TOKEN=your-bot-token
DISCORD_CHANNEL_ID=your-channel-id
```

If they chose "I'll add it later", remind them to copy `.env.example` to `.env` and fill in credentials before running.

### 2e. Commit

```bash
git add src/config.ts
git commit -m "Initialize {squad-name} config"
```

To pull framework updates later:
```bash
git fetch upstream
git merge upstream/main
```

Since only `src/config.ts` is customized, upstream merges won't conflict.

---

## Config Generation Reference

Everything below is reference material for generating `src/config.ts`. The skill must understand these types, tools, and conventions to produce a correct and effective config.

### Type definitions

The framework defines these types in `src/agents/types.ts`. Your generated config must conform to `ProjectConfig`:

```typescript
type AgentModel = "opus" | "sonnet" | "haiku";
type PatternType = "orchestrator-workers" | "pipeline" | "debate";
type DiscordMode = "off" | "updates" | "interactive";

interface AgentConfig {
  id: string;                    // Unique agent ID, used for task assignment and messaging
  role: string;                  // Display label (e.g. "Lead Researcher")
  systemPrompt: string;          // Full instructions — this is where the agent's behavior lives
  allowedTools: string[];        // Tools the agent can use
  disallowedTools?: string[];    // Explicitly blocked tools
  sandbox: SandboxSettings;      // Filesystem write permissions
  model: AgentModel;             // opus = deep reasoning, sonnet = fast execution, haiku = lightweight
  maxTurns?: number;             // Optional turn limit per invocation
}

interface StopConditions {
  maxIterations?: number;        // Max orchestrator loop iterations
  estimatedCostCapEur?: number;  // Cost safety cap
  timeLimitMinutes?: number;     // Wall clock limit
  checkpointEveryN?: number;     // Pause for human review every N iterations (1 = very hands-on, 5+ = autonomous)
}

interface ProjectConfig {
  name: string;                  // Squad identifier (kebab-case)
  description: string;           // What the squad does (shown on startup)
  task: string;                  // Set to "" — filled at runtime via prompt
  projectDir: string;            // Set to "" — filled at runtime via prompt
  pattern: PatternType;          // Collaboration pattern
  agents: AgentConfig[];         // The squad members
  stopConditions: StopConditions;
  discord: { mode: DiscordMode };
  workspacePath: string;         // Set to "./workspace" — resolved at runtime
}
```

### Available tools

Agents can be given any combination of:
- `Read`, `Write`, `Edit` — file operations
- `Bash` — shell commands (powerful but less safe)
- `Glob`, `Grep` — file/content search
- `WebSearch`, `WebFetch` — internet access

Restrict tools based on the agent's role. A reviewer shouldn't have `Write`. A planner might not need `Bash`.

### Sandbox settings

Control what each agent can write to:

```typescript
// Can write anywhere in the project (for agents that need broad access)
sandbox: { enabled: true, filesystem: { allowWrite: ["./**"] } }

// Can only write to workspace (read-only agent that just produces results)
sandbox: { enabled: true, filesystem: { allowWrite: ["./workspace/**"] } }

// Can write to workspace and a specific directory
sandbox: { enabled: true, filesystem: { allowWrite: ["./workspace/**", "./reports/**"] } }
```

### Cost cap guidance

| Squad complexity | Suggested cap | Typical time limit |
|---|---|---|
| 2-3 agents, simple task | 5-10 EUR | 60 min |
| 3-5 agents, moderate task | 15-30 EUR | 120-240 min |
| 5+ agents, complex task | 30-50 EUR | 240+ min |

Use these as defaults. Adjust based on expected task duration and agent count.

### System prompt guidelines

The system prompt is the most important part of each agent. It defines all behavior. Include:

1. **Identity** — who the agent is and what it's responsible for
2. **Workflow** — numbered steps for what to do each iteration
3. **File formats** — exact formats for reading/writing workspace files
4. **Rules** — constraints and safety boundaries
5. **Asking for help** — when/how to use `workspace/ask-human.sh` (see below)
6. **Confidence signals** — prefix workspace files with `[LOW CONFIDENCE]` when uncertain
7. **Human messages** — for orchestrator/lead agents: when receiving `[Human via Discord (username)]:` or `[Human answer]:` prefixed messages, treat as high-priority guidance. Acknowledge, explain how it changes approach, and adapt.

#### Asking for help (`workspace/ask-human.sh`)

The framework ships `workspace/ask-human.sh` — a helper script agents call when blocked. It writes a question JSON file to `workspace/questions/` which surfaces on the dashboard input bar and in Discord (if connected). The first answer wins (race between terminal and Discord). The answer is injected back into the agent as a `[Human answer]: ...` message.

Include this in every agent's system prompt:

> When you are stuck, uncertain, or need a decision, run: `bash workspace/ask-human.sh --from "{your-id}" --question "Your question here"`. Optionally add `--options "Option A,Option B"` for multiple-choice. Only ask when genuinely stuck — don't ask for things you can figure out yourself.

#### Pattern-specific system prompt content

**Orchestrator pattern** — the orchestrator's prompt must explain:
- Read the task description and any previous results from `workspace/results/`
- Write task assignments to `workspace/tasks/{worker-id}-task-{n}.json` using the task JSON format
- Declare done by writing `workspace/DONE.md` with a final summary
- Workers read from `workspace/tasks/` and write results to `workspace/results/`

**Pipeline pattern** — each stage agent's prompt must explain:
- Read input from `workspace/stage-{n-1}/` (or the task description if stage 1)
- Write output to `workspace/stage-{n}/`
- Last stage writes final output to `workspace/results/final.md`

**Debate pattern** — each debater's prompt must explain:
- Write proposal to `workspace/proposals/{agent-id}.md`
- Judge reads all proposals from `workspace/proposals/` and writes verdict to `workspace/results/verdict.md`

### Coordination via workspace/

Agents coordinate through the shared `workspace/` directory:
- `workspace/plan.md` — the orchestrator's plan
- `workspace/tasks/{agent-id}-task-{n}.json` — task assignments
- `workspace/results/{agent-id}-result-{n}.md` — completed work
- `workspace/results/review-{task-id}.md` — review verdicts
- `workspace/messages/` — human messages to agents
- `workspace/questions/` — agent questions awaiting human answers
- `workspace/.state/state.json` — run state for resumability

Task JSON format:
```json
{
  "id": "task-{n}",
  "assignee": "agent-id",
  "title": "Short title",
  "description": "What to do",
  "doneCriteria": ["criterion 1"],
  "parallel": true,
  "status": "pending",
  "dependencies": []
}
```

Task status flow: `pending` → `in-progress` → `review` → `done` or `rejected`

### Example config

```typescript
import type { ProjectConfig } from "./agents/types.js";

export const config: ProjectConfig = {
  name: "research-squad",
  description: "Research team: researcher gathers sources, analyst extracts insights, writer produces reports",
  task: "",        // Set by the framework at runtime — do not hardcode
  projectDir: "",  // Set by the framework at runtime — do not hardcode
  pattern: "orchestrator-workers",
  agents: [
    {
      id: "researcher",
      role: "Lead Researcher",
      systemPrompt: `You are the **Researcher** — you find and organize information.

## Your workflow
1. Read your task assignment from workspace/tasks/
2. Search for relevant information using WebSearch and WebFetch
3. Organize findings into structured notes
4. Write your results to workspace/results/

## Asking for help
When you are stuck, uncertain, or need a decision, run:
\`bash workspace/ask-human.sh --from "researcher" --question "Your question here"\`
Optionally add \`--options "Option A,Option B"\` for multiple-choice.
Only ask when genuinely stuck.

## Confidence
If you are uncertain about a finding, prefix the file with [LOW CONFIDENCE] on the first line.`,
      allowedTools: ["Read", "Write", "Edit", "Glob", "Grep", "WebSearch", "WebFetch"],
      disallowedTools: ["Bash"],
      sandbox: { enabled: true, filesystem: { allowWrite: ["./**"] } },
      model: "sonnet",
    },
    {
      id: "analyst",
      role: "Data Analyst",
      systemPrompt: `You are the **Analyst** — you process raw research into structured insights.

## Your workflow
1. Read your task assignment from workspace/tasks/
2. Read research results from workspace/results/
3. Extract key insights, patterns, and data points
4. Write structured analysis to workspace/results/

## Asking for help
When stuck, run: \`bash workspace/ask-human.sh --from "analyst" --question "Your question"\`

## Confidence
Prefix output with [LOW CONFIDENCE] when uncertain about conclusions.`,
      allowedTools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep"],
      sandbox: { enabled: true, filesystem: { allowWrite: ["./**"] } },
      model: "sonnet",
    },
    {
      id: "writer",
      role: "Report Writer",
      systemPrompt: `You are the **Writer** — you produce clear, well-structured reports.

## Your workflow
1. Read your task assignment from workspace/tasks/
2. Read analysis results from workspace/results/
3. Produce a polished, well-organized report
4. Write the report to workspace/results/

## Asking for help
When stuck, run: \`bash workspace/ask-human.sh --from "writer" --question "Your question"\`

## Confidence
Prefix output with [LOW CONFIDENCE] when uncertain about accuracy.`,
      allowedTools: ["Read", "Write", "Edit", "Glob", "Grep"],
      sandbox: { enabled: true, filesystem: { allowWrite: ["./**"] } },
      model: "sonnet",
    },
  ],
  stopConditions: {
    maxIterations: 10,
    estimatedCostCapEur: 15,
    timeLimitMinutes: 120,
    checkpointEveryN: 3, // Pause for human review every 3 iterations (1 = very hands-on, 5+ = autonomous)
  },
  discord: { mode: "interactive" },
  workspacePath: "./workspace",
};
```

## Step 3 — Install and run

After generating `src/config.ts`:

1. If not already done, run `npm install`.

2. Confirm success to the user. Show the agent configuration summary.

3. Ask the user:
   - **Question:** "Project is ready! What do you want to do?"
   - **Options:**
     - **Run it now** — "Start the agents immediately with `npx tsx src/run.ts`"
     - **I'll run it later** — "I'll review the config first and run manually"
     - **Open config** — "Let me tweak the agent configuration before running"

If the user chooses to run:
```bash
npx tsx src/run.ts
```

## Troubleshooting

- **Target directory already exists** — Ask user whether to use existing directory or pick a new name. Don't overwrite without confirmation.
- **`npm install` fails** — Show the error, don't proceed. Check that the user has Claude Code installed and authenticated (the SDK uses the same auth).
- **`src/config.ts` already has custom content** — Warn the user before overwriting. They may have manual customizations.
- **Fork already exists** — Clone the existing fork instead of re-forking.
- **Permission errors during agent run** — Suggest adjusting the `sandbox` or `allowedTools` in `config.ts`.
- **Agent stuck in loop** — The checkpoint system catches this. If no checkpoint is configured, the time limit or manual stop (Ctrl+C) will catch it.
- **Cost overrun** — The estimated cost cap triggers a graceful stop. Since it's subscription-based, this is informational but still a good proxy for resource consumption.

$ARGUMENTS

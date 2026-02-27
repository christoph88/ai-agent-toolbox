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

$ARGUMENTS

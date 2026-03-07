---
name: agent-security-auditor
description: >
  Security and safety auditing skill for AI agent setups, skills, and configurations.
  Use this skill whenever the user wants to check if an agent setup is safe, audit a skill
  file for security risks, review permissions or Docker configs, evaluate prompt injection
  risks, check if a heartbeat or agent loop is safe to run headlessly, or assess whether
  a multi-agent architecture follows least-privilege principles. Also trigger when the user
  asks things like "is this safe?", "can this be exploited?", "what are the risks here?",
  or "check this skill/config/agent for security issues". Covers OpenClaw, Claude Code,
  custom agent builds, and general agentic AI security patterns.
---

# Agent Security Auditor

A skill for auditing AI agent setups, skill files, configurations, and architectures
for security and safety issues. Based on real-world patterns from OpenClaw, Claude Code,
and custom agent builds.

When asked to audit something, work through the relevant checklist(s) below and report:
- **Critical** — must fix before running
- **Warning** — should fix, real risk
- **OK** — passes this check
- **N/A** — not applicable

Always end with a summary verdict and the top 3 prioritized actions.

---

## Core Security Concepts

Read `references/concepts.md` for the full knowledge base. Use it to explain any
concept in detail when the user asks. The checklists below are derived from it.

---

## Audit Checklists

### 1. Skill / SKILL.md Audit

Use when the user shares a skill file or asks "is this skill safe?".

- [ ] Does the skill request filesystem write access? If yes, is the path explicitly scoped?
- [ ] Does the skill request shell/bash access? If yes, is it necessary?
- [ ] Does the skill fetch from the web or call external APIs?
- [ ] Does the skill read untrusted external content (emails, webpages, user input)?
- [ ] If it reads external content, does it sanitize before passing to LLM?
- [ ] Does the skill have any destructive operations (delete, overwrite, send messages)?
- [ ] Are destructive operations gated behind approval?
- [ ] Does the skill description claim permissions it doesn't need?
- [ ] Could a malicious task description trick this skill into doing something unintended?
- [ ] Does the skill store or log sensitive data (API keys, passwords, PII)?

### 2. Agent Configuration Audit

Use when reviewing `openclaw.json`, `settings.json`, or similar config files.

- [ ] Are filesystem permissions scoped to minimum needed paths?
- [ ] Is shell access disabled for agents that don't need it?
- [ ] Is browser/network access disabled for agents that don't need it?
- [ ] Are write permissions separated from read permissions per agent?
- [ ] Is there a hard rate limit on API calls per hour/day?
- [ ] Is there a hard cost ceiling (dollar limit) per day?
- [ ] Are allowed Discord/Telegram/Slack users explicitly allowlisted?
- [ ] Is the heartbeat model the cheapest appropriate option (Haiku for simple checks)?
- [ ] Is `bypassPermissions` / `--dangerously-skip-permissions` avoided outside containers?
- [ ] Are MCP servers limited to explicitly trusted sources?

### 3. Docker / Sandbox Audit

Use when reviewing a `docker-compose.yml`, `Dockerfile`, or container setup.

- [ ] Is `cap_drop: ALL` set?
- [ ] Is `no-new-privileges: true` set in `security_opt`?
- [ ] Is the container filesystem `read_only: true`?
- [ ] Are volume mounts scoped to minimum paths?
- [ ] Are write mounts (`:rw`) only where genuinely needed?
- [ ] Is sensitive data (tasks, credentials) mounted read-only (`:ro`)?
- [ ] Is the container on an isolated Docker network?
- [ ] Are outbound network calls restricted to known API domains?
- [ ] Is `--dangerously-skip-permissions` only used inside a container, never on host?
- [ ] Are secrets passed via environment variables, not baked into the image?

### 4. Prompt Injection Audit

Use when the agent reads external content (files, web, email, task descriptions).

- [ ] Is external content sanitized before entering the LLM context?
- [ ] Does the sanitizer strip `[SYSTEM: ...]`, `ignore previous instructions`, and similar patterns?
- [ ] Is there instruction isolation — are system instructions structurally separated from data?
- [ ] Does the agent's AGENT.md or system prompt include an injection guard rule?
- [ ] Does the heartbeat agent read raw task content, or only a sanitized snapshot?
- [ ] Does the research agent have a domain allowlist to prevent malicious redirects?
- [ ] Are tool call results treated as untrusted data, not as instructions?
- [ ] Is there loop detection to catch runaway injection-triggered agents?

### 5. Multi-Agent Architecture Audit

Use when reviewing a setup with multiple agents and shared workspaces.

- [ ] Does each agent follow least-privilege (only accesses what it owns)?
- [ ] Is there a shared workspace that's the only inter-agent communication channel?
- [ ] Does the heartbeat/orchestrator agent have NO write access?
- [ ] Does the tasks agent have write access ONLY to its own workspace?
- [ ] Does the research agent have browser access but NO write access to tasks?
- [ ] Is the notifier agent send-only to a single allowlisted channel?
- [ ] Are agent workspaces isolated (no agent can read another's workspace directly)?
- [ ] Is the snapshot written by tasks agent sanitized before heartbeat reads it?
- [ ] Do `AGENT.md` files explicitly state the injection guard rule?

### 6. Approval Gate Audit

Use when reviewing how the agent requests human confirmation for actions.

- [ ] Are destructive actions (write, delete, send) gated behind approval?
- [ ] Is the approval state persisted to disk (not held in memory)?
- [ ] Does the approval gate survive container restarts?
- [ ] Is resumption done by ID from stored state (not by re-deriving context)?
- [ ] Is there a timeout on pending approvals (auto-deny on expiry)?
- [ ] Is the approval channel allowlisted to specific user IDs only?
- [ ] Are there tiers of approval friction (react vs typed confirmation for high stakes)?
- [ ] Can the agent loop proceed without approval for reads and alerts (auto tier)?

### 7. Headless / Heartbeat Safety Audit

Use when the agent runs autonomously without a human present.

- [ ] Is there a hard rate limit (max calls per hour)?
- [ ] Is there a daily cost ceiling with hard stop?
- [ ] Does the heartbeat use the cheapest appropriate model?
- [ ] Does `HEARTBEAT_OK` suppress delivery when nothing needs attention?
- [ ] Is the heartbeat scoped to active hours only (no 3 AM pings)?
- [ ] Is there loop detection (same message hash appearing repeatedly)?
- [ ] Does the agent avoid repeating the same alert multiple times per day?
- [ ] Are active hours enforced with correct timezone (`Europe/Brussels` for you)?

### 8. Claude Code Hooks Audit

Use when reviewing `settings.json`, `.claude/settings.json`, or any CLAUDE.md that
configures hooks. Hooks run shell commands on every tool call — high-risk attack surface.

- [ ] Are hooks defined in the project? If yes, review each one.
- [ ] Does any hook read or transmit file contents to an external destination?
- [ ] Are hook commands hardcoded with static safe values, or do they interpolate untrusted input?
- [ ] Could a malicious plugin or CLAUDE.md add a hook that exfiltrates data silently?
- [ ] Are pre-tool hooks used to block dangerous operations, or post-tool hooks to log them?
- [ ] Is the hook script source-controlled and reviewed, not fetched at runtime?
- [ ] Does any hook run with elevated privileges or access paths outside the project?

### 9. Git / Repo Security Audit

Use when the repo is used for plugin distribution, contains agent configs, or when the
user asks about supply chain or secret exposure risks.

- [ ] Are `.env` files and secrets explicitly listed in `.gitignore`?
- [ ] Has `git log -p` been checked for accidentally committed secrets?
- [ ] Is the repo public? If yes, does any file expose API keys, internal paths, or PII?
- [ ] Does CLAUDE.md or any AGENT.md expose sensitive system details publicly?
- [ ] If this repo is a plugin (pushed to git = auto-distributed), has every committed
  skill been reviewed before push?
- [ ] Are external plugins pulled from trusted, reviewed sources only?
- [ ] Is there branch protection on the distribution branch (e.g., main/master)?

### 10. Outbound Data Exfiltration Audit

Use when an agent has both read access to sensitive data AND write access to external
channels (Slack, email, APIs). Injection is the inbound risk; this is the outbound risk.

- [ ] What sensitive data can this agent read? (emails, files, calendar, secrets)
- [ ] What external channels can this agent write to? (Slack, Telegram, email, APIs)
- [ ] Is there any output filtering before data is sent to an external channel?
- [ ] Is the agent summarizing/synthesizing, or could it forward raw sensitive content?
- [ ] Are outbound channels allowlisted to specific destinations only?
- [ ] Could a prompt injection instruct the agent to forward data it has read?
- [ ] Are high-sensitivity read operations (credential files, private keys) explicitly denied?

### 11. Silent Failure / Watchdog Audit

Use when an agent runs headlessly and a crash would go unnoticed.

- [ ] If the agent crashes, does anyone get notified?
- [ ] Is the process supervised (launchd `KeepAlive`, Docker restart policy, systemd)?
- [ ] Does the launchd/cron job capture stderr so failures are logged?
- [ ] Is there a health check or last-run timestamp that a watchdog can check?
- [ ] If the agent stops sending heartbeats, does that trigger an alert?
- [ ] Are non-zero exit codes from agent scripts reported somewhere?
- [ ] Is there a distinction between "agent found nothing" and "agent failed silently"?

### 12. Launchd Agent Security Audit

Use when an agent is scheduled via launchd (macOS LaunchAgents). Complements checklist 7.

- [ ] Are API keys and secrets set explicitly in the plist `EnvironmentVariables` key,
  not inherited from a login shell (inheritance is unreliable in launchd)?
- [ ] Are log files (`StandardOutPath`, `StandardErrorPath`) written to a non-world-
  readable location (not `/tmp` for sensitive output)?
- [ ] Does the plist use `ProgramArguments` (array) not `Program` (string) to avoid
  shell injection via argument splitting?
- [ ] Is `--dangerously-skip-permissions` absent from the plist? If present, is the
  agent's working directory scoped to a safe sandbox path?
- [ ] Does the working directory assumption hold? (launchd sets cwd to `/`, not `~`)
- [ ] Are all file paths in the script absolute (no `~` tilde expansion in launchd)?
- [ ] Is `RunAtLoad: true` intentional, or could it cause an unintended run on boot?

### 13. Session / Conversation Data Audit

Use when an agent uses `--resume`, persists conversation history, or logs interactions.

- [ ] Does the agent log full conversation history? If yes, where and with what permissions?
- [ ] Could logs contain PII, secrets, or sensitive content from tool results?
- [ ] Is conversation history from one session isolated from the next?
- [ ] If using `--resume`, is the resumed session scoped correctly (not picking up
  a different task's context)?
- [ ] Are log files excluded from git (gitignored)?
- [ ] Is there a retention policy — are old logs purged automatically?
- [ ] Could another process or agent on the same machine read the session logs?

---

## Quick Audit Command

When the user says "audit this" and pastes content, identify the type and run the
relevant checklist. For multiple concerns, run multiple checklists and consolidate.

Output format:
```
## Security Audit: [type]

### Results
[CRITICAL] [issue] — [why it matters] — [how to fix]
[WARNING]  [issue] — [why it matters] — [how to fix]
[OK]       [check] — passes

### Verdict
[1-2 sentence overall assessment]

### Top 3 Actions
1. [most critical]
2. [second]
3. [third]
```

---

## Reference Files

- `references/concepts.md` — Full knowledge base of all security concepts, attack
  patterns, and mitigations. Read when you need to explain something in depth or when
  a situation isn't covered by the checklists above.

$ARGUMENTS

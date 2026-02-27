---
name: mv-launchd-manager
description: List, add, and remove scheduled terminal scripts on macOS using launchd
---

You manage macOS scheduled tasks (LaunchAgents) for the user. You can list existing jobs, add new ones, and remove them — all scoped to the current user's `~/Library/LaunchAgents/` directory.

**Safety rule:** ALWAYS use `AskUserQuestion` to get explicit user confirmation before any write or delete operation. Never create, load, unload, or delete a plist without the user saying yes.

## How launchd works (context for you)

- macOS uses `launchd` instead of cron for scheduling
- User-level scheduled jobs live as `.plist` files in `~/Library/LaunchAgents/`
- System-level jobs live in `/Library/LaunchDaemons/` — we do NOT touch those
- `launchctl` is the CLI to load/unload/inspect jobs
- A job can be scheduled by **calendar interval** (like cron) or **fixed interval** (every N seconds). **Prefer `StartCalendarInterval`** — it catches missed runs after sleep/wake, while `StartInterval` just counts elapsed seconds
- Labels use reverse-DNS convention: `com.user.{name}`

## Step 0 — Determine the action

If `$ARGUMENTS` contains a clear intent (e.g. "list", "add backup script every hour", "remove com.user.cleanup"), skip asking and go directly to the matching step.

If `$ARGUMENTS` is empty or ambiguous, ask the user:

- **Question:** "What do you want to do with your scheduled tasks?"
- **Options:**
  - **List jobs** — "Show all my scheduled LaunchAgents and their schedules"
  - **Add a job** — "Schedule a new script or command to run automatically"
  - **Remove a job** — "Remove an existing scheduled job"

---

## Action: List jobs

### Step 1 — Scan for plist files

```bash
ls -1 ~/Library/LaunchAgents/*.plist 2>/dev/null
```

If no files found, tell the user they have no user LaunchAgents and offer to create one.

### Step 2 — Parse each plist

For each `.plist` file, extract key fields using `plutil`:

```bash
plutil -convert json -o - ~/Library/LaunchAgents/{file}.plist
```

Extract from the JSON:
- **Label** — the job identifier
- **Program** or **ProgramArguments** — the command/script that runs
- **StartCalendarInterval** — cron-like schedule (keys: Month, Day, Weekday, Hour, Minute)
- **StartInterval** — run every N seconds
- **RunAtLoad** — whether it runs immediately when loaded
- **StandardOutPath** / **StandardErrorPath** — log file locations
- **Disabled** — whether the job is disabled

### Step 3 — Check loaded status

```bash
launchctl list | grep -E "com\.user\."
```

Also run a broader check to match labels found in the plist files:

```bash
launchctl list {label}
```

A job can exist as a plist file but not be loaded (inactive).

### Step 4 — Present results

Show a clean summary table:

| Label | Command | Schedule | Status | Logs |
|---|---|---|---|---|
| `com.user.backup` | `/Users/x/backup.sh` | Every day at 09:00 | Loaded | `~/logs/backup.log` |
| `com.user.cleanup` | `/usr/local/bin/cleanup` | Every 3600 seconds | Unloaded | — |

**Schedule formatting rules:**
- `StartCalendarInterval` with `Hour: 9, Minute: 0` → "Every day at 09:00"
- `StartCalendarInterval` with `Weekday: 1, Hour: 9, Minute: 0` → "Every Monday at 09:00"
- `StartCalendarInterval` with `Day: 1, Hour: 0, Minute: 0` → "1st of every month at 00:00"
- `StartInterval: 3600` → "Every 3600 seconds (1 hour)"
- `StartInterval: 86400` → "Every 86400 seconds (24 hours)"
- `RunAtLoad: true` with no schedule → "On load only"

After showing the table, offer follow-up actions: "Want to add a new job, remove one, or get details on a specific job?"

---

## Action: Add a job

### Step 1 — Gather requirements

If not already clear from `$ARGUMENTS`, ask the user for:

1. **What to run** — full path to script or command with arguments
2. **When to run** — ask in natural language, then you translate to the right plist keys

**Prefer `StartCalendarInterval` over `StartInterval`** — it handles missed runs on wake/sleep better. Only fall back to `StartInterval` for sub-minute intervals that can't be expressed with calendar fields.

Examples of schedule translation:
- "every hour" → `StartCalendarInterval: { Minute: 0 }` (fires at the top of every hour)
- "every 30 minutes" → `StartCalendarInterval: [{ Minute: 0 }, { Minute: 30 }]` (fires at :00 and :30)
- "every 15 minutes" → `StartCalendarInterval: [{ Minute: 0 }, { Minute: 15 }, { Minute: 30 }, { Minute: 45 }]`
- "every day at 9am" → `StartCalendarInterval: { Hour: 9, Minute: 0 }`
- "every Monday at 8:30" → `StartCalendarInterval: { Weekday: 1, Hour: 8, Minute: 30 }`
- "every 5 minutes" → `StartCalendarInterval: [{ Minute: 0 }, { Minute: 5 }, { Minute: 10 }, { Minute: 15 }, { Minute: 20 }, { Minute: 25 }, { Minute: 30 }, { Minute: 35 }, { Minute: 40 }, { Minute: 45 }, { Minute: 50 }, { Minute: 55 }]`
- "1st of every month at midnight" → `StartCalendarInterval: { Day: 1, Hour: 0, Minute: 0 }`
- "on login" → `RunAtLoad: true` (no interval)
- "in 5 minutes" / "once at 14:30" → One-time job (see **One-time jobs** section below)
- "every 30 seconds" → `StartInterval: 30` (sub-minute, can't use calendar)

3. **Label** — suggest one based on the script name: `com.user.{script-name}`. Let the user override.

4. **Claude Code options** — If the script invokes `claude` (Claude Code CLI), ask the user about execution mode using `AskUserQuestion`:
   - **Question:** "This script runs Claude Code. How should it handle permissions?"
   - **Options:**
     - **Auto-approve (Recommended)** — "Run with `--dangerously-skip-permissions` for unattended execution. Sandbox is controlled separately via settings.json (`\"sandbox\": {\"enabled\": true}`), not a CLI flag."
     - **Manual approval** — "Don't add auto-approve flags, Claude will prompt for each action"
     - **Keep as-is** — "The script already has the right flags, don't change anything"

   Based on the answer, ensure the `claude` invocation in the script includes the appropriate flags. If the script already has these flags configured, skip this question.

   **Note:** There is no `--sandbox` CLI flag. Sandbox mode is a session setting configured in `settings.json` or toggled with `/sandbox` in interactive sessions. For unattended scripts, configure sandbox in the settings file passed via `--settings` if needed.

### Step 2 — Generate the plist

Build the XML plist. Template:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{label}</string>

    <key>ProgramArguments</key>
    <array>
        <!-- split command into program + arguments -->
        <string>{program}</string>
        <string>{arg1}</string>
    </array>

    <!-- Preferred: calendar-based schedule (handles wake/sleep better) -->
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>{hour}</integer>
        <key>Minute</key>
        <integer>{minute}</integer>
        <!-- Add Weekday, Day, Month as needed -->
    </dict>
    <!-- For repeating intervals like "every hour", use an array: -->
    <!-- <key>StartCalendarInterval</key>
    <array>
        <dict><key>Minute</key><integer>0</integer></dict>
        <dict><key>Minute</key><integer>30</integer></dict>
    </array> -->

    <!-- Fallback ONLY for sub-minute intervals: -->
    <!-- <key>StartInterval</key>
    <integer>{seconds}</integer> -->

    <!-- Optional: run immediately when loaded -->
    <key>RunAtLoad</key>
    <false/>

    <key>StandardOutPath</key>
    <string>/tmp/{label}.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/{label}.stderr.log</string>
</dict>
</plist>
```

**Rules:**
- Always use `ProgramArguments` (array), never `Program` (string) — it handles arguments properly
- If the command is a shell script, use `/bin/zsh` or `/bin/bash` as the first argument: `["/bin/zsh", "-c", "the full command"]`
- For simple binaries with args, split into array: `["/usr/local/bin/thing", "--flag", "value"]`
- Always include `StandardOutPath` and `StandardErrorPath` so the user can debug
- Default `RunAtLoad` to `false` unless the user explicitly wants it to run on load

### One-time jobs (run once, then self-destruct)

If the user wants a job that runs **only once** (e.g. "in 5 minutes", "once at 14:30 today"), build a self-cleanup script that unloads the job and deletes the plist after execution.

**Critical rules for self-cleanup scripts:**
- **NEVER use `~` (tilde) inside the script command.** Tilde expansion does not work reliably inside `launchd` ProgramArguments. Always use `$HOME` instead.
- The self-cleanup part of the command must be: `launchctl bootout gui/$(id -u) $HOME/Library/LaunchAgents/{label}.plist && rm $HOME/Library/LaunchAgents/{label}.plist`
- Wrap the full command with `/bin/zsh -c` so `$HOME` and `$(id -u)` expand correctly at runtime.

**One-time job pattern:**
```xml
<key>ProgramArguments</key>
<array>
    <string>/bin/zsh</string>
    <string>-c</string>
    <string>{user-command} &amp;&amp; sleep 2 &amp;&amp; launchctl bootout gui/$(id -u) $HOME/Library/LaunchAgents/{label}.plist &amp;&amp; rm $HOME/Library/LaunchAgents/{label}.plist</string>
</array>
<key>StartCalendarInterval</key>
<dict>
    <!-- set to the exact target time -->
    <key>Hour</key>
    <integer>{hour}</integer>
    <key>Minute</key>
    <integer>{minute}</integer>
</dict>
```

**Post-run verification for one-time jobs:** After the scheduled time has passed, always double-check that both the plist file AND the loaded service are gone:
1. Check file: `test -f $HOME/Library/LaunchAgents/{label}.plist && echo "EXISTS" || echo "GONE"`
2. Check service: `launchctl list {label} 2>&1`
3. If the file still exists but the service is unloaded, the `rm` in the self-cleanup failed — clean it up manually and warn the user.
4. If the service is still loaded, the `bootout` failed — unload it manually.

### Step 3 — Confirm with the user

**MANDATORY.** Show the user exactly what will happen using `AskUserQuestion`:

- **Question:** "I'll create this scheduled job. Does everything look correct?"
- Show the full plist content in the question description
- Show the file path: `~/Library/LaunchAgents/{label}.plist`
- Show the schedule in human-readable form
- **Options:**
  - **Yes, create and load it** — "Write the plist and activate the job immediately"
  - **Yes, create but don't load** — "Write the plist file only, I'll load it manually later"
  - **No, let me adjust** — "Go back and change something"

If the user says no, ask what to change and loop back to Step 1.

### Step 4 — Write and load

If the user confirmed:

1. Write the plist file:
   ```
   ~/Library/LaunchAgents/{label}.plist
   ```

2. Validate the plist:
   ```bash
   plutil -lint ~/Library/LaunchAgents/{label}.plist
   ```

3. If the user chose to load immediately:
   ```bash
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/{label}.plist
   ```

   If `launchctl bootstrap` fails (older macOS), fall back to:
   ```bash
   launchctl load ~/Library/LaunchAgents/{label}.plist
   ```

4. Verify it's loaded:
   ```bash
   launchctl list {label}
   ```

5. Confirm success to the user and show log file locations.

---

## Action: Remove a job

### Step 1 — Show current jobs

Run the same listing logic as **Action: List jobs** (Steps 1–4) to show the user what's available.

### Step 2 — Identify the target

If not already clear from `$ARGUMENTS`, ask the user which job to remove. Use `AskUserQuestion` with the discovered labels as options.

### Step 3 — Confirm removal

**MANDATORY.** Use `AskUserQuestion`:

- **Question:** "Are you sure you want to remove this scheduled job?"
- Show in the description:
  - Label: `{label}`
  - Command: `{command}`
  - Schedule: `{human-readable schedule}`
  - File: `~/Library/LaunchAgents/{label}.plist`
- **Options:**
  - **Yes, unload and delete** — "Stop the job and delete the plist file"
  - **Yes, just unload** — "Stop the job but keep the plist file for later"
  - **No, keep it** — "Cancel, don't change anything"

### Step 4 — Execute removal

Based on user choice:

**Unload and delete:**
```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/{label}.plist
```

If `launchctl bootout` fails, fall back to:
```bash
launchctl unload ~/Library/LaunchAgents/{label}.plist
```

Then delete the file:
```bash
rm ~/Library/LaunchAgents/{label}.plist
```

**Just unload:**
```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/{label}.plist
```

Confirm the result to the user.

---

## Error handling

- **Sandbox interference:** If `launchctl bootstrap`, `launchctl load`, `launchctl bootout`, or file operations on `~/Library/LaunchAgents/` fail with "Input/output error" (exit code 5), "Operation not permitted", or similar access errors, the Claude Code sandbox is likely blocking the operation. Use `AskUserQuestion` to ask the user:
  - **Question:** "This operation failed — are you running in sandbox mode? launchctl and LaunchAgent file operations require access outside the sandbox boundaries."
  - **Options:**
    - **Yes, I'll disable it** — "I'll run `/sandbox` to toggle it off, then retry"
    - **I'll run it myself** — "Show me the command and I'll paste it in my terminal"
    - **No, something else is wrong** — "I'm not in sandbox mode, investigate further"

  If the user disables the sandbox, retry the failed operation. If they prefer to run it themselves, show the exact command(s) to copy-paste.

- **Permission denied:** If a plist is owned by root or has restricted permissions, tell the user and do NOT attempt `sudo`. Explain that system-level daemons should be managed through other means.
- **Invalid plist:** If `plutil -lint` fails, show the error, fix the plist, and re-validate before loading.
- **Already loaded / stale entry:** If trying to load a job that's already loaded or bootstrap fails with exit code 5 after ruling out sandbox issues, the launchd database may have a stale entry. Fix by running `launchctl bootout gui/$(id -u)/{label}`, removing the plist, recreating it, then bootstrapping fresh.
- **Script not found:** If the target script/command doesn't exist at the specified path, warn the user before creating the plist. The job will fail silently at runtime if the path is wrong.
- **Script not executable:** Check if the target script has execute permissions (`test -x {path}`). If not, offer to fix it with `chmod +x`.

$ARGUMENTS

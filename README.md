# Apex Neural — Agent Ecosystem

A deterministic, multi-phase coding agent workflow built on VS Code's Copilot agent infrastructure. Prevents context loss, hallucination, and scope drift by enforcing structured phases with memory handoffs, hooks for enforcement, and context-isolated subagents.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER REQUEST                             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     🎯 ORCHESTRATOR                              │
│  Coordinates all phases. Never writes code directly.            │
│  Tools: agent, memory, read, search, codebase                   │
│  Hooks: SessionStart, SubagentStart/Stop, Stop                  │
└──┬──────────┬───────────┬───────────┬──────────┬────────────────┘
   │          │           │           │          │
 Phase 1   Phase 2    Phase 3    Phase 4    On Demand
   │          │           │           │          │
   ▼          ▼           ▼           ▼          ▼
┌────────┐┌────────┐┌─────────┐┌────────┐┌─────────────┐
│PLANNER ││ARCHITEC││SOLUTION ││ TESTER ││ MAINTENANCE │
│        ││T       ││ER       ││        ││             │
│Readonly││Readonly││Full edit││Edit+Run││ Run+Report  │
│Analyze ││Validate││Implement││ Verify ││ Prune/Index │
│Plan    ││Design  ││Build    ││ Test   ││ Health/Skill│
└───┬────┘└───┬────┘└────┬────┘└───┬────┘└──────┬──────┘
    │         │          │         │             │
    ▼         ▼          ▼         ▼             ▼
  ┌──────────────────────────────────────────────────┐
  │          SESSION MEMORY (handoff state)           │
  │  current-plan.md → architecture-decision.md →     │
  │  implementation-log.md → test-results.md          │
  │              schedule-state.json                   │
  └──────────────────────────────────────────────────┘
```

## How It Works

### Phase 1: Planning (Planner subagent)
- **Tools**: read-only (`read`, `search`, `codebase`, `problems`)
- **Input**: User's task description
- **Output**: Structured plan with tasks, affected files, risks, acceptance criteria
- **Memory**: Saves plan to `.github/memory/planner/current-plan-<timestamp>.md`

### Phase 2: Architecture (Architect subagent)
- **Tools**: read-only (`read`, `search`, `codebase`, `usages`)
- **Input**: Plan from Phase 1
- **Output**: Architecture review with verdict (APPROVED / NEEDS_REVISION / BLOCKED)
- **Memory**: Saves decision to `.github/memory/architect/architecture-decision-<timestamp>.md`
- **Loop**: If NEEDS_REVISION → back to Planner (max 3 iterations)

### Phase 3: Solutioning (Solutioner subagent)
- **Tools**: full edit (`edit`, `create_file`, `replace_string_in_file`, `run_in_terminal`)
- **Input**: Approved plan + architecture decisions
- **Output**: Implemented code changes + implementation report
- **Memory**: Saves log to `.github/memory/solutioner/implementation-log-<timestamp>.md`
- **Hook**: Post-edit linting runs automatically after every file change

### Phase 4: Testing (Tester subagent)
- **Tools**: edit + run (`edit`, `create_file`, `run_in_terminal`, `problems`)
- **Input**: Implementation log + changed files
- **Output**: Test report with pass/fail, coverage, verdict
- **Memory**: Saves results to `.github/memory/tester/test-results-<timestamp>.md`
- **Loop**: If FAIL → back to Solutioner (max 5 iterations per test)

## Determinism Mechanisms

| Mechanism | Purpose | How |
|-----------|---------|-----|
| **Subagent context isolation** | Prevents context overflow | Each subagent gets only the previous phase's output |
| **Session memory handoffs** | Structured state between phases | Plans, decisions, logs saved as markdown artifacts |
| **Agent-scoped hooks** | Enforce phase gates | Stop hooks verify required outputs before allowing phase completion |
| **Tool restrictions** | Prevent unintended actions | Planner/Architect are read-only; Solutioner can edit; Tester can edit+run |
| **Pre-tool safety guard** | Block dangerous operations | Hook blocks destructive terminal commands and hook self-modification |
| **Post-edit linting** | Catch errors early | Lint/format hooks run after every file edit |
| **Reactive maintenance** | Keep indexes fresh | Memory index auto-rebuilds after memory file writes |
| **Time-gated scheduling** | Prevent redundant work | Maintenance tasks only run when overdue based on configurable intervals |
| **Subagent tracking** | Audit trail | All subagent start/stop events logged with timestamps |
| **Iteration limits** | Prevent infinite loops | Max 3 plan-architect iterations, max 5 solution-test iterations |
| **Phase-specific prompts** | Role enforcement | SubagentStart hook injects phase-specific role reminders |
| **Cross-platform hooks** | Platform independence | All hooks work on Windows, Linux, and macOS via `run-hook.js` dispatcher |

## Cross-Platform Hooks

All hook scripts are cross-platform by design. Each hook has both a PowerShell (`.ps1`) and bash (`.sh`) implementation, with a Node.js dispatcher that automatically selects the right one for the current OS.

### How It Works

```
                   ┌─────────────────────┐
                   │  run-hook.js <name>  │
                   └──────────┬──────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
         Windows          Linux           macOS
              │               │               │
              ▼               ▼               ▼
      <name>.ps1        <name>.sh        <name>.sh
      (PowerShell)     (bash/sh)        (bash/sh)
```

- **Windows**: Runs `<name>.ps1` via `pwsh` (PowerShell Core) or `powershell` (Windows PowerShell)
- **Linux/macOS**: Runs `<name>.sh` via `sh`
- **Stdin**: JSON input is forwarded from the caller to the script unchanged
- **Stdout**: Script JSON output is forwarded back to the caller

### Hook Scripts

| Hook | Event | Purpose |
|------|-------|---------|
| `pre-tool-guard` | PreToolUse | Blocks destructive terminal commands and hook self-modification |
| `post-edit-lint` | PostToolUse | Runs linter/formatter after file edits; validates JSON |
| `session-init` | SessionStart | Injects project context, git branch, and memory hints |
| `subagent-tracker` | SubagentStart/Stop | Logs subagent lifecycle events and injects phase context |
| `phase-gate` | Stop | Validates required phase outputs before allowing completion |

## File Structure

```
.github/
├── agents/
│   ├── orchestrator.agent.md    # Main coordinator
│   ├── planner.agent.md         # Planning agent (user-invocable)
│   ├── architect.agent.md       # Architecture agent (user-invocable)
│   ├── solutioner.agent.md      # Implementation agent (user-invocable)
│   ├── tester.agent.md          # Testing agent (user-invocable)
│   └── maintenance.agent.md     # Maintenance agent (user-invocable)
├── hooks/
│   └── safety-and-tracking.json # Workspace-level hooks
├── memory/
│   ├── README.md                # Memory system conventions & templates
│   ├── schedule-state.json      # Last-run timestamps for scheduled tasks
│   ├── base/
│   │   └── project-context.md   # Core project context (loaded on session start)
│   ├── orchestrator/            # Orchestrator conversation memories
│   ├── planner/                 # Planner conversation memories
│   ├── architect/               # Architect conversation memories
│   ├── solutioner/              # Solutioner conversation memories
│   └── tester/                  # Tester conversation memories
├── schedule.json                # Task schedule definitions and intervals
├── scripts/
│   └── hooks/
│       ├── run-hook.js            # Cross-platform hook runner (detects OS)
│       ├── session-init.ps1       # Injects project context (Windows)
│       ├── session-init.sh        # Injects project context (Linux/Mac)
│       ├── post-edit-lint.ps1     # Runs linter + reactive maintenance (Windows)
│       ├── post-edit-lint.sh      # Runs linter + reactive maintenance (Linux/Mac)
│       ├── pre-tool-guard.ps1     # Blocks dangerous operations (Windows)
│       ├── pre-tool-guard.sh      # Blocks dangerous operations (Linux/Mac)
│       ├── subagent-tracker.ps1   # Logs subagent lifecycle events (Windows)
│       ├── subagent-tracker.sh    # Logs subagent lifecycle events (Linux/Mac)
│       ├── phase-gate.ps1         # Validates phase outputs (Windows)
│       └── phase-gate.sh          # Validates phase outputs (Linux/Mac)
├── skills/
│   ├── codebase-analysis/
│   │   └── SKILL.md             # Codebase analysis patterns
│   ├── implementation-patterns/
│   │   └── SKILL.md             # Implementation best practices
│   └── test-strategy/
│       └── SKILL.md             # Testing strategy & patterns
├── copilot-instructions.md      # Global project instructions
└── tool-sets.json               # Grouped tool collections
```

## Usage

### Starting the Orchestrator
1. Open VS Code Chat
2. Select **Orchestrator** from the agents dropdown
3. Describe your task

Example:
```
Add a REST endpoint for user profile updates with input validation and error handling
```

The Orchestrator will automatically:
1. Invoke the Planner to create a structured plan
2. Invoke the Architect to validate the plan
3. Invoke the Solutioner to implement the changes
4. Invoke the Tester to verify everything works

### Using Individual Agents
All agents are user-invocable — you can select them directly from the VS Code Chat agent dropdown or use the Orchestrator's handoff buttons:
- **Quick Plan**: Jump directly to the Planner
- **Direct to Architect**: Skip planning if you already have a design question
- **Direct to Testing**: Jump to testing for existing code
- **Run Maintenance**: Check for overdue tasks and run them

For full workflow enforcement (phase gates, hooks, iteration limits), always prefer the **Orchestrator**.

### VS Code Settings

Enable these settings for best experience:

```json
{
  "github.copilot.chat.tools.memory.enabled": true,
  "chat.useCustomAgentHooks": true,
  "chat.agent.thinking.collapsedTools": false
}
```

## Customization

### Adding a New Subagent
1. Create a new `.agent.md` file in `.github/agents/`
2. Set `user-invocable: false` if the agent should only be called via `runSubagent`, or `user-invocable: true` to allow direct selection from the agent dropdown
3. Add the agent name to the Orchestrator's `agents` list
4. Add a phase in the Orchestrator's instructions

### Adding a New Skill
1. Create a directory in `.github/skills/`
2. Add a `SKILL.md` with YAML frontmatter (`name`, `description`)
3. The skill auto-loads when relevant to the conversation

### Adding a New Hook
1. Add both a `.ps1` (Windows) and `.sh` (Linux/Mac) script to `.github/scripts/hooks/`
2. Register it in `.github/hooks/safety-and-tracking.json` using the cross-platform runner:
   ```json
   {
     "type": "command",
     "command": "node ./.github/scripts/hooks/run-hook.js <hook-name>",
     "timeout": 10
   }
   ```
3. Or register it in an agent's `hooks` frontmatter using the same pattern

## Scheduled Maintenance

The project includes a time-gated maintenance system that keeps the memory system, indexes, and skills healthy without requiring manual intervention.

### How It Works

Maintenance tasks are defined in `.github/schedule.json` with configurable intervals. On every session start, the `session-init` hook checks which tasks are overdue and runs only those, tracking execution timestamps in `.github/memory/schedule-state.json`.

| Task | Interval | What It Does |
|------|---------|---------------|
| `prune-memory` | 24h | Archives old memories, compacts unenriched auto-captures |
| `rebuild-index` | 1h | Rebuilds the searchable memory index |
| `memory-health` | 4h | Generates health metrics report |
| `detect-conflicts` | 4h | Scans for unresolved memory conflicts |
| `memory-to-skill` | 168h | Distills recurring patterns into skill updates |

### Three Trigger Mechanisms

1. **Time-gated (SessionStart)** — Tasks run automatically when overdue at the start of each chat session
2. **Reactive (PostToolUse)** — Memory index auto-rebuilds whenever a memory file is created or edited
3. **On-demand (Maintenance agent)** — Invoke the Maintenance agent directly for targeted or full maintenance runs

### Customizing the Schedule

Edit `.github/schedule.json` to add tasks, change intervals, or disable tasks.

> **Note:** Hook scripts are cross-platform. Add both a `.ps1` and `.sh` variant in `.github/scripts/hooks/`, then reference them via the cross-platform runner in the `command` field.

```json
{
  "tasks": [
    {
      "name": "my-task",
      "description": "What this task does",
      "command": "node ./.github/scripts/hooks/run-hook.js my-script",
      "interval": "12h",
      "enabled": true
    }
  ]
}
```

Supported interval units: `h` (hours), `d` (days), `m` (minutes).

## Memory System

The project includes a persistent, version-controlled memory system in `.github/memory/` that accumulates knowledge across agent conversations.

### How It Works

- **Base memory** (`.github/memory/base/project-context.md`) — Canonical project context loaded on every session start. Describes what the repo is, its architecture, agents, hooks, and conventions.
- **Agent memory** (`.github/memory/<agent>/`) — Per-agent folders where conversation memories are stored over time. Each agent builds specialized knowledge from past tasks.

### Memory File Convention

Files are named `<context-summary>-<YYYYMMDD-HHMMSS>.md`:
```
.github/memory/orchestrator/added-rest-validation-20260321-183000.md
.github/memory/planner/refactored-auth-module-20260322-100000.md
```

### Agent Workflow with Memory

1. **Session start** → Load `base/project-context.md` for foundational context
2. **Before a task** → Check the relevant agent memory folder for related past work
3. **After a task** → Create a new memory file capturing decisions and outcomes
4. **On pattern discovery** → Update `base/project-context.md` if it affects project conventions

See `.github/memory/README.md` for the full template and conventions.

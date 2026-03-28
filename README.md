<div align="center">

# 🧠 Apex Neural

### Deterministic Multi-Agent Coding Workflow for VS Code

[![VS Code](https://img.shields.io/badge/VS%20Code-1.100%2B-blue?logo=visualstudiocode)](https://code.visualstudio.com/)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](./extensions/apex-neural-memory/LICENSE)
[![Copilot](https://img.shields.io/badge/GitHub%20Copilot-Agent%20Mode-8957e5?logo=githubcopilot&logoColor=white)](https://github.com/features/copilot)

**Apex Neural** is a structured, multi-phase AI coding workflow built on VS Code's Copilot Chat agent infrastructure.
It prevents context loss, hallucination, and scope drift by enforcing deterministic phases with memory handoffs, lifecycle hooks, and context-isolated subagents.

[Quick Start](#-quick-start) · [Architecture](#-architecture) · [Agents](#-agents) · [Memory System](#-memory-system) · [Hooks](#-cross-platform-hooks) · [Customization](#-customization)

</div>

---

## 📋 Table of Contents

- [Why Apex Neural?](#-why-apex-neural)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Architecture](#-architecture)
- [Agents](#-agents)
- [Memory System](#-memory-system)
- [Cross-Platform Hooks](#-cross-platform-hooks)
- [Skills](#-skills)
- [Determinism Mechanisms](#-determinism-mechanisms)
- [Scheduled Maintenance](#-scheduled-maintenance)
- [Customization](#-customization)
- [VS Code Settings](#-vs-code-settings)
- [Repository Structure](#-repository-structure)

---

## 💡 Why Apex Neural?

Large language models in coding assistants suffer from three core problems:

| Problem | How Apex Neural Solves It |
|---------|--------------------------|
| **Context loss** | Each phase produces structured artifacts that are handed off explicitly — no information is lost between steps |
| **Hallucination** | Read-only agents (Planner, Architect) can't modify code; implementation follows an approved plan |
| **Scope drift** | Phase gates enforce that each agent completes its role before the workflow advances |

Apex Neural wraps VS Code's Copilot Chat in a deterministic pipeline — **Planning → Architecture → Implementation → Testing** — where each phase runs in an isolated subagent with restricted tools, enforced outputs, and persistent memory.

---

## ✅ Prerequisites

| Requirement | Version | Purpose |
|------------|---------|---------|
| **VS Code** | 1.100+ | Host environment with GitHub Copilot Chat |
| **GitHub Copilot** | Chat enabled | Provides the agent and tool infrastructure |
| **Node.js** | 18+ | Setup script and cross-platform hook runner |

---

## 🚀 Quick Start

Apex Neural is designed to sit alongside your project repos in a shared VS Code workspace:

```
workspace/
├── .github/              ← Apex Neural agents, hooks, skills (installed by setup)
├── apex-neural/          ← this repo
├── your-project-1/
├── your-project-2/
└── ...
```

### 1. Clone the Repository

```bash
cd /path/to/workspace
git clone https://github.com/TheJagpreet/apex-neural.git
```

### 2. Run Setup

```bash
cd apex-neural
node scripts/setup.js
```

Or pass the workspace path directly:

```bash
node scripts/setup.js --workspace /path/to/workspace
```

The setup script will:
- Copy the `.github/` folder (agents, hooks, skills, memory) to the workspace root
- Copy this README into `.github/` for reference
- Optionally install the **apex-neural-memory** VS Code extension

### 3. Start Using It

1. Open the workspace folder in VS Code
2. Open VS Code Chat (`Ctrl+Shift+I` / `Cmd+Shift+I`)
3. Select **Orchestrator** from the agents dropdown
4. Describe your task — the Orchestrator handles the rest

```
Add a REST endpoint for user profile updates with input validation and error handling
```

---

## 🏗 Architecture

The Orchestrator coordinates a strict four-phase pipeline. Each phase runs in an isolated subagent with only the tools it needs. Structured artifacts flow between phases through the memory system.

```
                          ┌──────────────────┐
                          │   USER REQUEST   │
                          └────────┬─────────┘
                                   │
                                   ▼
          ┌────────────────────────────────────────────────┐
          │               🎯 ORCHESTRATOR                   │
          │                                                 │
          │  Coordinates all phases. Never writes code.     │
          │  Tools: agent, #apex_memory, read, search       │
          │  Hooks: SessionStart, SubagentStart/Stop, Stop  │
          └──┬─────────┬──────────┬──────────┬──────┬──────┘
             │         │          │          │      │
          Phase 1   Phase 2   Phase 3   Phase 4  On Demand
             │         │          │          │      │
             ▼         ▼          ▼          ▼      ▼
          ┌──────┐ ┌────────┐ ┌────────┐ ┌──────┐ ┌───────────┐
          │PLAN- │ │ARCHI-  │ │SOLUT-  │ │TEST- │ │MAINTEN-   │
          │NER   │ │TECT    │ │IONER   │ │ER    │ │ANCE       │
          │      │ │        │ │        │ │      │ │           │
          │Read  │ │Read    │ │Full    │ │Edit  │ │Run        │
          │Only  │ │Only    │ │Edit    │ │+ Run │ │+ Report   │
          └──┬───┘ └──┬─────┘ └──┬─────┘ └──┬───┘ └─────┬─────┘
             │        │          │          │           │
             ▼        ▼          ▼          ▼           ▼
          ┌──────────────────────────────────────────────────┐
          │          📁 SESSION MEMORY (.github/memory/)      │
          │                                                   │
          │  current-plan.md ──→ architecture-decision.md     │
          │                 ──→ implementation-log.md          │
          │                 ──→ test-results.md                │
          └──────────────────────────────────────────────────┘
```

### Iteration Loops

The workflow includes built-in feedback loops with safeguards:

```
  ┌───────────┐      max 3       ┌───────────┐
  │  PLANNER  │◄─── iterations ──│ ARCHITECT  │
  │           │───── plan ──────►│           │
  └───────────┘                  └───────────┘
       If NEEDS_REVISION ──► back to Planner

  ┌───────────┐      max 5       ┌───────────┐
  │SOLUTIONER │◄─── iterations ──│  TESTER    │
  │           │───── code ──────►│           │
  └───────────┘                  └───────────┘
       If tests FAIL ──► back to Solutioner
```

---

## 🤖 Agents

Apex Neural ships with six specialized agents. All are user-invocable from VS Code Chat, but the **Orchestrator** is the recommended entry point for full workflow enforcement.

### Orchestrator *(coordinator — never writes code)*

The central coordinator that delegates work to phase-specific subagents. It manages memory handoffs, enforces phase gates, and tracks iteration counts.

- **Tools**: `agent`, `#apex_memory`, `readFile`, `search`, `codebase`, `problems`, `fetch`, `listDirectory`
- **Hooks**: SessionStart, SubagentStart/Stop, Stop

### Phase 1: Planner *(read-only)*

Analyzes the task, explores the codebase, and produces a structured implementation plan with tasks, affected files, risks, and acceptance criteria.

- **Tools**: `readFile`, `search`, `codebase`, `problems`, `#apex_memory`, `usages`, `fetch`, `listDirectory`
- **Output**: `current-plan-<timestamp>.md`

### Phase 2: Architect *(read-only)*

Validates the plan against codebase patterns, identifies reuse opportunities, flags risks, and issues a verdict: **APPROVED**, **NEEDS_REVISION**, or **BLOCKED**.

- **Tools**: `readFile`, `search`, `codebase`, `problems`, `#apex_memory`, `usages`, `fetch`, `listDirectory`
- **Output**: `architecture-decision-<timestamp>.md`

### Phase 3: Solutioner *(full edit)*

Implements code changes following the approved plan and architecture decisions. Matches existing code style, handles errors consistently, and reports any deviations.

- **Tools**: `readFile`, `search`, `edit`, `#apex_memory`, `problems`, `usages`, `runInTerminal`, `getTerminalOutput`, `listDirectory`
- **Output**: `implementation-log-<timestamp>.md`

### Phase 4: Tester *(edit + run)*

Writes and runs tests, validates acceptance criteria, and reports pass/fail/partial verdicts. Discovers existing test conventions automatically.

- **Tools**: `readFile`, `search`, `edit`, `#apex_memory`, `problems`, `runInTerminal`, `getTerminalOutput`, `usages`, `testFailure`, `listDirectory`
- **Output**: `test-results-<timestamp>.md`

### Maintenance *(on-demand)*

Runs scheduled maintenance tasks: memory pruning, index rebuilding, health checks, conflict detection, and skill enrichment.

- **Tools**: `runInTerminal`, `getTerminalOutput`, `#apex_memory`, `readFile`, `listDirectory`, `problems`
- **Trigger**: On demand or when overdue tasks are detected at session start

---

## 🧠 Memory System

Apex Neural includes a **persistent, version-controlled memory system** powered by the **apex-neural-memory** VS Code extension. All memories are stored as markdown files in `.github/memory/`, making them inspectable, diffable, and shareable across the team.

### The `#apex_memory` Tool

The extension provides a Language Model Tool called `apex-neural_memory`, referenced in chat as **`#apex_memory`**. It replaces the built-in `vscode/memory` tool to ensure all memories are saved directly to the workspace folder.

> **Important:** All agents use `#apex_memory` — not the built-in `vscode/memory`. This ensures memories are workspace-local and version-controlled.

#### Actions

| Action | Description | Example |
|--------|-------------|---------|
| **store** | Save a memory with agent name, task, tags, and content | `#apex_memory store a memory about the API design patterns we discovered` |
| **recall** | Search memories by query (matches tags, tasks, content) | `#apex_memory recall memories about authentication` |
| **list** | List all memories, optionally filtered by agent | `#apex_memory list all memories for the architect agent` |

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `action` | `store` / `recall` / `list` | ✅ | The operation to perform |
| `agent` | string | — | Agent scope (e.g., `planner`, `architect`). Defaults to `shared` |
| `task` | string | — | Brief task description (used in filename and frontmatter) |
| `tags` | string[] | — | Categorization tags (e.g., `["api", "validation"]`) |
| `content` | string | — | Markdown content of the memory |
| `outcome` | string | — | Task outcome: `completed`, `approved`, `rejected`, `failed`, `partial`, `blocked` |
| `query` | string | — | Search query for `recall` action |

### Memory File Format

Every memory file includes YAML frontmatter for structured indexing:

```yaml
---
agent: architect
date: "2026-03-25T10:00:00Z"
task: "Documented API design patterns"
tags: [api, architecture, patterns]
outcome: approved
---

# API Design Patterns

Content of the memory goes here...
```

### Memory Directory Structure

```
.github/memory/
├── base/                # Foundational project context
│   └── project-context.md
├── orchestrator/        # Orchestrator conversation memories
├── planner/             # Planner conversation memories
├── architect/           # Architect conversation memories
├── solutioner/          # Solutioner conversation memories
├── tester/              # Tester conversation memories
└── shared/              # Cross-agent shared memories
```

### Memory Lifecycle

```
Session Start ──→ Load base/project-context.md
       │
       ├──→ Check agent memory folder for related past work
       │
       ├──→ Execute task
       │
       ├──→ Save memory file with structured frontmatter
       │
       └──→ Promote discoveries to shared/ if project-wide
```

### Conventions

- Files use kebab-case naming: `<context-summary>-<YYYYMMDD-HHMMSS>.md`
- Tags are lowercase, single-word: `api`, `auth`, `database`, `testing`, `security`, `bugfix`, `architecture`
- Always use `#apex_memory` — never `vscode/memory`

---

## 🪝 Cross-Platform Hooks

All hooks work on **Windows**, **Linux**, and **macOS**. Each hook has both a PowerShell (`.ps1`) and bash (`.sh`) implementation, with a Node.js dispatcher that selects the right one at runtime.

### Hook Dispatch Flow

```
                      ┌──────────────────────┐
                      │  run-hook.js <name>   │
                      └──────────┬───────────┘
                                 │
                 ┌───────────────┼───────────────┐
                 │               │               │
            Windows          Linux           macOS
                 │               │               │
                 ▼               ▼               ▼
         <name>.ps1        <name>.sh        <name>.sh
         (PowerShell)      (bash/sh)        (bash/sh)
```

### Registered Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `pre-tool-guard` | **PreToolUse** | Blocks destructive terminal commands and hook self-modification |
| `post-edit-lint` | **PostToolUse** | Runs linter/formatter after file edits; validates JSON; triggers reactive maintenance |
| `session-init` | **SessionStart** | Injects project context, git branch, and `#apex_memory` usage hints |
| `subagent-tracker` | **SubagentStart/Stop** | Logs subagent lifecycle events and injects phase-specific context |
| `phase-gate` | **Stop** | Validates that required phase outputs were saved before allowing completion |

### Hook Registration

Hooks are registered in two places:

1. **Workspace-level** (`.github/hooks/safety-and-tracking.json`) — applies to all agents
2. **Agent-level** (in the agent's YAML frontmatter `hooks` field) — applies to a specific agent

Both use the cross-platform runner:

```json
{
  "type": "command",
  "command": "node ./.github/scripts/hooks/run-hook.js <hook-name>",
  "timeout": 10
}
```

---

## 📚 Skills

Skills are auto-loading knowledge modules that provide domain-specific guidance when relevant to the conversation. They live in `.github/skills/`.

| Skill | Description |
|-------|-------------|
| **codebase-analysis** | Systematic approach to analyzing project structure, patterns, conventions, and dependencies |
| **implementation-patterns** | Best practices for error handling, input validation, security, and clean code |
| **test-strategy** | Testing strategies following the test pyramid: unit → integration → end-to-end |

### Adding a Skill

1. Create a directory in `.github/skills/<skill-name>/`
2. Add a `SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: my-skill
   description: "What this skill provides"
   ---
   ```
3. The skill auto-loads when relevant to the conversation

---

## 🔒 Determinism Mechanisms

Apex Neural enforces deterministic behavior through multiple layers:

| Mechanism | Purpose |
|-----------|---------|
| **Subagent context isolation** | Each subagent receives only the previous phase's output — prevents context overflow |
| **Session memory handoffs** | Plans, decisions, and logs are saved as structured markdown artifacts |
| **Phase gates** | Stop hooks verify required outputs before allowing phase completion |
| **Tool restrictions** | Planner/Architect are read-only; Solutioner can edit; Tester can edit + run |
| **Pre-tool safety guard** | Blocks destructive terminal commands and hook self-modification |
| **Post-edit linting** | Lint/format hooks run automatically after every file edit |
| **Reactive maintenance** | Memory index auto-rebuilds after memory file writes |
| **Time-gated scheduling** | Maintenance tasks only run when overdue based on configurable intervals |
| **Subagent tracking** | All subagent start/stop events are logged with timestamps |
| **Iteration limits** | Max 3 plan ↔ architect iterations, max 5 solution ↔ test iterations |
| **Phase-specific prompts** | SubagentStart hook injects role reminders at each phase transition |

---

## 🔧 Scheduled Maintenance

The maintenance system keeps memory indexes, skills, and health reports fresh without manual intervention.

### Trigger Mechanisms

```
┌──────────────────────────────────────────────────────────┐
│                  MAINTENANCE TRIGGERS                     │
├──────────────────┬──────────────────┬────────────────────┤
│   ⏰ Time-Gated  │  ⚡ Reactive      │  🎯 On-Demand     │
│                  │                  │                    │
│  SessionStart    │  PostToolUse     │  Maintenance       │
│  checks overdue  │  auto-rebuilds   │  agent invoked     │
│  tasks and runs  │  memory index    │  directly by user  │
│  them            │  on file writes  │  or orchestrator   │
└──────────────────┴──────────────────┴────────────────────┘
```

### Configurable Tasks

Tasks are defined in `.github/schedule.json` with configurable intervals. Execution timestamps are tracked in `.github/memory/schedule-state.json`.

| Task | Default Interval | What It Does |
|------|-----------------|--------------|
| `prune-memory` | 24h | Archives old memories, compacts unenriched auto-captures |
| `rebuild-index` | 1h | Rebuilds the searchable memory index |
| `memory-health` | 4h | Generates health metrics report |
| `detect-conflicts` | 4h | Scans for unresolved memory conflicts |
| `memory-to-skill` | 168h (weekly) | Distills recurring patterns into skill updates |

### Customizing the Schedule

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

---

## 🎨 Customization

### Adding a New Agent

1. Create a `.agent.md` file in `.github/agents/`
2. Set `user-invocable: true` for direct access from the Chat dropdown, or `false` for subagent-only
3. Add the agent name to the Orchestrator's `agents` list in its frontmatter
4. Define the agent's phase in the Orchestrator's instructions

### Adding a New Hook

1. Create both a `.ps1` (Windows) and `.sh` (Linux/Mac) script in `.github/scripts/hooks/`
2. Register it in `.github/hooks/safety-and-tracking.json`:
   ```json
   {
     "type": "command",
     "command": "node ./.github/scripts/hooks/run-hook.js <hook-name>",
     "timeout": 10
   }
   ```
3. Or register it in an agent's `hooks` frontmatter for agent-scoped hooks

### Tool Sets

Tool sets group related tools for easy assignment to agents. Defined in `.github/tool-sets.json`:

| Tool Set | Tools | Description |
|----------|-------|-------------|
| **reader** | `codebase`, `search`, `readFile`, `problems`, `usages`, `listDirectory`, `fileSearch` | Read-only code exploration |
| **writer** | `editFiles`, `createFile`, `createDirectory` | File creation and modification |
| **runner** | `runInTerminal`, `getTerminalOutput`, `problems` | Command execution and diagnostics |
| **workflow** | `runSubagent`, `apex-neural_memory` | Agent orchestration and memory management |

---

## ⚙ VS Code Settings

Enable these settings for the best experience:

```json
{
  "chat.useCustomAgentHooks": true,
  "chat.agent.thinking.collapsedTools": false
}
```

Ensure the **apex-neural-memory** extension is installed (the setup script offers to install it automatically).

---

## 📁 Repository Structure

```
apex-neural/
├── .github/
│   ├── agents/                          # Agent definitions
│   │   ├── orchestrator.agent.md          # Main coordinator
│   │   ├── planner.agent.md               # Planning agent
│   │   ├── architect.agent.md             # Architecture agent
│   │   ├── solutioner.agent.md            # Implementation agent
│   │   ├── tester.agent.md                # Testing agent
│   │   └── maintenance.agent.md           # Maintenance agent
│   ├── hooks/
│   │   └── safety-and-tracking.json       # Workspace-level hook registration
│   ├── memory/                            # Version-controlled memory store
│   │   ├── base/
│   │   │   └── project-context.md           # Core project context
│   │   ├── orchestrator/                    # Orchestrator memories
│   │   ├── planner/                         # Planner memories
│   │   ├── architect/                       # Architect memories
│   │   ├── solutioner/                      # Solutioner memories
│   │   ├── tester/                          # Tester memories
│   │   ├── shared/                          # Cross-agent memories
│   │   └── schedule-state.json              # Maintenance timestamps
│   ├── scripts/
│   │   └── hooks/                           # Cross-platform hook scripts
│   │       ├── run-hook.js                    # OS dispatcher (Node.js)
│   │       ├── session-init.{sh,ps1}          # Session initialization
│   │       ├── pre-tool-guard.{sh,ps1}        # Safety guard
│   │       ├── post-edit-lint.{sh,ps1}        # Linting + reactive maintenance
│   │       ├── subagent-tracker.{sh,ps1}      # Lifecycle logging
│   │       └── phase-gate.{sh,ps1}            # Phase validation
│   ├── skills/                              # Auto-loading knowledge modules
│   │   ├── codebase-analysis/SKILL.md
│   │   ├── implementation-patterns/SKILL.md
│   │   └── test-strategy/SKILL.md
│   ├── copilot-instructions.md              # Global project instructions
│   ├── schedule.json                        # Maintenance task definitions
│   └── tool-sets.json                       # Grouped tool collections
├── extensions/
│   └── apex-neural-memory/                  # VS Code extension
│       ├── src/
│       │   ├── extension.ts                   # Extension entry point
│       │   ├── memoryTool.ts                  # Memory tool implementation
│       │   └── test/memoryTool.test.ts        # Unit tests
│       ├── package.json                       # Extension manifest
│       └── README.md                          # Extension documentation
├── scripts/
│   └── setup.js                             # Interactive workspace setup
└── README.md                                # ← You are here
```

---

<div align="center">

**Built for deterministic AI-assisted development.**

[Report an Issue](https://github.com/TheJagpreet/apex-neural/issues) · [Contribute](https://github.com/TheJagpreet/apex-neural/pulls)

</div>

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
- [MCP Servers (Playwright)](#-mcp-servers-playwright)
- [Determinism Mechanisms](#-determinism-mechanisms)
- [Scheduled Maintenance](#-scheduled-maintenance)
- [Customization](#-customization)
- [Agent Plugin (Preview)](#-agent-plugin-preview)
- [LangGraph Edition (Python + Ollama)](#-langgraph-edition-python--ollama)
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
├── .vscode/
│   └── mcp.json          ← MCP server config (Playwright) (installed by setup)
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

Choose the setup method for your platform:

**Node.js (all platforms):**
```bash
cd apex-neural
node scripts/setup.js
```

**Bash (Linux / macOS):**
```bash
cd apex-neural
./scripts/setup.sh
```

**PowerShell (Windows / cross-platform):**
```powershell
cd apex-neural
.\scripts\setup.ps1
```

**Windows Batch:**
```cmd
cd apex-neural
scripts\setup.cmd
```

Or pass the workspace path directly:

```bash
node scripts/setup.js --workspace /path/to/workspace
./scripts/setup.sh --workspace /path/to/workspace
```
```powershell
.\scripts\setup.ps1 -Workspace C:\path\to\workspace
```

The setup script will:
- Copy the `.github/` folder (agents, hooks, skills, memory) to the workspace root
- Copy this README into `.github/` for reference
- Copy `.vscode/mcp.json` (Playwright MCP server configuration) to the workspace
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
          ┌────────────────────────────────────────────────────────────┐
          │               🎯 ORCHESTRATOR                               │
          │                                                             │
          │  Coordinates all phases. Never writes code.                 │
          │  Tools: agent, #apex_neural_memory, read, search           │
          │  Hooks: SessionStart, SubagentStart/Stop, Stop             │
          └──┬─────────┬──────────┬──────────┬──────┬──────┬──────────┘
             │         │          │          │      │      │
          Phase 1   Phase 2   Phase 3   Phase 4  On Demand Standalone
             │         │          │          │      │      │
             ▼         ▼          ▼          ▼      ▼      ▼
          ┌──────┐ ┌────────┐ ┌────────┐ ┌──────┐ ┌─────┐ ┌─────────┐
          │PLAN- │ │ARCHI-  │ │SOLUT-  │ │TEST- │ │MAIN-│ │SKILL    │
          │NER   │ │TECT    │ │IONER   │ │ER    │ │TEN- │ │CREATOR  │
          │      │ │        │ │        │ │      │ │ANCE │ │         │
          │Read  │ │Read    │ │Full    │ │Edit  │ │Run  │ │Edit     │
          │Only  │ │Only    │ │Edit    │ │+ Run │ │+ Rpt│ │+ Create │
          └──┬───┘ └──┬─────┘ └──┬─────┘ └──┬───┘ └──┬──┘ └────┬────┘
             │        │          │          │        │         │
             ▼        ▼          ▼          ▼        ▼         ▼
          ┌──────────────────────────────────────────────────────────┐
          │          📁 SESSION MEMORY (.github/memory/)              │
          │                                                           │
          │  current-plan.md ──→ architecture-decision.md             │
          │                 ──→ implementation-log.md                  │
          │                 ──→ test-results.md                        │
          └──────────────────────────────────────────────────────────┘
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

Apex Neural ships with seven specialized agents. All are user-invocable from VS Code Chat, but the **Orchestrator** is the recommended entry point for full workflow enforcement.

### Orchestrator *(coordinator — never writes code)*

The central coordinator that delegates work to phase-specific subagents. It manages memory handoffs, enforces phase gates, and tracks iteration counts.

- **Tools**: `agent`, `#apex_neural_memory`, `readFile`, `search`, `codebase`, `problems`, `fetch`, `listDirectory`
- **Hooks**: SessionStart, SubagentStart/Stop, Stop

### Phase 1: Planner *(read-only)*

Analyzes the task, explores the codebase, and produces a structured implementation plan with tasks, affected files, risks, and acceptance criteria.

- **Tools**: `readFile`, `search`, `codebase`, `problems`, `#apex_neural_memory`, `usages`, `fetch`, `listDirectory`
- **Output**: `current-plan-<timestamp>.md`

### Phase 2: Architect *(read-only)*

Validates the plan against codebase patterns, identifies reuse opportunities, flags risks, and issues a verdict: **APPROVED**, **NEEDS_REVISION**, or **BLOCKED**.

- **Tools**: `readFile`, `search`, `codebase`, `problems`, `#apex_neural_memory`, `usages`, `fetch`, `listDirectory`
- **Output**: `architecture-decision-<timestamp>.md`

### Phase 3: Solutioner *(full edit)*

Implements code changes following the approved plan and architecture decisions. Matches existing code style, handles errors consistently, and reports any deviations.

- **Tools**: `readFile`, `search`, `edit`, `#apex_neural_memory`, `problems`, `usages`, `runInTerminal`, `getTerminalOutput`, `listDirectory`
- **Output**: `implementation-log-<timestamp>.md`

### Phase 4: Tester *(edit + run)*

Writes and runs tests, validates acceptance criteria, and reports pass/fail/partial verdicts. Discovers existing test conventions automatically.

- **Tools**: `readFile`, `search`, `edit`, `#apex_neural_memory`, `problems`, `runInTerminal`, `getTerminalOutput`, `usages`, `testFailure`, `listDirectory`
- **Output**: `test-results-<timestamp>.md`

### Maintenance *(on-demand)*

Runs scheduled maintenance tasks: memory pruning, index rebuilding, health checks, conflict detection, and skill enrichment.

- **Tools**: `runInTerminal`, `getTerminalOutput`, `#apex_neural_memory`, `readFile`, `listDirectory`, `problems`
- **Trigger**: On demand or when overdue tasks are detected at session start

### Skill Creator *(standalone)*

Creates new skills, modifies existing skills, and validates skill structure. Disjoint from the main workflow — can be invoked independently by the user or the Orchestrator.

- **Tools**: `readFile`, `search`, `edit`, `#apex_neural_memory`, `problems`, `listDirectory`, `createFile`, `codebase`
- **Output**: New or updated skill in `.github/skills/`, registered in `plugin.json`

---

## 🧠 Memory System

Apex Neural includes a **persistent, version-controlled memory system** powered by the **apex-neural-memory** VS Code extension. All memories are stored as markdown files in `.github/memory/`, making them inspectable, diffable, and shareable across the team.

### The `#apex_neural_memory` Tool

The extension provides a Language Model Tool called `apex_neural_memory`, referenced in chat as **`#apex_neural_memory`**. It replaces the built-in `vscode/memory` tool to ensure all memories are saved directly to the workspace folder.

> **Important:** All agents use `#apex_neural_memory` — not the built-in `vscode/memory`. This ensures memories are workspace-local and version-controlled.

#### Actions

| Action | Description | Example |
|--------|-------------|---------|
| **store** | Save a memory with agent name, task, tags, and content | `#apex_neural_memory store a memory about the API design patterns we discovered` |
| **recall** | Search memories by query (matches tags, tasks, content) | `#apex_neural_memory recall memories about authentication` |
| **list** | List all memories, optionally filtered by agent | `#apex_neural_memory list all memories for the architect agent` |

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
- Always use `#apex_neural_memory` — never `vscode/memory`

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
| `session-init` | **SessionStart** | Injects project context, git branch, and `#apex_neural_memory` usage hints |
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
| **frontend-testing** | Frontend and E2E testing with the Microsoft Playwright MCP server for browser automation |
| **nodejs-testing** | Node.js/TypeScript backend testing patterns for Jest, Vitest, Mocha, and node:test |
| **python-testing** | Python backend testing patterns for pytest, Django, Flask, and FastAPI |
| **skill-creator** | Guides skill creation, editing, and description optimization for better triggering accuracy |

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

## 🌐 MCP Servers (Playwright)

The Tester agent supports the **Model Context Protocol (MCP)** to integrate external tools. The workspace includes a pre-configured Playwright MCP server for browser-based end-to-end testing.

### Configuration

The MCP server is defined in `.vscode/mcp.json` (copied by the setup script):

```json
{
  "servers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest"],
      "type": "stdio"
    }
  }
}
```

### What It Provides

The Playwright MCP server gives agents real-time browser control via the Model Context Protocol:

| Category | Tools |
|----------|-------|
| **Navigation** | `browser_navigate`, `browser_navigate_back`, `browser_click`, `browser_type`, `browser_hover`, `browser_press_key` |
| **Observation** | `browser_snapshot`, `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests` |
| **Tab management** | `browser_tab_list`, `browser_tab_new`, `browser_tab_select`, `browser_tab_close` |
| **Page control** | `browser_wait`, `browser_resize`, `browser_evaluate`, `browser_file_upload`, `browser_drag`, `browser_select_option` |

### How It Works

1. VS Code detects the MCP server configuration in `.vscode/mcp.json`
2. When the Tester agent needs to perform browser-based testing, it calls Playwright MCP tools
3. The MCP server launches a Chromium browser and executes the requested actions
4. Results (screenshots, accessibility snapshots, network logs) are returned to the agent

### Requirements

- **Node.js 18+** must be installed (the server uses `npx` to auto-download `@playwright/mcp`)
- **VS Code 1.100+** with MCP server support enabled
- First run may take longer as it downloads the Playwright browser binaries

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
| **workflow** | `runSubagent`, `apex_neural_memory` | Agent orchestration and memory management |

---

---

## 🔌 Agent Plugin (Preview)

Apex Neural can be installed as a **VS Code Copilot agent plugin**, making it discoverable and manageable directly from VS Code's Extensions sidebar. This is an alternative to the manual [setup script](#-quick-start) approach.

> **Note:** Agent plugins require VS Code 1.100+ with `chat.plugins.enabled` set to `true`.

### Install from Source

1. Open the Command Palette (`Ctrl+Shift+P` / `Cmd+Shift+P`)
2. Run **Chat: Install Plugin From Source**
3. Enter the repository URL:
   ```
   https://github.com/TheJagpreet/apex-neural
   ```

VS Code clones the repository and registers its agents, skills, and hooks automatically.

### Install as a Local Plugin

If you've already cloned the repo, register it as a local plugin in your VS Code settings:

```json
// settings.json
"chat.pluginLocations": {
    "/path/to/apex-neural": true
}
```

### What the Plugin Provides

The `plugin.json` manifest at the repository root declares the following components:

| Component | Path | Description |
|-----------|------|-------------|
| **Agents** | `.github/agents/` | Orchestrator, Planner, Architect, Solutioner, Tester, Maintenance, Skill Creator |
| **Skills** | `.github/skills/` | Codebase Analysis, Implementation Patterns, Test Strategy, Frontend Testing, Node.js Testing, Python Testing, Skill Creator |
| **Hooks** | `hooks.json` | Pre-tool guard, post-edit lint, session init, subagent tracker, phase gate |
| **Hook scripts** | `.github/scripts/hooks/` | Cross-platform scripts (`run-hook.js`, `.sh`, `.ps1`) referenced by hooks |
| **MCP config** | `.vscode/mcp.json` | Playwright MCP server for browser-based E2E testing |

> **How hooks work in plugin mode:** The plugin-root `hooks.json` uses `${CLAUDE_PLUGIN_ROOT}` tokens so VS Code resolves paths to the hook scripts within the installed plugin directory. The workspace-level `safety-and-tracking.json` (used by the setup script) uses relative paths instead.

### Manage the Plugin

- **Enable/Disable**: Right-click the plugin in the **Agent Plugins - Installed** view in the Extensions sidebar
- **Browse plugins**: Search `@agentPlugins` in the Extensions view
- **Uninstall**: Right-click → Uninstall from the Extensions sidebar

> **Important:** The plugin bundles hooks that execute shell commands. Review the contents before installing.

### Plugin vs Setup Script

| Feature | Plugin Install | Setup Script |
|---------|----------------|--------------|
| **Installation** | One command from VS Code | Run `node scripts/setup.js` |
| **Updates** | Automatic via Extensions | Re-run setup script |
| **Scope** | User-level (all workspaces) | Per-workspace |
| **Memory extension** | Install separately | Prompted during setup |
| **Requires** | VS Code 1.100+, `chat.plugins.enabled` | Node.js 18+ |

Both methods require the **apex-neural-memory** VS Code extension for the memory system.

---

## 🐍 LangGraph Edition (Python + Ollama)

Apex Neural also ships with a **standalone Python implementation** of the same deterministic SDLC workflow, built on [LangGraph](https://github.com/langchain-ai/langgraph) and powered by [Ollama](https://ollama.com/) for local LLM inference. This lives in the `langgraph/` directory at the repository root.

### Why LangGraph?

The LangGraph edition provides the same end-to-end agent orchestration without requiring VS Code or GitHub Copilot:

| Feature | VS Code (.github/) | LangGraph (langgraph/) |
|---------|--------------------|-----------------------|
| **Runtime** | VS Code Copilot Chat | Python CLI / API |
| **LLM** | GitHub Copilot | Ollama (local, private) |
| **Orchestration** | Agent handoffs + hooks | LangGraph StateGraph |
| **Memory** | VS Code extension (TypeScript) | Python tool (same format) |
| **Phase gates** | Hook scripts (bash/ps1) | Conditional graph edges |
| **Iteration limits** | Orchestrator instructions | Graph routing functions |

### Quick Start

```bash
# 1. Install Ollama and pull a model
ollama pull llama3.1

# 2. Install Python dependencies
cd langgraph
pip install -r requirements.txt

# 3. Run the full SDLC workflow
python -m apex_neural "Add a REST endpoint for user profile updates"

# 4. Or run maintenance only
python -m apex_neural --maintenance
```

### Configuration

| Environment Variable | Default | Description |
|---------------------|---------|-------------|
| `OLLAMA_MODEL` | `llama3.1` | Ollama model name |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama server URL |
| `OLLAMA_TEMPERATURE` | `0.2` | Sampling temperature |
| `APEX_MEMORY_ROOT` | `.github/memory` | Memory storage directory |

### Memory Tool

The Python memory tool is a direct port of the TypeScript `MemoryTool` from the `apex-neural-memory` VS Code extension. It stores, recalls, and lists memories as Markdown files with YAML frontmatter — using the exact same file format and directory structure. Both implementations can read each other's memory files.

### Testing

```bash
cd langgraph
pip install -e ".[dev]"
pytest
```

> See [`langgraph/README.md`](./langgraph/README.md) for the complete LangGraph documentation.

---

## ⚙ VS Code Settings

Enable these settings for the best experience:

```json
{
  "chat.useCustomAgentHooks": true,
  "chat.agent.thinking.collapsedTools": false,
  "chat.plugins.enabled": true
}
```

Ensure the **apex-neural-memory** extension is installed (the setup script offers to install it automatically).

---

## 📁 Repository Structure

```
apex-neural/
├── plugin.json                              # Agent plugin manifest (VS Code Copilot)
├── hooks.json                               # Plugin hooks with ${CLAUDE_PLUGIN_ROOT} paths
├── .github/
│   ├── agents/                          # Agent definitions
│   │   ├── orchestrator.agent.md          # Main coordinator
│   │   ├── planner.agent.md               # Planning agent
│   │   ├── architect.agent.md             # Architecture agent
│   │   ├── solutioner.agent.md            # Implementation agent
│   │   ├── tester.agent.md                # Testing agent
│   │   ├── maintenance.agent.md           # Maintenance agent
│   │   └── skill-creator.agent.md         # Skill creation agent
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
│   │   ├── test-strategy/SKILL.md
│   │   ├── frontend-testing/SKILL.md          # Playwright MCP browser testing
│   │   ├── nodejs-testing/SKILL.md            # Node.js/TypeScript testing
│   │   ├── python-testing/SKILL.md            # Python testing
│   │   └── skill-creator/SKILL.md
│   ├── copilot-instructions.md              # Global project instructions
│   ├── schedule.json                        # Maintenance task definitions
│   └── tool-sets.json                       # Grouped tool collections
├── .vscode/
│   ├── launch.json                          # VS Code debug configuration
│   └── mcp.json                             # MCP server config (Playwright)
├── extensions/
│   └── apex-neural-memory/                  # VS Code extension
│       ├── src/
│       │   ├── extension.ts                   # Extension entry point
│       │   ├── memoryTool.ts                  # Memory tool implementation
│       │   └── test/memoryTool.test.ts        # Unit tests
│       ├── package.json                       # Extension manifest
│       └── README.md                          # Extension documentation
├── scripts/
│   ├── setup.js                             # Interactive workspace setup (Node.js)
│   ├── setup.sh                             # Interactive workspace setup (Bash — Linux/macOS)
│   ├── setup.ps1                            # Interactive workspace setup (PowerShell — Windows)
│   └── setup.cmd                            # Windows batch wrapper
├── langgraph/                               # LangGraph Python edition
│   ├── apex_neural/                         # Python package
│   │   ├── agents/                            # Agent nodes (planner, architect, etc.)
│   │   ├── tools/
│   │   │   └── memory_tool.py                 # Python memory tool (store/recall/list)
│   │   ├── config.py                          # Ollama LLM configuration
│   │   ├── state.py                           # WorkflowState schema (Pydantic)
│   │   ├── orchestrator.py                    # LangGraph StateGraph workflow
│   │   └── main.py                            # CLI entry point
│   ├── tests/                               # Pytest test suite
│   ├── pyproject.toml                       # Python project metadata
│   ├── requirements.txt                     # Dependencies
│   └── README.md                            # LangGraph documentation
└── README.md                                # ← You are here
```

---

<div align="center">

**Built for deterministic AI-assisted development.**

[Report an Issue](https://github.com/TheJagpreet/apex-neural/issues) · [Contribute](https://github.com/TheJagpreet/apex-neural/pulls)

</div>

# 🧠 Apex Neural — LangGraph Edition

**Deterministic multi-agent SDLC workflow using LangGraph and Ollama.**

This is a standalone Python implementation of the same end-to-end agent orchestration flow defined in the `.github/` folder (VS Code Copilot agents). It uses [LangGraph](https://github.com/langchain-ai/langgraph) for the state-machine workflow and [Ollama](https://ollama.com/) as the local LLM backend.

---

## Architecture

The orchestrator implements the same four-phase deterministic pipeline:

```
                          ┌──────────────────┐
                          │   USER REQUEST   │
                          └────────┬─────────┘
                                   │
                                   ▼
          ┌────────────────────────────────────────────────────────────┐
          │               🎯 ORCHESTRATOR (LangGraph StateGraph)       │
          │                                                            │
          │  Coordinates all phases. Never writes code.                │
          │  Routes: conditional edges with iteration limits           │
          └──┬─────────┬──────────┬──────────┬─────────────────────────┘
             │         │          │          │
          Phase 1   Phase 2   Phase 3   Phase 4
             │         │          │          │
             ▼         ▼          ▼          ▼
          ┌──────┐ ┌────────┐ ┌────────┐ ┌──────┐
          │PLAN- │ │ARCHI-  │ │SOLUT-  │ │TEST- │
          │NER   │ │TECT    │ │IONER   │ │ER    │
          │      │ │        │ │        │ │      │
          │Read  │ │Read    │ │Full    │ │Edit  │
          │Only  │ │Only    │ │Edit    │ │+ Run │
          └──┬───┘ └──┬─────┘ └──┬─────┘ └──┬───┘
             │        │          │          │
             ▼        ▼          ▼          ▼
          ┌──────────────────────────────────────────────────────────┐
          │          📁 MEMORY SYSTEM (.github/memory/)              │
          │                                                          │
          │  Python memory_tool: store / recall / list               │
          │  Markdown files with YAML frontmatter                    │
          └──────────────────────────────────────────────────────────┘
```

### Iteration Loops

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

## Quick Start

### Prerequisites

| Requirement | Version | Purpose |
|------------|---------|---------|
| **Python** | 3.11+ | Runtime |
| **Ollama** | Latest | Local LLM server |

### 1. Install Ollama and pull a model

```bash
# Install Ollama: https://ollama.com/download
ollama pull llama3.1
```

### 2. Install dependencies

```bash
cd langgraph
pip install -r requirements.txt
```

Or using pip with pyproject.toml:

```bash
cd langgraph
pip install -e ".[dev]"
```

### 3. Run a task

```bash
# Full SDLC workflow
python -m apex_neural "Add a REST endpoint for user profile updates"

# Run maintenance only
python -m apex_neural --maintenance
```

### 4. Configuration

Environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `OLLAMA_MODEL` | `llama3.1` | Ollama model name |
| `OLLAMA_BASE_URL` | `http://localhost:11434` | Ollama server URL |
| `OLLAMA_TEMPERATURE` | `0.2` | Sampling temperature |
| `APEX_MEMORY_ROOT` | `.github/memory` | Memory storage directory |

---

## Project Structure

```
langgraph/
├── apex_neural/                 # Python package
│   ├── __init__.py              # Package marker
│   ├── __main__.py              # python -m apex_neural support
│   ├── main.py                  # CLI entry point
│   ├── config.py                # Ollama LLM configuration
│   ├── state.py                 # WorkflowState schema (Pydantic)
│   ├── orchestrator.py          # LangGraph StateGraph — the core workflow
│   ├── agents/
│   │   ├── __init__.py
│   │   ├── planner.py           # Phase 1: Task decomposition & planning
│   │   ├── architect.py         # Phase 2: Design validation & review
│   │   ├── solutioner.py        # Phase 3: Code implementation
│   │   ├── tester.py            # Phase 4: Test creation & validation
│   │   └── maintenance.py       # On-demand: Memory system maintenance
│   ├── tools/
│   │   ├── __init__.py
│   │   └── memory_tool.py       # Python memory tool (store/recall/list)
│   └── memory/
│       └── __init__.py
├── tests/
│   ├── __init__.py
│   ├── test_memory_tool.py      # Memory tool unit + integration tests
│   ├── test_orchestrator.py     # Graph structure & routing tests
│   └── test_config.py           # LLM configuration tests
├── pyproject.toml               # Python project metadata
├── requirements.txt             # Dependencies
└── README.md                    # ← You are here
```

---

## Memory System

The Python memory tool is a direct port of the TypeScript `MemoryTool` class from the `apex-neural-memory` VS Code extension. It provides the same three operations:

| Action | Description |
|--------|-------------|
| `memory_store` | Save a memory as a Markdown file with YAML frontmatter |
| `memory_recall` | Search memories by query (matches tags, task, content) |
| `memory_list` | List all memories, optionally filtered by agent |

Memories are stored in the same format and directory structure as the VS Code extension:

```
.github/memory/
├── planner/          # Planner agent memories
├── architect/        # Architect agent memories
├── solutioner/       # Solutioner agent memories
├── tester/           # Tester agent memories
├── shared/           # Cross-agent shared memories
└── schedule-state.json
```

Each memory file includes YAML frontmatter:

```yaml
---
agent: planner
date: "2026-03-25T10:00:00Z"
task: "Implementation plan: Add REST endpoint"
tags: [plan, planning]
outcome: completed
---

# Implementation Plan: ...
```

---

## Agents

### Planner (Phase 1)
Read-only agent that analyses the task and produces a structured implementation plan with tasks, affected files, risks, and acceptance criteria.

### Architect (Phase 2)
Read-only agent that validates the plan against codebase patterns, identifies reuse opportunities, and issues a verdict: **APPROVED**, **NEEDS_REVISION**, or **BLOCKED**.

### Solutioner (Phase 3)
Implementation agent that writes production-quality code following the approved plan and architecture decisions.

### Tester (Phase 4)
Quality assurance agent that writes and runs tests, validates acceptance criteria, and reports **PASS**, **FAIL**, or **PARTIAL** verdicts.

### Maintenance (On-demand)
Standalone agent for memory system health checks, pruning, and index rebuilding.

---

## Testing

```bash
cd langgraph
pip install -e ".[dev]"
pytest
```

---

## Comparison: VS Code Agents vs LangGraph

| Feature | VS Code (.github/) | LangGraph (langgraph/) |
|---------|--------------------|-----------------------|
| **Runtime** | VS Code Copilot Chat | Python CLI / API |
| **LLM** | GitHub Copilot | Ollama (local) |
| **Orchestration** | Agent handoffs + hooks | LangGraph StateGraph |
| **Memory** | VS Code extension (TypeScript) | Python tool (same format) |
| **Phase gates** | Hook scripts (bash/ps1) | Conditional graph edges |
| **Iteration limits** | Orchestrator instructions | Graph routing functions |
| **Skills** | Auto-loading SKILL.md files | System prompts in agent nodes |

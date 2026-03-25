# Apex Neural Memory

A VS Code extension that provides a workspace-local memory tool for the Apex Neural agent ecosystem. This replaces the built-in `vscode/memory` tool, ensuring memories are saved directly to the workspace `.github/memory/` folder instead of VS Code's server storage.

## Features

The extension contributes a single Language Model Tool called `apex-neural_memory` (referenced as `#memory` in chat) with three actions:

### Store

Save a new memory as a markdown file with YAML frontmatter.

```
#memory store a new memory for the architect agent about the API design patterns we discovered
```

**Parameters:**
- `action`: `"store"` (required)
- `agent`: Agent name (e.g., `orchestrator`, `planner`, `architect`, `solutioner`, `tester`, `shared`). Defaults to `shared`.
- `task`: Brief description of the task or context.
- `tags`: Array of categorization tags (e.g., `["api", "validation"]`).
- `content`: Markdown content of the memory.
- `outcome`: Task outcome (`completed`, `approved`, `rejected`, `failed`, `partial`, `blocked`). Defaults to `completed`.

### Recall

Search existing memories by query string. Matches against tags, task descriptions, agent names, and content.

```
#memory recall memories about API validation
```

**Parameters:**
- `action`: `"recall"` (required)
- `query`: Search query string.
- `agent`: Optionally filter by agent name.

### List

List all memories, optionally filtered by agent.

```
#memory list all memories for the tester agent
```

**Parameters:**
- `action`: `"list"` (required)
- `agent`: Optionally filter by agent name.

## Memory File Format

Memories are stored as markdown files in `.github/memory/<agent>/` with YAML frontmatter:

```markdown
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

### File Naming

Files follow the pattern: `<context-summary>-<YYYYMMDD-HHMMSS>.md`

Examples:
- `api-design-patterns-20260325-100000.md`
- `fixed-auth-race-condition-20260325-143000.md`

## Directory Structure

```
.github/memory/
├── orchestrator/     # Orchestrator agent memories
├── planner/          # Planner agent memories
├── architect/        # Architect agent memories
├── solutioner/       # Solutioner agent memories
├── tester/           # Tester agent memories
└── shared/           # Cross-agent shared memories
```

Directories are created automatically when a memory is stored.

## Development

```bash
cd extensions/apex-neural-memory
npm install
npm run compile
```

Press **F5** in VS Code to launch the Extension Development Host for testing.

## Building

```bash
npm run vscode:prepublish
```

# Project Instructions — Apex Neural

## Workflow

This project uses a deterministic agent workflow. When working on any non-trivial task, use the **Orchestrator** agent which coordinates: **Planning → Architecture → Solutioning → Testing**.

Do NOT skip phases. Every feature or bug fix flows through all four phases.

## Code Conventions

- Follow existing patterns in the codebase — do not introduce new patterns without Architect approval
- Use descriptive naming: variables, functions, files
- Keep functions focused and short
- Handle errors explicitly — never silently swallow exceptions
- Validate inputs at system boundaries

## Memory Usage

Memory is managed by the **apex-neural-memory** VS Code extension, which provides the `apex_neural_memory` tool. This tool saves memories directly to the workspace folder at `.github/memory/`, ensuring they are version-controlled and accessible across sessions.

### Using the Memory Tool

Agents should use the `apex_neural_memory` tool (referenced as `#apex_neural_memory` in chat) with the following actions:

- **store**: Save a memory with agent name, task, tags, and content
- **recall**: Search memories by query (matches against tags, task descriptions, and content)
- **list**: List all memories, optionally filtered by agent

### Memory Structure

The extension manages the following workspace structure:

```
.github/memory/
├── <agent>/           # Per-agent memory folders (auto-created)
│   └── <context>-<timestamp>.md
└── shared/            # Cross-agent shared memories
    └── <context>-<timestamp>.md
```

### Memory File Format

All memory files include YAML frontmatter for structured indexing:

```yaml
---
agent: architect
date: "2026-03-25T10:00:00Z"
task: "Brief task description"
tags: [api, validation]
outcome: completed
---
```

### Conventions

- Use the `apex_neural_memory` tool (referenced as `#apex_neural_memory` in chat) for all memory operations — do not use the built-in `vscode/memory`
- Memory files use kebab-case naming: `<context-summary>-<YYYYMMDD-HHMMSS>.md`
- Use lowercase, single-word tags
- Common tags: `api`, `auth`, `database`, `testing`, `security`, `performance`, `refactoring`, `bugfix`, `architecture`, `convention`

## Security

- Never hardcode secrets or credentials
- Use parameterized queries for all database operations
- Validate and sanitize all external inputs
- Review OWASP Top 10 for any security-sensitive changes

## Testing

- All new code must have tests
- Match existing test patterns and frameworks
- Tests must pass before any task is considered complete

## Human-in-the-Loop (HITL)

The workflow supports optional **Human-in-the-Loop checkpoints** where the Orchestrator pauses to get user approval before advancing to the next phase. This is configured in `.github/workflow-config.json`.

### Configuration

The `humanInTheLoop` section in `.github/workflow-config.json` controls HITL behavior:

- **Top-level toggle** (`humanInTheLoop.enabled`): Master switch for all HITL checkpoints. Set to `false` to disable all HITL pauses.
- **Per-agent toggles** (`humanInTheLoop.agents.<agent>.enabled`): Fine-grained control per agent. Both the top-level and the agent-specific flag must be `true` for the checkpoint to activate.

### Currently Supported Checkpoints

| Agent    | When it pauses                              | What the user reviews        |
|----------|---------------------------------------------|------------------------------|
| Planner  | After the Planner produces an implementation plan | The full implementation plan |

### How to Toggle

To disable HITL entirely, set the top-level flag to `false`:
```json
{ "humanInTheLoop": { "enabled": false, ... } }
```

To disable HITL only for the Planner while keeping the system ready for future agents:
```json
{ "humanInTheLoop": { "enabled": true, "agents": { "planner": { "enabled": false } } } }
```

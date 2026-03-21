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

- **Session memory** (`/memories/session/`): Used by the workflow agents to pass structured artifacts between phases (plans, architecture decisions, implementation logs, test results)
- **Repository memory** (`/memories/repo/`): Store codebase conventions discovered during analysis
- **Persistent memory** (`.github/memory/`): File-based, version-controlled memory that accumulates across conversations. Base context in `base/`, per-agent memories in `<agent-name>/` folders, shared cross-agent knowledge in `shared/`.
- **User memory** (`/memories/`): Store personal preferences and cross-project patterns

### Memory System Features

- **Auto-capture**: Memories are automatically generated on SubagentStop via hooks. Agents should enrich the auto-captured file before finishing.
- **YAML frontmatter**: All memory files use structured frontmatter (agent, date, task, tags, outcome, etc.) for programmatic indexing.
- **Searchable index**: `.github/memory/index.json` is rebuilt on session start — use it for efficient memory lookup by agent, tag, or file.
- **Memory health**: `.github/memory/memory-health.json` tracks per-agent file counts, staleness, and compaction needs.
- **Conflict detection**: Memories with `conflicts_with` frontmatter are surfaced at session start for resolution.
- **Pruning**: Memories older than 90 days are auto-archived. Unenriched auto-captures are compacted after 7 days.
- **Shared memory**: Cross-cutting discoveries are promoted to `.github/memory/shared/` by the Orchestrator.
- **Conversation replay**: Use `continues` frontmatter to chain related sessions. Set `conversation_type: digest` for summaries.
- **Memory → Skills**: Run `.github/scripts/memory-to-skill.sh` to analyze accumulated patterns for skill enrichment.

## Security

- Never hardcode secrets or credentials
- Use parameterized queries for all database operations
- Validate and sanitize all external inputs
- Review OWASP Top 10 for any security-sensitive changes

## Testing

- All new code must have tests
- Match existing test patterns and frameworks
- Tests must pass before any task is considered complete

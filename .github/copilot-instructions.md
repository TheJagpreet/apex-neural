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
- **User memory** (`/memories/`): Store personal preferences and cross-project patterns

## Security

- Never hardcode secrets or credentials
- Use parameterized queries for all database operations
- Validate and sanitize all external inputs
- Review OWASP Top 10 for any security-sensitive changes

## Testing

- All new code must have tests
- Match existing test patterns and frameworks
- Tests must pass before any task is considered complete

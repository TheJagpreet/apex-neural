# Agent Memory System

This directory stores persistent memory for the Apex Neural agent ecosystem. Memory files accumulate over time, building a knowledge base that agents can reference for context.

## Structure

```
.github/memory/
├── README.md                   # This file
├── index.json                  # Auto-generated searchable index of all memories
├── memory-health.json          # Auto-generated metrics and health report
├── base/
│   ├── project-context.md      # Core project context (auto-maintained)
│   └── conventions-changelog.md # How project conventions evolved over time
├── shared/                     # Cross-agent shared memories
│   └── <context>-<timestamp>.md
├── orchestrator/
│   ├── TEMPLATE.md             # Role-specific memory template
│   └── <context>-<timestamp>.md
├── planner/
│   ├── TEMPLATE.md
│   └── <context>-<timestamp>.md
├── architect/
│   ├── TEMPLATE.md
│   └── <context>-<timestamp>.md
├── solutioner/
│   ├── TEMPLATE.md
│   └── <context>-<timestamp>.md
└── tester/
    ├── TEMPLATE.md
    └── <context>-<timestamp>.md
```

## Memory Types

### Base Memory (`base/`)
Contains the canonical project context — what this repo is, its architecture, conventions, and capabilities. This file should be updated whenever the project structure changes significantly. Agents load this for foundational context. Also tracks convention evolution in `conventions-changelog.md`.

### Shared Memory (`shared/`)
Cross-cutting concerns that all agents need — recurring patterns, project-wide conventions, and architectural decisions. Memories are "promoted" here by the Orchestrator when a discovery is broadly useful.

- Any agent can **read** shared memories
- Only the **Orchestrator** should **promote** memories to shared (via post-phase evaluation)
- Shared memories should reference their source: `promoted_from: ../architect/api-design-patterns-20260320.md`

### Agent Memory (`<agent-name>/`)
Each agent type has its own memory folder with a role-specific `TEMPLATE.md`. Memories are created automatically on subagent stop (via hooks) and capture decisions, patterns discovered, recurring issues, and lessons learned.

## YAML Frontmatter Schema

All memory files MUST include structured YAML frontmatter. This enables programmatic indexing, filtering, and search.

```yaml
---
agent: architect                          # Agent that created this memory
date: "2026-03-21T18:39:00Z"             # ISO 8601 timestamp (UTC)
task: "Validated REST endpoint plan"      # Brief description of the task
tags: [api, validation, rest]             # Categorization tags for lookup
related_files:                            # Files this memory relates to
  - src/routes/users.ts
  - src/middleware/validate.ts
outcome: approved                         # Result: approved, rejected, completed, failed, partial
confidence: high                          # Self-assessed confidence: high, medium, low
supersedes: null                          # Path to older memory this replaces (or null)
conflicts_with: null                      # Path to contradicting memory (or null) — triggers conflict resolution
continues: null                           # Path to previous conversation memory (for replay chains)
promoted_from: null                       # If in shared/, path to the original agent memory
conversation_type: task                   # task, review, investigation, digest
---
```

### Required Fields
- `agent`, `date`, `task`, `tags`, `outcome`

### Optional Fields
- `related_files`, `confidence`, `supersedes`, `conflicts_with`, `continues`, `promoted_from`, `conversation_type`

### Tag Conventions
- Use lowercase, single-word tags
- Common tags: `api`, `auth`, `database`, `testing`, `security`, `performance`, `refactoring`, `bugfix`, `architecture`, `convention`
- Agent-specific tags are fine (e.g., `flaky-test`, `tech-debt`, `estimation`)

## File Naming Convention

Agent memory files follow this pattern:

```
<context-summary>-<YYYYMMDD-HHMMSS>.md
```

**Examples:**
- `added-rest-endpoint-validation-20260321-183000.md`
- `refactored-auth-module-20260322-100000.md`
- `fixed-race-condition-db-pool-20260323-140000.md`

**Rules:**
- Use kebab-case for the context summary
- Keep the summary under 50 characters
- Include the full timestamp (UTC) for chronological ordering
- One memory file per significant conversation or task

## Memory File Body Template

After the YAML frontmatter, the body follows role-specific templates (see `TEMPLATE.md` in each agent folder). The generic structure is:

```markdown
---
(YAML frontmatter — see schema above)
---

# <Title>

## Context
<What prompted this work>

## Decisions Made
- <Key decision 1 and rationale>
- <Key decision 2 and rationale>

## Patterns Discovered
- <Any codebase patterns identified>

## Outcome
<What was the result>

## Lessons / Notes
- <Anything worth remembering for future tasks>
```

## Cross-Agent Memory Sharing Protocol

### How Memories Get Shared

1. **Automatic**: The Orchestrator evaluates subagent outputs after each phase. If a discovery is broadly useful, it promotes the memory to `shared/`.
2. **References**: Memory files can reference other memories: `See also: ../architect/api-design-patterns-20260320.md`
3. **Promotion criteria**: A memory should be promoted to shared if it:
   - Establishes or changes a project-wide convention
   - Discovers a pattern that multiple agents need to know
   - Documents an architectural decision affecting the whole system

### Reading Shared Memories
All agents should check `shared/` for relevant context before starting a task, in addition to their own folder.

## Memory Lifecycle

### Auto-Capture
Memories are automatically generated when a subagent stops (via the `memory-capture.sh` hook). The hook extracts key decisions from the agent's output and writes a memory file with proper frontmatter.

### Indexing
On session start, `rebuild-memory-index.sh` scans all memory folders and builds `index.json` — a searchable catalog with metadata (agent, date, tags, summary, file path).

### Pruning & Compaction
On session start, `prune-memory.sh` manages memory lifecycle:
- **TTL pruning**: Memories older than 90 days are archived to `<agent>/archive/`
- **Compaction**: Related memories (same tags, same month) can be merged into digest files
- **Relevance tracking**: The index tracks reference counts; never-referenced memories are candidates for archival

### Conflict Detection
`detect-memory-conflicts.sh` scans for memories with `conflicts_with` frontmatter and surfaces unresolved conflicts at session start.

### Metrics
`memory-health.sh` generates `memory-health.json` with per-agent file counts, growth rates, staleness indicators, and compaction triggers.

## Conversation Replay

For multi-session continuity, memory files support replay chains:
- Set `conversation_type: digest` for condensed conversation summaries
- Use `continues: <path-to-previous-memory>` to chain related conversations
- On new sessions about the same topic, the session-init hook pre-loads the relevant digest chain

## Usage by Agents

- **On session start**: `session-init.sh` auto-loads project context, recent memory digest, and relevant file-specific memories
- **Before a task**: Check agent memory folder + `shared/` for related past work (use `index.json` for efficient lookup)
- **After a task**: Memory is auto-captured by the `memory-capture.sh` hook on SubagentStop
- **On pattern discovery**: Update `base/project-context.md` if it affects project-level conventions
- **On convention change**: Log the change in `base/conventions-changelog.md`

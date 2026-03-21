# Conventions Changelog

> Tracks how project conventions have evolved over time. Updated whenever a convention is established, changed, or deprecated.

## Format

Each entry follows:
```
### YYYY-MM-DD — [Convention Name]
- **Change**: What changed
- **Reason**: Why it changed
- **Previous**: What it was before (or "New" for first-time conventions)
- **Memory**: Link to the memory file that prompted this change
```

---

## Entries

### 2026-03-21 — Memory System with YAML Frontmatter
- **Change**: All memory files must include structured YAML frontmatter with required fields (agent, date, task, tags, outcome)
- **Reason**: Enables programmatic indexing, search, filtering, and conflict detection
- **Previous**: Loose markdown template with inline metadata
- **Memory**: `.github/memory/orchestrator/bootstrapped-memory-system-20260321-183900.md`

### 2026-03-21 — Cross-Agent Memory Sharing Protocol
- **Change**: Added `shared/` directory for cross-cutting memories. Orchestrator promotes broadly useful discoveries.
- **Reason**: Breaks agent memory silos; enables knowledge reuse across all roles
- **Previous**: Each agent had isolated memory folders with no sharing mechanism
- **Memory**: `.github/memory/shared/README.md`

### 2026-03-21 — Automatic Memory Capture
- **Change**: Memories are auto-generated on SubagentStop via `memory-capture.sh` hook
- **Reason**: Removes manual burden of memory creation, ensuring consistent capture
- **Previous**: Manual memory file creation by agents after task completion
- **Memory**: `.github/scripts/hooks/memory-capture.sh`

### 2026-03-21 — Memory-Aware Session Initialization
- **Change**: `session-init.sh` now loads project context summary, recent memory digest, and rebuilds the memory index on session start
- **Reason**: Agents get immediate context without manually browsing memory folders
- **Previous**: Session init only detected project type and checked for resume state
- **Memory**: `.github/scripts/hooks/session-init.sh`

---
agent: orchestrator
date: "2026-03-21T18:39:00Z"
task: "Set up persistent memory management system for the agent ecosystem"
tags: [memory, infrastructure, bootstrap]
related_files:
  - .github/memory/README.md
  - .github/memory/base/project-context.md
  - .github/scripts/hooks/session-init.sh
outcome: completed
confidence: high
supersedes: null
conflicts_with: null
continues: null
conversation_type: task
---

# Bootstrapped Memory Management System

## Context
The Apex Neural repo needed a way to persist knowledge across agent conversations. Previously, all context was ephemeral — lost between sessions. The memory system was designed to accumulate learnings over time within `.github/memory/`.

## Decisions Made
- Memory lives in `.github/memory/` to keep everything consolidated under `.github/`
- Base memory (`base/project-context.md`) holds canonical project context, loaded on every session
- Per-agent folders allow agents to build specialized knowledge over time
- File naming uses `<context-summary>-<YYYYMMDD-HHMMSS>.md` for chronological ordering
- Moved `scripts/` into `.github/scripts/` to consolidate all agent infrastructure under `.github/`

## Patterns Discovered
- The repo is purely an agent ecosystem definition — no application source code
- All hook paths are relative to workspace root (e.g., `./.github/scripts/hooks/`)
- VS Code Copilot's `vscode/memory` tool handles session memory; this file-based system complements it with persistent, version-controlled memory

## Outcome
- Created `.github/memory/` with `base/`, `orchestrator/`, `planner/`, `architect/`, `solutioner/`, `tester/` subdirectories
- Wrote `project-context.md` as the foundational base memory
- Established naming conventions and file templates via `README.md`
- Moved `scripts/` to `.github/scripts/` and updated all references

## Lessons / Notes
- Keep base memory updated when project structure changes
- Agent memories should capture decisions and rationale, not just actions
- This memory system is file-based and version-controlled — it travels with the repo

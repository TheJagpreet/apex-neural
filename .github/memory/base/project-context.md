# Apex Neural — Project Context

> Auto-generated base memory file. This captures the project's purpose, architecture, and conventions for agent context loading.

## Overview

**Apex Neural** is a deterministic, multi-phase coding agent workflow built on VS Code's Copilot agent infrastructure. It prevents context loss, hallucination, and scope drift by enforcing structured phases with memory handoffs, hooks for enforcement, and context-isolated subagents.

This is **not a traditional software project** — it is an agent ecosystem definition. The repository contains no application source code; it defines agents, skills, hooks, and tooling that run inside VS Code Copilot.

## Architecture

The system uses an **Orchestrator → Subagent** pattern with four sequential phases:

1. **Planning** (Planner) — Read-only analysis producing a structured implementation plan
2. **Architecture** (Architect) — Read-only design validation and pattern enforcement
3. **Solutioning** (Solutioner) — Full edit access for code implementation
4. **Testing** (Tester) — Edit + run access for writing and executing tests

### Key Design Principles

- **Context isolation**: Each subagent receives only the previous phase's output, preventing context overflow
- **Phase gates**: Stop hooks verify required outputs before allowing phase completion
- **Tool restrictions**: Planner/Architect are read-only; Solutioner can edit; Tester can edit + run
- **Iteration limits**: Max 3 plan-architect loops, max 5 solution-test loops
- **Memory handoffs**: Structured artifacts (plans, decisions, logs, results) pass between phases via session memory

## Agents

| Agent | Role | Tools | Invocable |
|-------|------|-------|-----------|
| **Orchestrator** | Coordinates all phases, never writes code | agent, memory, read, search | Yes (primary entry point) |
| **Planner** | Produces structured implementation plans | read-only (readFile, search, codebase, problems) | Yes |
| **Architect** | Validates plans against codebase patterns | read-only (readFile, search, codebase, usages) | Yes |
| **Solutioner** | Implements code following approved plans | full edit (edit, create, terminal) | Yes |
| **Tester** | Writes/runs tests, validates implementation | edit + run (edit, terminal, testFailure) | Yes |

## Skills

- **codebase-analysis** — Systematic codebase exploration: project identification, pattern recognition, dependency analysis
- **implementation-patterns** — Security-first patterns, error handling, clean code principles
- **test-strategy** — Test pyramid, AAA pattern, coverage targets, failure analysis

## Hooks

| Hook | Script | Purpose |
|------|--------|---------|
| PreToolUse | `pre-tool-guard.sh` | Blocks dangerous terminal commands and hook self-modification |
| PostToolUse | `post-edit-lint.sh` | Runs linter/formatter after file edits (supports JS/TS, Python, Go) |
| SessionStart | `session-init.sh` | Memory-aware init: loads project context, recent memory digest, runs pruning, indexing, health checks, and conflict detection |
| SubagentStart | `subagent-tracker.sh` | Audit trail logging + phase-specific context injection |
| SubagentStop | `subagent-tracker.sh` | Audit trail logging |
| SubagentStop | `memory-capture.sh` | Auto-generates memory files with YAML frontmatter on subagent completion |
| Stop | `phase-gate.sh` | Validates required phase outputs before allowing completion |

## Memory System

### Persistent Memory (`.github/memory/`)
File-based, version-controlled memory with structured YAML frontmatter. Auto-indexed, pruned, and health-checked on each session start.

| Folder | Purpose |
|--------|---------|
| `base/` | Project context + conventions changelog |
| `shared/` | Cross-agent knowledge (promoted by Orchestrator) |
| `<agent>/` | Per-agent memories with role-specific templates |
| `index.json` | Searchable catalog of all memory entries |
| `memory-health.json` | Per-agent metrics, staleness, compaction triggers |

### Memory Lifecycle
- **Auto-capture**: SubagentStop hook generates memory files automatically
- **Indexing**: Rebuilt on session start (`rebuild-memory-index.sh`)
- **Pruning**: 90-day TTL archival + 7-day compaction of unenriched auto-captures (`prune-memory.sh`)
- **Conflict detection**: Scans `conflicts_with` frontmatter and tag-based heuristics (`detect-memory-conflicts.sh`)
- **Health monitoring**: Per-agent file counts, staleness, growth (`memory-health.sh`)
- **Skill enrichment**: Manual pipeline to distill patterns into skills (`memory-to-skill.sh`)

### Session Memory Artifacts

| Phase | Artifact | Path |
|-------|----------|------|
| Planning | Structured plan | `/memories/session/current-plan.md` |
| Architecture | Design review & decisions | `/memories/session/architecture-decision.md` |
| Solutioning | Implementation log | `/memories/session/implementation-log.md` |
| Testing | Test results & verdict | `/memories/session/test-results.md` |

## Conventions

- **Workflow**: All non-trivial tasks flow through Planning → Architecture → Solutioning → Testing
- **Memory paths**: Session memory at `/memories/session/`, repo memory at `/memories/repo/`, persistent memory at `.github/memory/`
- **Error handling**: Explicit — never silently swallow exceptions
- **Code style**: Follow existing patterns; no new patterns without Architect approval
- **Security**: No hardcoded secrets; parameterized queries; validate/sanitize external inputs

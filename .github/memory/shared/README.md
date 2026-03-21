---
agent: shared
date: "2026-03-21T18:55:00Z"
task: "Established cross-agent memory sharing protocol"
tags: [memory, protocol, shared]
related_files: [.github/memory/README.md]
outcome: completed
confidence: high
supersedes: null
conflicts_with: null
continues: null
promoted_from: null
conversation_type: task
---

# Shared Memory — Cross-Agent Knowledge Base

This folder contains memories that are relevant across all agent roles. Memories are "promoted" here from individual agent folders when they contain broadly useful knowledge.

## Promotion Criteria

A memory should be promoted to shared if it:
- Establishes or modifies a **project-wide convention**
- Documents a **pattern that multiple agents need** (e.g., "all API endpoints use X middleware")
- Records an **architectural decision** affecting the whole system
- Captures a **recurring issue** that any agent might encounter

## How to Promote

The Orchestrator evaluates subagent outputs after each phase. To promote a memory:
1. Copy the relevant content to a new file in `shared/`
2. Add `promoted_from: <original-path>` to the frontmatter
3. Update the original memory's body with: `Promoted to shared: ../shared/<filename>`

## Reading Shared Memories

All agents should check this folder (or use `index.json` filtered by `agent: shared`) before starting a task.

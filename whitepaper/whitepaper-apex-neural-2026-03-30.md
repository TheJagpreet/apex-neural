# Apex Neural: A Deterministic Multi-Agent Coding Workflow for VS Code

**Structured AI-Assisted Software Development Through Phase-Gated Agent Orchestration**

| | |
|---|---|
| **Version** | 1.0 |
| **Date** | March 30, 2026 |
| **Author** | Jagpreet Singh Sasan |
| **Organization** | TheJagpreet / Apex Neural Project |
| **License** | MIT |
| **Classification** | Public |

---

## Executive Summary

Large language models have transformed software development, yet their adoption in professional workflows remains constrained by three persistent failure modes: context loss across long interactions, hallucinated code that passes superficial review, and scope drift that turns focused tasks into sprawling, unplanned refactors. These problems intensify as task complexity grows, making LLM-assisted development unreliable for precisely the scenarios where it would deliver the most value.

**Apex Neural** addresses these failures by imposing a deterministic, phase-gated workflow on top of VS Code's GitHub Copilot Chat agent infrastructure. Rather than allowing a single LLM session to handle everything from planning through implementation, Apex Neural decomposes every coding task into four strictly ordered phases --- Planning, Architecture, Solutioning, and Testing --- each executed by a specialized subagent with restricted tools and explicit output requirements. Structured artifacts flow between phases through a persistent, version-controlled memory system, eliminating the information loss that plagues long-running AI sessions.

**Key value propositions:**

- **Context preservation through memory handoffs**: Each phase produces structured markdown artifacts that are explicitly passed to the next phase, preventing the information decay that occurs in monolithic LLM conversations.
- **Hallucination reduction via tool restriction**: Read-only agents (Planner, Architect) cannot modify code; the implementation agent follows an approved, architect-validated plan rather than improvising.
- **Scope control through phase gates**: Lifecycle hooks verify that required outputs exist before any phase can complete, preventing silent failures and unauthorized phase transitions.
- **Cross-platform reliability**: All hooks ship with both PowerShell and bash implementations, dispatched at runtime by a Node.js runner, ensuring consistent behavior on Windows, Linux, and macOS.
- **Native VS Code integration**: Apex Neural installs as a VS Code Copilot agent plugin or via a setup script, requiring no external infrastructure beyond VS Code 1.100+ with GitHub Copilot.

This whitepaper is intended for software engineers, engineering managers, and DevOps practitioners evaluating structured approaches to AI-assisted development. Readers familiar with VS Code's Copilot agent infrastructure will find the most immediate value in Sections 6--8. Those seeking industry context should begin with Sections 4--5.

---

## Table of Contents

1. [Title Page](#apex-neural-a-deterministic-multi-agent-coding-workflow-for-vs-code)
2. [Executive Summary](#executive-summary)
3. [Table of Contents](#table-of-contents)
4. [Introduction](#introduction)
5. [Problem Statement](#problem-statement)
6. [Solution Overview](#solution-overview)
7. [Technical Architecture](#technical-architecture)
8. [Implementation Deep-Dive](#implementation-deep-dive)
9. [Use Cases and Applications](#use-cases-and-applications)
10. [Comparative Analysis](#comparative-analysis)
11. [Performance and Benchmarks](#performance-and-benchmarks)
12. [Security and Compliance](#security-and-compliance)
13. [Roadmap and Future Work](#roadmap-and-future-work)
14. [Conclusion](#conclusion)
15. [References](#references)
16. [Appendices](#appendices)

---

## Introduction

The software development industry is undergoing a fundamental shift in how code is authored, reviewed, and maintained. The global AI in software development market, valued at approximately USD 674 million in 2024, is projected to reach USD 15.7 billion by 2033 at a compound annual growth rate of 42.3% [1]. Development teams report 15%+ velocity gains from AI tool adoption across the software development lifecycle, and the jump from $550 million to $4 billion in 2025 reflects a capability inflection point where models can now interpret entire codebases and execute multi-step tasks [2].

This growth has been accompanied by a parallel evolution in tooling. GitHub Copilot transitioned from a code completion tool to a fully agentic development partner in 2025, and VS Code 1.109 (January 2026) was described by Microsoft as "the home for multi-agent development" [3]. Agent plugins, custom agent profiles, and multi-agent orchestration are now first-class features of the VS Code ecosystem [4]. Gartner reported a 1,445% surge in multi-agent system inquiries from Q1 2024 to Q2 2025 [5], signaling broad industry interest in coordinated AI workflows.

Yet adoption is not without friction. A 2025 industry survey found that 45% of developers who experimented with agent frameworks like LangChain never deployed them to production [6]. The gap between prototype and production-grade agent systems persists because most frameworks focus on the mechanics of agent coordination --- message passing, state management, tool routing --- without addressing the software engineering concerns that matter in practice: reproducibility, auditability, and controlled scope.

Apex Neural occupies this gap. It is not a general-purpose agent framework; it is a purpose-built workflow layer for VS Code that brings the rigor of a CI/CD pipeline to LLM-assisted coding. This document describes the system's design, implementation, and positioning within the broader landscape of AI-assisted development tools.

**How to read this paper:** Sections 4--5 establish the problem context and are useful for readers evaluating whether Apex Neural addresses their pain points. Sections 6--8 provide the technical substance and are most relevant to engineers considering adoption. Sections 9--13 cover practical applications, comparisons, and the project's trajectory.

---

## Problem Statement

### The Three Failure Modes of LLM-Assisted Development

Large language models operating within coding assistants suffer from three interrelated problems that become increasingly severe as task complexity grows.

#### 1. Context Loss

LLM conversations are bounded by context windows. As an agentic workflow accumulates history --- gathered information, intermediate reasoning, tool call results --- the accumulated context can become distracting rather than helpful [7]. Research on long-context failure modes identifies "context distraction," where the model over-focuses on accumulated context and neglects its trained capabilities, and "context poisoning," where misinformation in earlier turns propagates through subsequent reasoning, often requiring extensive effort to undo [7].

In practice, this manifests as a coding assistant that performs well on a five-minute task but degrades on a thirty-minute task. The model forgets constraints established earlier in the conversation, re-reads files it has already analyzed, or produces output that contradicts its own prior decisions. For non-trivial feature work --- the kind that involves multiple files, cross-cutting concerns, and careful sequencing --- this degradation is the norm rather than the exception.

#### 2. Hallucination

AI hallucinations in coding tools occur because models generate outputs based on statistical likelihoods rather than deterministic logic [8]. A model can produce syntactically valid code that references nonexistent APIs, invents configuration options, or implements logic that sounds plausible but is functionally incorrect. Amazon Web Services documented that automated reasoning checks can deliver up to 99% verification accuracy for hallucination detection, but such checks require explicit integration into the development workflow [9].

The risk is particularly acute when a single agent session handles both design and implementation. Without an independent validation step, hallucinated design decisions propagate directly into code. The developer reviewing the output must catch both the design error and the implementation error simultaneously --- a task that becomes harder as the volume of AI-generated code increases.

#### 3. Scope Drift

Scope drift occurs when an AI assistant, given a focused task, expands its changes beyond the intended scope. A request to "add input validation to the user registration endpoint" might result in the assistant also refactoring the authentication middleware, updating unrelated test files, and adding a logging framework it decided was needed. Each individual change might be reasonable in isolation, but collectively they create a pull request that is difficult to review, hard to roll back, and potentially introduces regressions in unrelated subsystems.

Scope drift is a natural consequence of the generative model's optimization function: it maximizes the appearance of helpfulness. Without explicit constraints, the model will keep "improving" code until it reaches a token limit or is stopped by the user.

### Who Is Affected

These problems affect every team using LLM-assisted development tools, but the impact scales with team size and codebase complexity. Solo developers can compensate with manual oversight; teams of ten or more cannot practically review every AI-generated change at the token level. Organizations with compliance requirements (SOC2, HIPAA, GDPR) face additional risk, since hallucinated code may introduce security vulnerabilities that pass superficial review.

### Why Existing Approaches Fall Short

Current approaches to mitigating these failures include:

- **Prompt engineering**: Effective for simple tasks but cannot enforce structural guarantees across multi-step workflows. Prompts are suggestions, not constraints.
- **Context window management**: Techniques like RAG (Retrieval-Augmented Generation) and context pruning help with information retrieval but do not address scope control or hallucination in code generation.
- **General-purpose agent frameworks** (LangChain, CrewAI, AutoGen): These provide agent coordination primitives but require significant integration work to function within a developer's existing IDE workflow. They operate outside the editor, creating a split-attention problem.
- **Single-agent coding tools** (Copilot Chat, Cursor, Claude Code): Powerful for interactive coding but operate as monolithic sessions without phase separation, tool restriction, or enforced output validation.

None of these approaches combine IDE-native execution, phase-gated workflows, tool-level access control, and persistent artifact management into a single, installable system.

> **Key Takeaway:** The three failure modes --- context loss, hallucination, and scope drift --- are not independent bugs to be patched individually. They are emergent properties of running a generative model in an unconstrained, long-running session. Solving them requires structural intervention at the workflow level, not better prompting.

---

## Solution Overview

Apex Neural introduces a deterministic, multi-phase workflow that wraps VS Code's Copilot Chat agent infrastructure. The core mechanism is simple: decompose every coding task into four phases, execute each phase in an isolated subagent with restricted tools, and enforce structured handoffs between phases through a persistent memory system.

### Core Principles

1. **Phase isolation**: Each phase runs in a separate subagent context. The Planner cannot see the Tester's history; the Solutioner cannot see the raw user conversation. Each agent receives only the artifacts from the preceding phase, preventing context overflow and cross-phase contamination.

2. **Tool restriction by role**: The Planner and Architect are read-only agents --- they can explore the codebase but cannot modify files. The Solutioner can edit code but must follow an approved plan. The Tester can edit test files and execute commands. These restrictions are enforced at the agent configuration level.

3. **Structured artifact handoffs**: Each phase produces a structured markdown document (plan, architecture decision, implementation log, test report) with a defined schema. These artifacts are saved to the workspace's `.github/memory/` directory, making them inspectable, diffable, and version-controlled alongside the code.

4. **Phase gates**: Lifecycle hooks validate that required artifacts were produced before a phase can complete. A Planner that tries to finish without saving a plan, or a Tester that stops without recording test results, will be prompted to complete its obligations.

5. **Deterministic coordination**: The Orchestrator agent manages the workflow. It never writes code. It delegates to subagents, manages memory handoffs, enforces iteration limits (max 3 plan-architect cycles, max 5 solution-test cycles), and escalates to the human developer when convergence fails.

### The Four-Phase Pipeline

```
User Request
    |
    v
[Orchestrator] --- coordinates, never codes
    |
    +---> Phase 1: PLANNER (read-only)
    |         Produces: current-plan-<timestamp>.md
    |
    +---> Phase 2: ARCHITECT (read-only)
    |         Produces: architecture-decision-<timestamp>.md
    |         May loop back to Planner (max 3 iterations)
    |
    +---> Phase 3: SOLUTIONER (full edit)
    |         Produces: implementation-log-<timestamp>.md
    |
    +---> Phase 4: TESTER (edit + run)
              Produces: test-results-<timestamp>.md
              May loop back to Solutioner (max 5 iterations)
```

### Key Differentiators

| Differentiator | Apex Neural | Typical AI Coding Tool |
|---|---|---|
| **Phase separation** | Four distinct phases with isolated contexts | Single monolithic session |
| **Tool access control** | Role-based (read-only, edit, edit+run) | All tools available to all sessions |
| **Artifact persistence** | Version-controlled markdown in `.github/memory/` | Ephemeral conversation history |
| **Phase validation** | Lifecycle hooks enforce output requirements | No structural validation |
| **Iteration limits** | Configurable caps prevent infinite loops | No built-in loop detection |
| **Installation** | VS Code plugin or setup script; no external infra | Often requires external servers or APIs |

### Conceptual Architecture

The system operates entirely within VS Code's extension and agent infrastructure. No external servers, databases, or API keys beyond GitHub Copilot are required. The memory system uses the local filesystem (`.github/memory/`), hooks execute as local shell scripts dispatched by a Node.js runner, and agent definitions are markdown files read by VS Code's Copilot Chat subsystem.

> **Key Takeaway:** Apex Neural does not replace the AI model; it constrains how the model is used. By decomposing tasks into phases with explicit inputs, restricted tools, and validated outputs, it converts an inherently probabilistic process into a structured, auditable workflow.

---

## Technical Architecture

### Component Overview

Apex Neural consists of five major subsystems:

1. **Agent Definitions** (`.github/agents/*.agent.md`): Six markdown files that define agent roles, tool access, handoff configurations, and lifecycle hooks.
2. **Memory System** (`extensions/apex-neural-memory/`): A VS Code extension that provides the `apex_neural_memory` Language Model Tool for storing, recalling, and listing workspace-local memories.
3. **Hook System** (`.github/scripts/hooks/`): Cross-platform lifecycle hooks (PowerShell + bash) dispatched by a Node.js runner.
4. **Skills** (`.github/skills/`): Auto-loading knowledge modules that provide domain-specific guidance.
5. **Setup Infrastructure** (`scripts/setup.js`, `plugin.json`, `hooks.json`): Installation and configuration tooling.

### Agent Architecture

Each agent is defined as a markdown file with YAML frontmatter specifying its name, description, available tools, sub-agents, handoff configurations, and lifecycle hooks. VS Code's Copilot Chat reads these definitions and registers the agents as selectable participants in the chat interface.

#### Agent Inventory

| Agent | Phase | Tool Access | Can Edit Code | Key Output |
|---|---|---|---|---|
| **Orchestrator** | Coordinator | `agent`, `apex_neural_memory`, `readFile`, `search`, `codebase`, `fetch` | No | Workflow coordination |
| **Planner** | 1 | `readFile`, `search`, `codebase`, `problems`, `apex_neural_memory`, `usages`, `fetch` | No | Implementation plan |
| **Architect** | 2 | `readFile`, `search`, `codebase`, `problems`, `apex_neural_memory`, `usages`, `fetch` | No | Architecture decision |
| **Solutioner** | 3 | `readFile`, `search`, `edit`, `apex_neural_memory`, `problems`, `runInTerminal` | Yes | Implementation log |
| **Tester** | 4 | `readFile`, `search`, `edit`, `apex_neural_memory`, `problems`, `runInTerminal`, `testFailure` | Yes (tests) | Test report |
| **Maintenance** | On-demand | `runInTerminal`, `getTerminalOutput`, `apex_neural_memory`, `readFile` | No | Health reports |

The tool restriction model is the primary enforcement mechanism against hallucination and scope drift. A Planner agent that lacks the `edit` tool literally cannot modify source code, regardless of what it decides to do. This is a hard constraint, not a prompt-based suggestion.

#### Handoff Configuration

The Orchestrator declares named handoffs to each subagent:

```yaml
handoffs:
  - label: "Quick Plan"
    agent: Planner
    prompt: "Create a plan for the task described above."
    send: false
  - label: "Direct to Architect"
    agent: Architect
    prompt: "Analyze the architecture for the task described above."
    send: false
```

The `send: false` parameter means these are proposal-based handoffs: the Orchestrator prepares the handoff, then confirms before dispatching. This gives the coordinator an opportunity to inject context from the memory system before the subagent begins work.

#### Iteration Control

Two feedback loops operate within the pipeline:

- **Plan-Architect Loop** (max 3 iterations): If the Architect issues a `NEEDS_REVISION` verdict, the Orchestrator sends feedback to the Planner for revision. After three iterations without convergence, both versions are presented to the human developer for decision.
- **Solution-Test Loop** (max 5 iterations): If the Tester reports failures, the Solutioner receives the failure analysis and implements fixes. After five iterations, the system escalates with full diagnostics.

These limits prevent the common failure mode where AI agents enter infinite improvement loops, consuming tokens and time without converging on a solution.

### Memory System Architecture

The memory system is implemented as a VS Code extension (`apex-neural-memory`) that registers a Language Model Tool called `apex_neural_memory`. This tool replaces VS Code's built-in `vscode/memory` tool to ensure all memories are workspace-local and version-controlled.

#### Storage Model

Memories are stored as markdown files with YAML frontmatter in `.github/memory/<agent>/`:

```
.github/memory/
├── base/               # Foundational project context
├── orchestrator/       # Orchestrator memories
├── planner/            # Plan artifacts
├── architect/          # Architecture decisions
├── solutioner/         # Implementation logs
├── tester/             # Test reports
└── shared/             # Cross-agent discoveries
```

Each memory file follows a structured format:

```yaml
---
agent: architect
date: "2026-03-25T10:00:00Z"
task: "Reviewed API design patterns"
tags: [api, validation, rest]
outcome: approved
---

# API Design Patterns
Content of the memory...
```

#### Tool Operations

The `apex_neural_memory` tool supports three actions:

| Action | Purpose | Matching Logic |
|---|---|---|
| **store** | Save a new memory with agent scope, task description, tags, content, and outcome | N/A |
| **recall** | Search memories by query | Matches against agent name, task, tags, and content (case-insensitive substring) |
| **list** | List all memories, optionally filtered by agent | Groups by agent, sorted by date descending |

The recall action returns the 10 most recent matches, with content truncated at 500 characters per result. This prevents the memory retrieval itself from overwhelming the receiving agent's context window.

#### Security Measures

The memory tool implements several safety measures in its TypeScript implementation:

- **Path sanitization**: Agent names are lowercased, stripped of non-alphanumeric characters, and truncated to 30 characters to prevent directory traversal attacks.
- **YAML escaping**: Task descriptions and content are escaped before writing to prevent YAML injection.
- **Filename safety**: Filenames are generated via a slugify function that strips special characters, collapses hyphens, and truncates to 50 characters.

### Hook System Architecture

Hooks are lifecycle event handlers that execute shell commands at specific points in the agent workflow. They provide the enforcement layer that transforms guidelines into constraints.

#### Hook Dispatch Flow

All hooks are dispatched through a single Node.js runner (`run-hook.js`) that detects the operating system and executes the appropriate script:

```
run-hook.js <hook-name>
    |
    +-- Windows --> <hook-name>.ps1 (via pwsh or powershell)
    +-- Linux/macOS --> <hook-name>.sh (via sh)
```

The runner reads JSON from stdin (provided by VS Code's hook infrastructure), forwards it to the platform-specific script, and returns the script's JSON output to VS Code. This architecture ensures identical behavior across platforms while allowing each script to use platform-native idioms.

#### Registered Hooks

| Hook | Event | Function |
|---|---|---|
| **pre-tool-guard** | `PreToolUse` | Blocks destructive terminal commands (`rm -rf /`, `DROP TABLE`, `git push --force main`, etc.) and requires manual approval for edits to hook scripts (preventing self-modification) |
| **post-edit-lint** | `PostToolUse` | Runs appropriate linter/formatter after file edits (Prettier for JS/TS, Ruff for Python, gofmt for Go); validates JSON syntax for schedule files |
| **session-init** | `SessionStart` | Detects project type, injects git branch context, checks for previous session state, and reminds agents to use `#apex_neural_memory` |
| **subagent-tracker** | `SubagentStart/Stop` | Logs subagent lifecycle events to `.github/audit/subagent-trace.log` and injects phase-specific context reminders |
| **phase-gate** | `Stop` | Validates that the stopping agent produced its required output artifact before allowing completion |

#### Hook Registration

Hooks are registered at two levels:

1. **Workspace-level** (`.github/hooks/safety-and-tracking.json`): Applied to all agents via VS Code's hook system.
2. **Agent-level** (in the agent's YAML frontmatter): Applied only when that specific agent is active.
3. **Plugin-level** (`hooks.json` at repository root): Uses `${CLAUDE_PLUGIN_ROOT}` tokens for portable path resolution when installed as a VS Code agent plugin.

### Skills Subsystem

Skills are auto-loading knowledge modules that provide domain-specific guidance. They are markdown files in `.github/skills/<skill-name>/SKILL.md` with YAML frontmatter. VS Code loads them into the agent's context when they are relevant to the conversation.

| Skill | Coverage |
|---|---|
| **codebase-analysis** | Project identification, directory mapping, pattern recognition, dependency analysis, build/run discovery |
| **implementation-patterns** | Input validation, injection prevention, authentication patterns, error handling, clean code principles |
| **test-strategy** | Test pyramid prioritization, convention discovery, AAA pattern, edge case checklists, coverage targets |

### Data Flow Diagram

```
User Request
    |
    v
ORCHESTRATOR
    |
    +--- SessionStart hook injects project context
    |
    +--- Recalls relevant memories from .github/memory/
    |
    +--- SubagentStart hook --> injects phase context
    |         |
    |         v
    |    PLANNER (read-only)
    |         |
    |         +--- Reads codebase via search/readFile
    |         +--- Produces current-plan-<ts>.md
    |         +--- Phase-gate hook validates plan exists
    |         |
    |         v
    |    ARCHITECT (read-only)
    |         |
    |         +--- Reads plan + codebase
    |         +--- Verdict: APPROVED / NEEDS_REVISION / BLOCKED
    |         +--- Produces architecture-decision-<ts>.md
    |         +--- If NEEDS_REVISION --> back to Planner (max 3x)
    |         |
    |         v
    |    SOLUTIONER (edit)
    |         |
    |         +--- Reads plan + architecture decision
    |         +--- Implements code changes
    |         +--- Post-edit hooks run linter
    |         +--- Pre-tool guard blocks dangerous commands
    |         +--- Produces implementation-log-<ts>.md
    |         |
    |         v
    |    TESTER (edit + run)
    |         |
    |         +--- Reads plan + implementation log
    |         +--- Writes and runs tests
    |         +--- Verdict: PASS / FAIL / PARTIAL
    |         +--- If FAIL --> back to Solutioner (max 5x)
    |         +--- Produces test-results-<ts>.md
    |
    v
Summary presented to user
```

> **Key Takeaway:** Apex Neural's architecture is layered --- agent definitions provide role separation, the memory system provides persistence, hooks provide enforcement, and skills provide knowledge. Each layer can be customized independently, and the system operates entirely within VS Code's existing infrastructure.

---

## Implementation Deep-Dive

### The Orchestrator's Coordination Protocol

The Orchestrator is the only agent that interacts directly with the user and delegates to subagents. Its coordination logic follows a strict protocol:

1. **Session start**: The `session-init` hook detects the project type (Node.js, Python, Go, Rust), reads the current git branch, checks for existing session state from interrupted workflows, and injects a reminder to use the `apex_neural_memory` tool.

2. **Memory priming**: Before delegating to any subagent, the Orchestrator recalls relevant memories from `.github/memory/shared/` and the target agent's folder. This provides continuity across sessions --- if the Planner discovered an architectural constraint last week, it is surfaced before this week's planning begins.

3. **Context isolation**: Each subagent receives only its task description, the output from the preceding phase, and relevant file paths (not full file contents --- the subagent reads what it needs). This prevents context overflow and ensures each agent starts with a clean, focused context.

4. **Handoff validation**: After each subagent completes, the Orchestrator reads the produced artifact and verifies it against the expected schema before advancing to the next phase.

5. **Discovery promotion**: After each phase, the Orchestrator evaluates whether any subagent discovery should be promoted to `.github/memory/shared/` for cross-agent access. Discoveries that establish project-wide conventions, patterns, or architectural decisions are promoted.

### Pre-Tool Safety Guard

The `pre-tool-guard` hook intercepts every tool invocation before execution. It operates as a pattern-matching firewall:

**Blocked terminal commands** (hard deny):
- Filesystem destruction: `rm -rf /`, `rm -rf ~`, `del /s /q C:\`, `rd /s /q C:\`
- Database destruction: `DROP TABLE`, `DROP DATABASE`, `TRUNCATE TABLE`
- Disk operations: `Format-Volume`, `Clear-Disk`, `format [drive]:`
- Dangerous git operations: `git push --force main`, `git push --force master`, `git reset --hard origin`

**Protected file edits** (require manual approval):
- Any edit targeting `.github/scripts/hooks/` or `.github/hooks/` is flagged for human review, preventing agents from modifying their own safety infrastructure.

The guard returns a JSON response with `permissionDecision: "deny"` for blocked actions and `permissionDecision: "ask"` for protected actions. All other tool invocations pass through with an empty JSON response (implicit allow).

### Post-Edit Linting Pipeline

The `post-edit-lint` hook runs after every file modification, providing immediate feedback to the editing agent:

1. **File type detection**: Extracts the file extension from the edited path.
2. **Linter selection**:
   - JavaScript/TypeScript (`.ts`, `.tsx`, `.js`, `.jsx`, `.mjs`, `.cjs`): Runs Prettier format check
   - Python (`.py`): Runs Ruff linter
   - Go (`.go`): Runs gofmt
3. **Reactive maintenance**: If `.github/schedule.json` is edited, the hook validates JSON syntax and warns if the file is malformed.

Linter feedback is injected into the agent's context as `additionalContext`, allowing the agent to self-correct formatting issues without human intervention.

### Memory Tool Implementation

The `MemoryTool` class (428 lines of TypeScript) implements the VS Code `LanguageModelTool` interface. Key implementation details:

**Store operation:**
1. Sanitizes the agent name (prevents directory traversal)
2. Creates the memory directory if it does not exist (`fs.promises.mkdir` with `recursive: true`)
3. Generates a kebab-case filename from the task description + UTC timestamp
4. Writes YAML frontmatter + markdown content to the file
5. Returns a confirmation with the relative file path

**Recall operation:**
1. Scans all subdirectories of `.github/memory/` (or a single agent directory if filtered)
2. Reads each `.md` file (excluding `TEMPLATE.md` and `README.md`)
3. Parses YAML frontmatter using a custom lightweight parser (no external YAML library dependency)
4. Filters by case-insensitive substring matching against agent, task, tags, and content
5. Returns the 10 most recent matches, sorted by date descending, with content truncated at 500 characters

**Frontmatter parser:** The tool includes a custom YAML frontmatter parser that handles the subset of YAML used by memory files (string values, arrays of strings). This avoids a dependency on a full YAML parsing library while correctly handling quoted values, array syntax, and escaped characters.

### Phase Gate Validation

The `phase-gate` hook runs on the `Stop` event for every agent. Its validation logic is agent-type-specific:

| Agent | Required Output |
|---|---|
| Planner | Plan with: Objective, Acceptance Criteria, Affected Files, Task Breakdown, Risk Assessment, Testing Strategy |
| Architect | Review with: Verdict, Pattern Analysis, Reuse Opportunities, Issues Found |
| Solutioner | Log with: Tasks Completed, Files Changed, Deviations from Plan |
| Tester | Report with: Test Results table, Acceptance Criteria Coverage, Verdict |

The hook does not parse the artifact content --- it injects a reminder into the agent's context listing the required output sections. The agent is expected to self-validate before stopping. If the agent attempts to stop without producing the required output, the context reminder prompts it to complete its obligations.

The hook includes an infinite-loop prevention mechanism: if the `stop_hook_active` flag is set (indicating the hook itself triggered a stop event), the hook passes through without intervention.

### Cross-Platform Hook Dispatch

The `run-hook.js` dispatcher (85 lines) handles cross-platform execution:

1. Reads the hook name from `process.argv[2]`
2. Collects stdin data synchronously (`fs.readFileSync(0, 'utf8')`)
3. On Windows: Checks for `pwsh` (PowerShell Core) availability, falls back to `powershell` (Windows PowerShell), executes the `.ps1` script with `-ExecutionPolicy Bypass`
4. On Linux/macOS: Executes the `.sh` script via `sh`
5. Forwards stdout/stderr from the child process to the parent process
6. Exits with the child process's exit code

This design ensures that hook authors write in their platform's native scripting language while consumers (VS Code, agent definitions) reference a single, OS-independent command.

> **Key Takeaway:** The implementation emphasizes hard constraints over soft suggestions. Tool access is enforced at the agent definition level, destructive operations are blocked at the hook level, and phase completion is validated at the lifecycle event level. The system trusts the LLM's capabilities within its designated scope while preventing it from operating outside that scope.

---

## Use Cases and Applications

### Use Case 1: Multi-File Feature Development

**Scenario:** A developer requests "Add a REST endpoint for user profile updates with input validation, error handling, and database persistence."

**Workflow:**
1. **Planner**: Explores the codebase, identifies the existing endpoint patterns, database access layer, and validation library. Produces a plan with 6 tasks across 4 files, including risk assessment for concurrent update conflicts.
2. **Architect**: Validates the plan against existing patterns, identifies a reusable validation middleware, flags that the database schema migration is missing from the plan.
3. **Planner** (revision): Adds the migration task and updates the task dependency graph.
4. **Architect**: Issues `APPROVED` verdict.
5. **Solutioner**: Implements all 7 tasks in dependency order, producing an implementation log.
6. **Tester**: Writes unit tests for the validation logic, integration tests for the endpoint, and verifies acceptance criteria. All tests pass.

**Outcome:** A reviewable, well-documented feature implementation with full test coverage, produced through a traceable workflow where every decision is recorded in `.github/memory/`.

**Target persona:** Full-stack developers working on established codebases where consistency with existing patterns is critical.

### Use Case 2: Bug Fix with Root Cause Analysis

**Scenario:** A reported bug: "Users intermittently see stale data after profile updates."

**Workflow:**
1. **Planner**: Analyzes the bug report, searches for caching layers, identifies a race condition between the cache invalidation and the database write.
2. **Architect**: Confirms the diagnosis, identifies that the same pattern exists in two other endpoints, recommends a shared fix.
3. **Solutioner**: Implements the cache invalidation ordering fix across all three endpoints.
4. **Tester**: Writes a regression test that simulates concurrent requests and verifies cache consistency.

**Outcome:** The bug is fixed at its root cause rather than symptom-level, and similar bugs in other endpoints are preemptively resolved.

**Target persona:** Backend engineers debugging production issues where the fix scope is unclear at the outset.

### Use Case 3: Onboarding New Team Members

**Scenario:** A new developer joins the team and needs to implement their first feature.

**Workflow:** The developer describes their task to the Orchestrator. The Planner explores the codebase and produces a plan that references existing patterns, naming conventions, and architecture decisions --- effectively teaching the new developer how the codebase works through the plan itself. The Architect validates the plan, catching any deviations from established conventions before code is written. The accumulated memories in `.github/memory/shared/` provide institutional knowledge that persists across sessions.

**Outcome:** The new developer's first PR follows team conventions from the start, reducing review friction and onboarding time.

**Target persona:** Engineering managers concerned about onboarding velocity and codebase consistency.

### Use Case 4: Legacy Code Modification

**Scenario:** A developer needs to modify a module with no tests, complex dependencies, and undocumented behavior.

**Workflow:** The Planner maps the module's dependency graph and identifies the behavioral contracts from usage patterns. The Architect flags the untested state and recommends a "characterization test first" strategy. The Solutioner writes characterization tests before making the change. The Tester validates both the characterization tests and the new behavior.

**Outcome:** The legacy module gains test coverage as a byproduct of the modification, and the change is verifiable against established behavior.

**Target persona:** Teams maintaining legacy codebases where changes carry high regression risk.

### Use Case 5: Cross-Team Workflow Standardization

**Scenario:** An organization with multiple development teams wants consistent AI-assisted development practices.

**Workflow:** Apex Neural is installed as a VS Code agent plugin (`chat.pluginLocations` setting) or via the setup script in each team's workspace. Custom skills are added to `.github/skills/` to encode team-specific patterns. The memory system captures and shares architectural decisions across sessions. The maintenance agent periodically promotes recurring patterns from individual memory stores into shared skills.

**Outcome:** AI-assisted development follows the same structured workflow across all teams, with team-specific customizations encoded in skills and memory rather than tribal knowledge.

**Target persona:** Engineering directors and platform teams responsible for developer tooling standards.

---

## Comparative Analysis

### Feature Comparison

| Capability | Apex Neural | LangChain / LangGraph | CrewAI | AutoGen | GitHub Copilot (native) |
|---|---|---|---|---|---|
| **IDE integration** | Native VS Code plugin | External; requires custom UI | External | External | Native VS Code |
| **Phase separation** | 4 enforced phases | User-defined graph | Role-based crews | Conversation patterns | None (single session) |
| **Tool access control** | Per-agent restriction | Per-node configuration | Per-agent tools | Per-agent tools | All tools available |
| **Artifact persistence** | Version-controlled markdown | In-memory state (configurable) | Crew memory | Conversation history | Ephemeral |
| **Phase validation** | Lifecycle hooks | Custom callbacks | Task delegation | Reply validation | None |
| **Setup complexity** | `node scripts/setup.js` or VS Code plugin install | pip install + application code | pip install + crew definition | pip install + agent code | Pre-installed |
| **External dependencies** | VS Code 1.100+, Node.js 18+, GitHub Copilot | Python runtime, API keys | Python runtime, API keys | Python runtime, API keys | VS Code, GitHub Copilot |
| **Cross-platform hooks** | PowerShell + bash + Node.js dispatch | Python only | Python only | Python only | N/A |
| **Iteration limits** | Configurable (3 plan/arch, 5 sol/test) | Manual implementation | Configurable | Manual implementation | None |
| **Audit trail** | Subagent trace log + memory files | Custom logging | Task logs | Conversation logs | None |

### Where Apex Neural Excels

- **Zero-infrastructure setup**: Operates entirely within VS Code. No external servers, no database, no separate API keys beyond Copilot.
- **Structural enforcement**: Phase gates and tool restrictions are hard constraints, not prompt-based suggestions. A read-only agent cannot edit files regardless of the model's intent.
- **Artifact traceability**: Every decision is recorded in version-controlled markdown, making the AI's reasoning inspectable and diffable through standard git tools.
- **Cross-platform parity**: First-class Windows support through PowerShell hooks, unlike most agent frameworks that assume Unix environments.

### Where Apex Neural Does Not Excel

- **Model flexibility**: Tied to whichever LLM backs VS Code's Copilot Chat. Cannot swap models per-agent or use multiple model providers simultaneously.
- **Scalability**: Designed for individual developers and small teams. Not suited for organization-wide orchestration across hundreds of repositories without additional tooling.
- **Programmatic extensibility**: Configuration is declarative (markdown + JSON). Complex coordination logic beyond the four-phase pipeline requires modifying agent definitions rather than writing code.
- **Non-VS Code environments**: No support for JetBrains, Neovim, Emacs, or web-based IDEs.

### Positioning

Apex Neural is best positioned as a **workflow discipline layer** for teams already using VS Code with GitHub Copilot. It does not compete with general-purpose agent frameworks (LangChain, CrewAI) on flexibility or with foundation model providers on capability. Its value lies in converting the unstructured, probabilistic output of an LLM into a structured, auditable development workflow --- the same value that CI/CD pipelines brought to manual deployment processes.

---

## Performance and Benchmarks

### Planned Evaluation

Apex Neural is currently in active development (v1.0.0) and does not yet have published benchmark data. A formal evaluation is planned with the following methodology:

#### Proposed Metrics

| Metric | Description | Measurement Method |
|---|---|---|
| **Phase completion rate** | Percentage of tasks that successfully traverse all four phases without human intervention | Automated logging via subagent-tracker |
| **Iteration convergence** | Average number of plan-architect and solution-test iterations before convergence | Memory artifact analysis |
| **Hallucination rate** | Percentage of Solutioner outputs that deviate from the approved plan without justification | Manual review of implementation logs vs. plans |
| **Scope adherence** | Percentage of file modifications that appear in the approved plan's "Affected Files" table | Automated diff analysis |
| **Context utilization** | Token count consumed per phase relative to total context window | VS Code telemetry (if available) |
| **Memory recall precision** | Percentage of recalled memories that are relevant to the current task | Manual evaluation of recall results |

#### Proposed Comparison

The evaluation will compare:
1. **Apex Neural (full pipeline)**: All four phases with hooks enabled.
2. **Apex Neural (reduced)**: Orchestrator + Solutioner only (no planning/architecture phase).
3. **Baseline Copilot Chat**: Same tasks executed in a single Copilot Chat session without Apex Neural.

Tasks will be drawn from real-world feature requests and bug fixes in open-source repositories, covering both small (single-file) and large (multi-file, multi-concern) changes.

#### Expected Outcomes

Based on the architectural design and existing research on structured agent workflows, the expected outcomes are:

- Higher phase completion rates for complex tasks (multi-file, cross-cutting) where context management is critical
- Lower hallucination rates due to plan-first, validate-second workflow
- Higher scope adherence due to explicit plan approval before implementation
- Higher total token consumption (the cost of running four agents instead of one) offset by fewer wasted iterations

> **Key Takeaway:** Formal benchmarks are forthcoming. The architectural rationale predicts that the system trades increased token consumption for improved reliability on complex tasks --- a worthwhile trade-off for production-grade development work.

---

## Security and Compliance

### Threat Model

Apex Neural operates within VS Code's existing security perimeter. The primary threat vectors are:

| Threat | Mitigation |
|---|---|
| **Destructive commands via AI agent** | `pre-tool-guard` hook blocks `rm -rf`, `DROP TABLE`, `git push --force main`, and other dangerous patterns before execution |
| **Agent self-modification** | Edits to hook scripts and hook registration files require manual approval via the `pre-tool-guard` hook |
| **Directory traversal via memory system** | Agent names are sanitized (lowercased, non-alphanumeric stripped, truncated to 30 chars) before use in file paths |
| **YAML injection via memory content** | Task descriptions and content are escaped before YAML frontmatter generation |
| **Prompt injection via memory recall** | Memory content is limited to 500 characters per result in recall, reducing the attack surface for injected prompts in stored memories |
| **Credential exposure** | Memories are stored in `.github/memory/`, which should be included in `.gitignore` if the team's workflow involves storing sensitive context; the system itself does not store credentials |

### Code Quality Enforcement

The skill system encodes security-first implementation patterns:

- **Input validation at system boundaries**: The `implementation-patterns` skill instructs agents to validate all inputs at API endpoints, CLI arguments, file reads, and environment variables.
- **Injection prevention**: Agents are guided to use parameterized queries, context-appropriate output escaping, and file path validation.
- **No silent error swallowing**: The implementation patterns skill explicitly prohibits empty catch blocks.

### Compliance Considerations

Apex Neural does not directly address regulatory compliance frameworks (GDPR, SOC2, HIPAA). However, its architecture supports compliance workflows:

- **Audit trail**: All subagent start/stop events are logged with timestamps in `.github/audit/subagent-trace.log`. All phase artifacts are version-controlled.
- **Separation of duties**: The Planner and Architect cannot modify code; the Solutioner and Tester cannot bypass the planning phase. This enforces a form of maker-checker control.
- **Reviewable decisions**: Architecture decisions are stored as structured markdown with explicit rationale, alternatives considered, and trade-offs documented.

### Responsible Use

The pre-tool safety guard is a defense-in-depth measure, not a comprehensive security solution. It blocks known destructive patterns but cannot anticipate all possible harmful commands. Teams deploying Apex Neural in sensitive environments should:

1. Review all hook scripts before installation (the README explicitly notes this)
2. Consider adding organization-specific blocked patterns to `pre-tool-guard.ps1` and `pre-tool-guard.sh`
3. Use `.gitignore` to exclude `.github/memory/` if memories might contain sensitive business logic
4. Enable VS Code's `chat.useCustomAgentHooks` setting explicitly (hooks do not run silently)

---

## Roadmap and Future Work

### Short-Term (0--6 Months)

- **Formal benchmarking**: Execute the evaluation methodology described in Section 11 against open-source repositories and publish results.
- **Memory search improvements**: Replace substring matching with TF-IDF or embedding-based semantic search for the recall operation, improving precision on large memory stores.
- **Maintenance script implementation**: The `schedule.json` currently defines an empty task list. Implement the planned maintenance scripts (memory pruning, index rebuilding, health checks, conflict detection, memory-to-skill promotion).
- **Shell script parity**: Ensure all `.sh` hook implementations have feature parity with their `.ps1` counterparts (currently the PowerShell versions are more mature).

### Mid-Term (6--18 Months)

- **Multi-model agent support**: As VS Code expands multi-agent orchestration (1.109+), explore assigning different LLM models to different phases --- a smaller, faster model for planning, a more capable model for implementation.
- **Team memory sharing**: Extend the memory system to support team-wide shared memories via git remote synchronization, enabling cross-developer knowledge transfer.
- **Custom phase definitions**: Allow teams to define their own phase pipelines beyond the fixed four-phase model --- for example, adding a "Security Review" phase between Architecture and Solutioning.
- **Metrics dashboard**: Build a VS Code webview panel that visualizes workflow metrics: phase completion rates, iteration counts, memory utilization, and convergence trends over time.

### Long-Term Vision

- **CI/CD integration**: Extend the workflow to trigger automated code review and deployment pipelines, connecting Apex Neural's structured output to existing DevOps infrastructure.
- **Cross-IDE support**: Evaluate porting the agent definition format and hook system to JetBrains IDEs and other editors as their agent infrastructures mature.
- **Organizational learning**: Build a feedback loop where successful workflow patterns are automatically extracted from memory and codified into new skills, creating an organization-specific knowledge base that improves over time.

### Open Problems

- **Optimal phase granularity**: Is four phases the right decomposition? Some tasks (trivial bug fixes) may benefit from a two-phase shortcut; others (system redesigns) may need additional phases.
- **Memory pruning policy**: How aggressively should old memories be archived? Aggressive pruning saves context; conservative pruning preserves institutional knowledge.
- **Token economics**: The multi-agent approach consumes more tokens than a single-session approach. Quantifying the ROI (fewer rework iterations, higher first-pass quality) requires production data.

---

## Conclusion

AI-assisted software development is no longer experimental --- it is a mainstream practice reshaping how teams write, review, and maintain code. Yet the fundamental reliability problems of LLM-based coding tools --- context loss, hallucination, and scope drift --- remain unsolved by approaches that treat the AI as a monolithic, unconstrained assistant.

Apex Neural demonstrates that these problems are addressable through architectural intervention. By decomposing tasks into phases with isolated contexts, restricting tool access by role, enforcing structured artifact handoffs through a persistent memory system, and validating phase completion through lifecycle hooks, the system converts an inherently probabilistic process into a structured, auditable workflow. The result is not a smarter AI, but a more disciplined use of the AI we already have.

The project is open-source under the MIT license, operates entirely within VS Code's existing infrastructure, and requires no external servers or API keys beyond GitHub Copilot. It is designed to be adopted incrementally --- teams can start with the setup script or plugin install and customize the agents, skills, and hooks to match their specific workflow requirements.

For teams that have experienced the frustration of AI-generated pull requests that drift from their original scope, or LLM sessions that forget critical constraints established ten minutes earlier, Apex Neural offers a concrete, implementable solution: structure the workflow, restrict the tools, persist the artifacts, and validate the outputs.

**Get started:** [github.com/TheJagpreet/apex-neural](https://github.com/TheJagpreet/apex-neural)

---

## References

[1] Grand View Research. "AI In Software Development Market | Industry Report, 2033." Accessed March 2026. https://www.grandviewresearch.com/industry-analysis/ai-software-development-market-report

[2] Keyhole Software. "Software Development Statistics: 2026 Market Size, Developer Trends & Technology Adoption." Accessed March 2026. https://keyholesoftware.com/software-development-statistics-2026-market-size-developer-trends-technology-adoption/

[3] Visual Studio Code Blog. "Your Home for Multi-Agent Development." February 5, 2026. https://code.visualstudio.com/blogs/2026/02/05/multi-agent-development

[4] Visual Studio Code Documentation. "Agent plugins in VS Code (Preview)." Accessed March 2026. https://code.visualstudio.com/docs/copilot/customization/agent-plugins

[5] Deloitte. "Unlocking exponential value with AI agent orchestration." Technology, Media and Telecom Predictions 2026. https://www.deloitte.com/us/en/insights/industry/technology/technology-media-and-telecom-predictions/2026/ai-agent-orchestration.html

[6] Shakudo. "Top 9 AI Agent Frameworks as of March 2026." Accessed March 2026. https://www.shakudo.io/blog/top-9-ai-agent-frameworks

[7] Breunig, D. "How Long Contexts Fail." June 22, 2025. https://www.dbreunig.com/2025/06/22/how-contexts-fail-and-how-to-fix-them.html

[8] InfoWorld. "How to keep AI hallucinations out of your code." Accessed March 2026. https://www.infoworld.com/article/3822251/how-to-keep-ai-hallucinations-out-of-your-code.html

[9] Amazon Web Services. "Minimize AI hallucinations and deliver up to 99% verification accuracy with Automated Reasoning checks." Accessed March 2026. https://aws.amazon.com/blogs/aws/minimize-ai-hallucinations-and-deliver-up-to-99-verification-accuracy-with-automated-reasoning-checks-now-available/

[10] Visual Studio Magazine. "Hands On with New Multi-Agent Orchestration in VS Code." February 9, 2026. https://visualstudiomagazine.com/articles/2026/02/09/hands-on-with-new-multi-agent-orchestration-in-vs-code.aspx

[11] Visual Studio Code Documentation. "Using agents in Visual Studio Code." Accessed March 2026. https://code.visualstudio.com/docs/copilot/agents/overview

[12] QuantumBlack, AI by McKinsey. "Agentic workflows for software development." Medium, February 2026. https://medium.com/quantumblack/agentic-workflows-for-software-development-dc8e64f4a79d

[13] Osmani, A. "My LLM coding workflow going into 2026." Accessed March 2026. https://addyosmani.com/blog/ai-coding-workflow/

[14] Kubiya. "Top AI Agent Orchestration Frameworks for Developers 2025." Accessed March 2026. https://www.kubiya.ai/blog/ai-agent-orchestration-frameworks

[15] AIMultiple. "LLM Orchestration in 2026: Top 22 frameworks and gateways." Accessed March 2026. https://aimultiple.com/llm-orchestration

[16] Muse, K. "Creating Agent Plugins for VS Code and Copilot CLI." Accessed March 2026. https://www.kenmuse.com/blog/creating-agent-plugins-for-vs-code-and-copilot-cli/

[17] Zhou, Z. et al. "Detecting and Correcting Hallucinations in LLM-Generated Code via Deterministic AST Analysis." arXiv, 2025. https://arxiv.org/html/2601.19106v1

---

## Appendices

### Appendix A: Glossary

| Term | Definition |
|---|---|
| **Agent** | An AI assistant configured with a specific role, tool set, and instructions, defined as a markdown file in `.github/agents/` |
| **Agent Plugin** | A VS Code extension format that bundles agents, skills, hooks, and MCP servers into a single installable package |
| **Artifact** | A structured markdown document produced by a phase agent (plan, architecture decision, implementation log, test report) |
| **Context Isolation** | The practice of providing each subagent only the information it needs, rather than the full conversation history |
| **Copilot Chat** | VS Code's integrated AI chat interface, powered by GitHub Copilot, which serves as the execution environment for Apex Neural agents |
| **Handoff** | The transfer of control from the Orchestrator to a subagent, including task description and relevant context |
| **Hook** | A shell script that executes in response to a lifecycle event (PreToolUse, PostToolUse, SessionStart, SubagentStart, SubagentStop, Stop) |
| **Language Model Tool** | A VS Code API that allows extensions to register tools callable by LLMs during chat interactions |
| **Memory** | A persistent markdown file stored in `.github/memory/` with YAML frontmatter, representing a piece of knowledge or a phase artifact |
| **Orchestrator** | The coordinating agent that manages the four-phase workflow, delegates to subagents, and enforces iteration limits |
| **Phase Gate** | A lifecycle hook that validates a phase's required outputs before allowing the agent to complete |
| **Skill** | An auto-loading knowledge module (markdown file) that provides domain-specific guidance when relevant to the conversation |
| **Subagent** | An agent invoked by the Orchestrator to execute a specific phase of the workflow |

### Appendix B: Tool Set Reference

| Tool Set | Tools | Used By |
|---|---|---|
| **reader** | `codebase`, `search`, `readFile`, `problems`, `usages`, `listDirectory`, `fileSearch` | Planner, Architect |
| **writer** | `editFiles`, `createFile`, `createDirectory` | Solutioner, Tester |
| **runner** | `runInTerminal`, `getTerminalOutput`, `problems` | Solutioner, Tester, Maintenance |
| **workflow** | `runSubagent`, `apex_neural_memory` | Orchestrator |

### Appendix C: Memory File Schema

```yaml
---
agent: string        # Agent name (lowercase, alphanumeric + hyphens)
date: string         # ISO 8601 timestamp (e.g., "2026-03-25T10:00:00Z")
task: string         # Brief task description
tags: string[]       # Categorization tags (e.g., [api, validation])
outcome: string      # One of: completed, approved, rejected, failed, partial, blocked
---

# Markdown Content

Free-form markdown body describing the memory content.
```

### Appendix D: Hook Event JSON Schema

**PreToolUse input:**
```json
{
  "tool_name": "run_in_terminal",
  "tool_input": {
    "command": "npm test"
  },
  "cwd": "/path/to/workspace"
}
```

**PreToolUse deny response:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Blocked by safety guard: command matches dangerous pattern"
  }
}
```

**SessionStart response:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Project: my-app v1.0.0 (Node.js) | Branch: feature/auth | Memory: Use #apex_neural_memory tool for store/recall/list."
  }
}
```

### Appendix E: Installation Quick Reference

**Option 1: VS Code Agent Plugin**
```
1. Ctrl+Shift+P -> "Chat: Install Plugin From Source"
2. Enter: https://github.com/TheJagpreet/apex-neural
3. Enable: "chat.plugins.enabled": true
```

**Option 2: Setup Script**
```bash
git clone https://github.com/TheJagpreet/apex-neural.git
cd apex-neural
node scripts/setup.js
```

**Required VS Code Settings:**
```json
{
  "chat.useCustomAgentHooks": true,
  "chat.agent.thinking.collapsedTools": false,
  "chat.plugins.enabled": true
}
```

# Apex Neural — Agent Ecosystem

A deterministic, multi-phase coding agent workflow built on VS Code's Copilot agent infrastructure. Prevents context loss, hallucination, and scope drift by enforcing structured phases with memory handoffs, hooks for enforcement, and context-isolated subagents.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER REQUEST                             │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                     🎯 ORCHESTRATOR                              │
│  Coordinates all phases. Never writes code directly.            │
│  Tools: agent, memory, read, search, codebase                   │
│  Hooks: SessionStart, SubagentStart/Stop, Stop                  │
└──────┬──────────┬───────────┬───────────┬───────────────────────┘
       │          │           │           │
  Phase 1    Phase 2     Phase 3     Phase 4
       │          │           │           │
       ▼          ▼           ▼           ▼
┌──────────┐ ┌──────────┐ ┌───────────┐ ┌──────────┐
│ PLANNER  │ │ARCHITECT │ │SOLUTIONER │ │ TESTER   │
│          │ │          │ │           │ │          │
│ Read-only│ │ Read-only│ │ Full edit │ │Edit+Run  │
│ Analyze  │ │ Validate │ │ Implement │ │ Verify   │
│ Plan     │ │ Design   │ │ Build     │ │ Test     │
│user-invoc│ │user-invoc│ │user-invoc │ │user-invoc│
└─────┬────┘ └────┬─────┘ └─────┬─────┘ └────┬─────┘
      │           │             │             │
      ▼           ▼             ▼             ▼
  ┌────────────────────────────────────────────────┐
  │          SESSION MEMORY (handoff state)         │
  │  current-plan.md → architecture-decision.md →   │
  │  implementation-log.md → test-results.md        │
  └────────────────────────────────────────────────┘
```

## How It Works

### Phase 1: Planning (Planner subagent)
- **Tools**: read-only (`read`, `search`, `codebase`, `problems`)
- **Input**: User's task description
- **Output**: Structured plan with tasks, affected files, risks, acceptance criteria
- **Memory**: Saves plan to `/memories/session/current-plan.md`

### Phase 2: Architecture (Architect subagent)
- **Tools**: read-only (`read`, `search`, `codebase`, `usages`)
- **Input**: Plan from Phase 1
- **Output**: Architecture review with verdict (APPROVED / NEEDS_REVISION / BLOCKED)
- **Memory**: Saves decision to `/memories/session/architecture-decision.md`
- **Loop**: If NEEDS_REVISION → back to Planner (max 3 iterations)

### Phase 3: Solutioning (Solutioner subagent)
- **Tools**: full edit (`edit`, `create_file`, `replace_string_in_file`, `run_in_terminal`)
- **Input**: Approved plan + architecture decisions
- **Output**: Implemented code changes + implementation report
- **Memory**: Saves log to `/memories/session/implementation-log.md`
- **Hook**: Post-edit linting runs automatically after every file change

### Phase 4: Testing (Tester subagent)
- **Tools**: edit + run (`edit`, `create_file`, `run_in_terminal`, `problems`)
- **Input**: Implementation log + changed files
- **Output**: Test report with pass/fail, coverage, verdict
- **Memory**: Saves results to `/memories/session/test-results.md`
- **Loop**: If FAIL → back to Solutioner (max 5 iterations per test)

## Determinism Mechanisms

| Mechanism | Purpose | How |
|-----------|---------|-----|
| **Subagent context isolation** | Prevents context overflow | Each subagent gets only the previous phase's output |
| **Session memory handoffs** | Structured state between phases | Plans, decisions, logs saved as markdown artifacts |
| **Agent-scoped hooks** | Enforce phase gates | Stop hooks verify required outputs before allowing phase completion |
| **Tool restrictions** | Prevent unintended actions | Planner/Architect are read-only; Solutioner can edit; Tester can edit+run |
| **Pre-tool safety guard** | Block dangerous operations | Hook blocks destructive terminal commands and hook self-modification |
| **Post-edit linting** | Catch errors early | Lint/format hooks run after every file edit |
| **Subagent tracking** | Audit trail | All subagent start/stop events logged with timestamps |
| **Iteration limits** | Prevent infinite loops | Max 3 plan-architect iterations, max 5 solution-test iterations |
| **Phase-specific prompts** | Role enforcement | SubagentStart hook injects phase-specific role reminders |

## File Structure

```
.github/
├── agents/
│   ├── orchestrator.agent.md    # Main coordinator
│   ├── planner.agent.md         # Planning agent (user-invocable)
│   ├── architect.agent.md       # Architecture agent (user-invocable)
│   ├── solutioner.agent.md      # Implementation agent (user-invocable)
│   └── tester.agent.md          # Testing agent (user-invocable)
├── hooks/
│   └── safety-and-tracking.json # Workspace-level hooks
├── skills/
│   ├── codebase-analysis/
│   │   └── SKILL.md             # Codebase analysis patterns
│   ├── implementation-patterns/
│   │   └── SKILL.md             # Implementation best practices
│   └── test-strategy/
│       └── SKILL.md             # Testing strategy & patterns
├── copilot-instructions.md      # Global project instructions
└── tool-sets.json               # Grouped tool collections

scripts/
└── hooks/
    ├── session-init.sh          # Injects project context on session start
    ├── post-edit-lint.sh        # Runs linter after file edits
    ├── pre-tool-guard.sh        # Blocks dangerous operations
    ├── subagent-tracker.sh      # Logs subagent lifecycle events
    └── phase-gate.sh            # Validates phase outputs before completion
```

## Usage

### Starting the Orchestrator
1. Open VS Code Chat
2. Select **Orchestrator** from the agents dropdown
3. Describe your task

Example:
```
Add a REST endpoint for user profile updates with input validation and error handling
```

The Orchestrator will automatically:
1. Invoke the Planner to create a structured plan
2. Invoke the Architect to validate the plan
3. Invoke the Solutioner to implement the changes
4. Invoke the Tester to verify everything works

### Using Individual Agents
All agents are user-invocable — you can select them directly from the VS Code Chat agent dropdown or use the Orchestrator's handoff buttons:
- **Quick Plan**: Jump directly to the Planner
- **Direct to Architect**: Skip planning if you already have a design question
- **Direct to Testing**: Jump to testing for existing code

For full workflow enforcement (phase gates, hooks, iteration limits), always prefer the **Orchestrator**.

### VS Code Settings

Enable these settings for best experience:

```json
{
  "github.copilot.chat.tools.memory.enabled": true,
  "chat.useCustomAgentHooks": true,
  "chat.agent.thinking.collapsedTools": false
}
```

## Customization

### Adding a New Subagent
1. Create a new `.agent.md` file in `.github/agents/`
2. Set `user-invocable: false` if the agent should only be called via `runSubagent`, or `user-invocable: true` to allow direct selection from the agent dropdown
3. Add the agent name to the Orchestrator's `agents` list
4. Add a phase in the Orchestrator's instructions

### Adding a New Skill
1. Create a directory in `.github/skills/`
2. Add a `SKILL.md` with YAML frontmatter (`name`, `description`)
3. The skill auto-loads when relevant to the conversation

### Adding a New Hook
1. Add a script to `scripts/hooks/`
2. Make it executable: `chmod +x scripts/hooks/your-hook.sh`
3. Register it in `.github/hooks/safety-and-tracking.json` or in an agent's `hooks` frontmatter

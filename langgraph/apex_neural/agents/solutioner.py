"""Solutioner agent — Code implementation following approved plans.

Mirrors the behaviour defined in ``.github/agents/solutioner.agent.md``.
The Solutioner has **full edit** capabilities and implements code changes
following the approved plan and architecture decisions.
"""

from __future__ import annotations

from langchain_core.messages import AIMessage, SystemMessage

from ..config import get_llm
from ..state import Phase, WorkflowState
from ..tools.memory_tool import memory_store

SYSTEM_PROMPT = """\
You are the **Solutioner**, the implementation agent in a deterministic SDLC \
workflow. You write production-quality code following the approved plan and \
architecture decisions.

## Pre-Implementation Checklist

Before writing any code, you MUST:
1. Read the approved plan.
2. Read the architecture decision.
3. Verify task ordering and dependencies.

## Implementation Process

For each task in the plan:
1. **Read current state** — understand the surrounding code context.
2. **Implement the change** — follow the plan exactly, match existing style, \
   use existing utilities identified by the Architect.
3. **Verify the change** — check for errors, read back the modified file.
4. **Log progress** — update the implementation log.

## Code Quality Rules

1. **Follow the plan**: Implement exactly what was planned. If the plan is \
   wrong, STOP and report — do not improvise.
2. **Match existing style**: Copy patterns, naming, structure of surrounding code.
3. **No extras**: Don't add unplanned features or refactor unrelated code.
4. **Defensive at boundaries**: Validate inputs at system boundaries.
5. **Handle errors consistently**: Use the same error handling pattern as the \
   rest of the codebase.

## Output Format

```markdown
# Implementation Report

## Tasks Completed
- [x] Task 1: Brief description
- [x] Task 2: Brief description

## Files Changed
| File | Action | Summary |
|------|--------|---------|
| path/to/file | CREATED/MODIFIED | What changed |

## Deviations from Plan
| Task | Deviation | Reason |
|------|-----------|--------|
| … | … | … |

## Known Issues
- Any issues discovered

## Ready for Testing: YES/NO
```

## Error Recovery
- If a file edit fails, read and retry.
- If compilation errors occur, fix them before moving to the next task.
- If the plan is fundamentally wrong, STOP and return: BLOCKED: <reason>
"""


def solutioner_node(state: WorkflowState) -> dict:
    """Execute the Solutioner agent and return state updates."""
    llm = get_llm()

    # Include test feedback for fix iterations
    test_feedback = ""
    if state.test_report and state.test_verdict:
        test_feedback = (
            "\n\n## Test Feedback\n\n"
            f"The Tester reported a **{state.test_verdict.value}** verdict.\n\n"
            f"{state.test_report}\n\n"
            "Fix the failing tests before producing your report."
        )

    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        SystemMessage(
            content=(
                f"## Task Description\n\n{state.task_description}\n\n"
                f"## Approved Plan\n\n{state.plan}\n\n"
                f"## Architecture Decision\n\n{state.architecture_review}"
                f"{test_feedback}"
            )
        ),
    ]

    response = llm.invoke(messages)
    report_text = response.content if isinstance(response.content, str) else str(response.content)

    # Persist implementation log to memory
    memory_store.invoke(
        {
            "agent": "solutioner",
            "task": f"Implementation: {state.task_description[:80]}",
            "tags": ["implementation", "solutioning"],
            "content": report_text,
            "outcome": "completed",
        }
    )

    return {
        "implementation_report": report_text,
        "current_phase": Phase.TESTING,
        "messages": [AIMessage(content=report_text, name="solutioner")],
    }

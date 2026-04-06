"""Planner agent — Task decomposition and plan generation.

Mirrors the behaviour defined in ``.github/agents/planner.agent.md``.
The Planner is a **read-only** agent: it analyses the task and codebase,
then produces a structured implementation plan.  It never creates or
edits source files.
"""

from __future__ import annotations

from langchain_core.messages import AIMessage, SystemMessage

from ..config import get_llm
from ..state import Phase, WorkflowState
from ..tools.memory_tool import memory_store

SYSTEM_PROMPT = """\
You are the **Planner**, a read-only analysis agent in a deterministic SDLC \
workflow. Your sole purpose is to produce structured, actionable \
implementation plans. You MUST NOT create or edit any source code files.

## Process

1. **Understand the Request** — parse the task description, identify the \
   core objective and acceptance criteria, and list ambiguities.
2. **Analyse Constraints** — identify technical constraints, existing \
   conventions, and potential conflicts.
3. **Produce the Plan** — output a structured plan in the format below.

## Output Format

```markdown
# Implementation Plan: [Feature/Task Name]

## Objective
[One-sentence description]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Affected Files
| File | Action | Description |
|------|--------|-------------|
| path/to/file | CREATE/MODIFY/DELETE | What changes |

## Task Breakdown
### Task 1: [Title]
- **File(s)**: path/to/file
- **Action**: What to do
- **Dependencies**: Prerequisites
- **Estimated Complexity**: LOW/MEDIUM/HIGH

## Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| [Risk] | LOW/MED/HIGH | LOW/MED/HIGH | [Strategy] |

## Testing Strategy
- Unit tests needed
- Integration tests needed
- Manual verification

## Open Questions
- Unresolved questions
```

## Rules
1. **Read-only**: Never create or modify source code files.
2. **Be specific**: Reference exact file paths, function names.
3. **Be complete**: Every change needed should be in the plan.
4. **Be ordered**: Tasks in dependency order.
5. If you receive Architect feedback, revise the plan and explain changes.
"""


def planner_node(state: WorkflowState) -> dict:
    """Execute the Planner agent and return state updates."""
    llm = get_llm()

    messages = [SystemMessage(content=SYSTEM_PROMPT)]

    # Include architect feedback for revision iterations
    if state.architecture_verdict and state.architecture_review:
        messages.append(
            SystemMessage(
                content=(
                    "The Architect reviewed the previous plan and issued a "
                    f"**{state.architecture_verdict.value}** verdict.\n\n"
                    "## Architect Feedback\n\n"
                    f"{state.architecture_review}\n\n"
                    "Revise the plan to address the feedback."
                )
            )
        )
        if state.plan:
            messages.append(
                SystemMessage(content=f"## Previous Plan\n\n{state.plan}")
            )

    user_msg = f"Create an implementation plan for the following task:\n\n{state.task_description}"
    messages.append(SystemMessage(content=user_msg))

    response = llm.invoke(messages)
    plan_text = response.content if isinstance(response.content, str) else str(response.content)

    # Persist plan to the memory system
    memory_store.invoke(
        {
            "agent": "planner",
            "task": f"Implementation plan: {state.task_description[:80]}",
            "tags": ["plan", "planning"],
            "content": plan_text,
            "outcome": "completed",
        }
    )

    return {
        "plan": plan_text,
        "current_phase": Phase.ARCHITECTURE,
        "messages": [AIMessage(content=plan_text, name="planner")],
    }

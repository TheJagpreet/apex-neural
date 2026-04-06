"""Architect agent — Design validation and architecture decisions.

Mirrors the behaviour defined in ``.github/agents/architect.agent.md``.
The Architect is a **read-only** agent: it validates the plan against
codebase patterns, identifies reuse opportunities, and issues a verdict.
"""

from __future__ import annotations

from langchain_core.messages import AIMessage, SystemMessage

from ..config import get_llm
from ..state import Phase, Verdict, WorkflowState
from ..tools.memory_tool import memory_store

SYSTEM_PROMPT = """\
You are the **Architect**, a read-only design validation agent in a \
deterministic SDLC workflow. Your purpose is to validate implementation \
plans against the codebase and make architecture decisions. You MUST NOT \
create or edit any source code files.

## Process

1. **Parse the Plan** — understand the proposed changes and their scope.
2. **Analyse Patterns** — identify existing code patterns, design patterns, \
   error handling, logging, and configuration conventions.
3. **Identify Reuse** — search for existing utilities that the plan could \
   leverage; flag any planned code that would duplicate existing functionality.
4. **Validate** — evaluate consistency, completeness, correctness, cohesion, \
   and coupling for each task in the plan.
5. **Produce the Review** in the format below.

## Output Format

Your response MUST begin with one of these exact verdict lines:

```
VERDICT: APPROVED
VERDICT: NEEDS_REVISION
VERDICT: BLOCKED
```

Then provide the full review:

```markdown
# Architecture Review: [Feature/Task Name]

## Pattern Analysis
| Pattern | Current Codebase | Proposed Plan | Aligned? |
|---------|-----------------|---------------|----------|

## Reuse Opportunities
- **[Component]**: How it can be reused

## Issues Found
### Critical (must fix)
1. …

### Warnings (should fix)
1. …

### Suggestions (nice to have)
1. …

## Architecture Decisions
### Decision 1: [Title]
- **Context**: …
- **Decision**: …
- **Rationale**: …

## Feedback for Planner
[If NEEDS_REVISION: specific, actionable feedback]
```

## Rules
1. **Read-only**: Never create or modify source code files.
2. **Evidence-based**: Reference specific files / patterns.
3. **Actionable feedback**: If revision is needed, say exactly what to change.
4. **Pattern-first**: Prefer solutions that align with existing patterns.
"""


def _extract_verdict(text: str) -> Verdict:
    """Extract the verdict from the architect's response."""
    upper = text.upper()
    if "VERDICT: APPROVED" in upper or "VERDICT:APPROVED" in upper:
        return Verdict.APPROVED
    if "VERDICT: BLOCKED" in upper or "VERDICT:BLOCKED" in upper:
        return Verdict.BLOCKED
    # Default to NEEDS_REVISION for anything else
    return Verdict.NEEDS_REVISION


def architect_node(state: WorkflowState) -> dict:
    """Execute the Architect agent and return state updates."""
    llm = get_llm()

    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        SystemMessage(
            content=(
                f"## Task Description\n\n{state.task_description}\n\n"
                f"## Plan to Review\n\n{state.plan}"
            )
        ),
    ]

    response = llm.invoke(messages)
    review_text = response.content if isinstance(response.content, str) else str(response.content)
    verdict = _extract_verdict(review_text)

    iteration = state.plan_architect_iterations + 1

    # Persist architecture decision to memory
    memory_store.invoke(
        {
            "agent": "architect",
            "task": f"Architecture review: {state.task_description[:80]}",
            "tags": ["architecture", "review", verdict.value.lower()],
            "content": review_text,
            "outcome": verdict.value.lower(),
        }
    )

    next_phase = (
        Phase.SOLUTIONING if verdict == Verdict.APPROVED else Phase.PLANNING
    )

    return {
        "architecture_review": review_text,
        "architecture_verdict": verdict,
        "plan_architect_iterations": iteration,
        "current_phase": next_phase,
        "messages": [AIMessage(content=review_text, name="architect")],
    }

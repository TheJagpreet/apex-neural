"""Orchestrator — LangGraph StateGraph implementing the deterministic SDLC workflow.

This is the central coordinator that replicates the behaviour of
``.github/agents/orchestrator.agent.md`` using LangGraph's ``StateGraph``.

Workflow phases:
    Planning → Architecture → Solutioning → Testing

Iteration limits:
    Plan ↔ Architect: max 3
    Solution ↔ Test:  max 5
"""

from __future__ import annotations

from langchain_core.messages import AIMessage
from langgraph.graph import END, StateGraph

from .agents.architect import architect_node
from .agents.planner import planner_node
from .agents.solutioner import solutioner_node
from .agents.tester import tester_node
from .state import Phase, Verdict, WorkflowState

# ── Iteration limits ────────────────────────────────────────────────────

MAX_PLAN_ARCHITECT_ITERATIONS = 3
MAX_SOLUTION_TEST_ITERATIONS = 5
MAX_SUMMARY_LENGTH = 500


# ── Routing functions ───────────────────────────────────────────────────


def route_after_architect(state: WorkflowState) -> str:
    """Decide the next node after the Architect phase.

    - APPROVED → proceed to solutioner
    - NEEDS_REVISION and under limit → back to planner
    - NEEDS_REVISION and over limit → escalate (complete with warning)
    - BLOCKED → fail
    """
    if state.architecture_verdict == Verdict.APPROVED:
        return "solutioner"

    if state.architecture_verdict == Verdict.BLOCKED:
        return "escalate"

    # NEEDS_REVISION
    if state.plan_architect_iterations >= MAX_PLAN_ARCHITECT_ITERATIONS:
        return "escalate"

    return "planner"


def route_after_tester(state: WorkflowState) -> str:
    """Decide the next node after the Tester phase.

    - PASS → complete
    - FAIL/PARTIAL and under limit → back to solutioner
    - FAIL/PARTIAL and over limit → escalate
    """
    if state.test_verdict == Verdict.PASS:
        return "complete"

    if state.solution_test_iterations >= MAX_SOLUTION_TEST_ITERATIONS:
        return "escalate"

    return "solutioner"


# ── Terminal nodes ──────────────────────────────────────────────────────


def complete_node(state: WorkflowState) -> dict:
    """Produce the final success summary."""
    summary = (
        "# Workflow Complete ✅\n\n"
        f"## Task\n{state.task_description}\n\n"
        f"## Plan\n{state.plan[:MAX_SUMMARY_LENGTH]}{'…' if len(state.plan) > MAX_SUMMARY_LENGTH else ''}\n\n"
        f"## Architecture Verdict\n{state.architecture_verdict.value if state.architecture_verdict else 'N/A'}\n\n"
        f"## Test Verdict\n{state.test_verdict.value if state.test_verdict else 'N/A'}\n\n"
        f"## Iterations\n"
        f"- Plan ↔ Architect: {state.plan_architect_iterations}\n"
        f"- Solution ↔ Test: {state.solution_test_iterations}\n"
    )
    return {
        "final_summary": summary,
        "current_phase": Phase.COMPLETED,
        "messages": [AIMessage(content=summary, name="orchestrator")],
    }


def escalate_node(state: WorkflowState) -> dict:
    """Produce a failure / escalation summary."""
    reason = ""
    if state.architecture_verdict == Verdict.BLOCKED:
        reason = f"Architect BLOCKED the plan:\n\n{state.architecture_review}"
    elif state.plan_architect_iterations >= MAX_PLAN_ARCHITECT_ITERATIONS:
        reason = (
            f"Plan ↔ Architect loop did not converge after "
            f"{MAX_PLAN_ARCHITECT_ITERATIONS} iterations."
        )
    elif state.solution_test_iterations >= MAX_SOLUTION_TEST_ITERATIONS:
        reason = (
            f"Solution ↔ Test loop did not converge after "
            f"{MAX_SOLUTION_TEST_ITERATIONS} iterations."
        )
    else:
        reason = "Unknown escalation reason."

    summary = (
        "# Workflow Escalated ⚠️\n\n"
        f"## Task\n{state.task_description}\n\n"
        f"## Reason\n{reason}\n\n"
        "Manual intervention required."
    )
    return {
        "final_summary": summary,
        "current_phase": Phase.FAILED,
        "error": reason,
        "messages": [AIMessage(content=summary, name="orchestrator")],
    }


# ── Graph construction ──────────────────────────────────────────────────


def build_graph() -> StateGraph:
    """Build and compile the SDLC orchestrator graph.

    Returns a compiled LangGraph ``StateGraph`` ready for invocation.

    Graph topology::

        START → planner → architect ──(APPROVED)──→ solutioner → tester ──(PASS)──→ complete → END
                   ▲          │                          ▲          │
                   └──(NEEDS_REVISION)                   └──(FAIL)──┘
                              │
                        (BLOCKED / over limit) → escalate → END
    """
    graph = StateGraph(WorkflowState)

    # ── Add nodes ───────────────────────────────────────────────────
    graph.add_node("planner", planner_node)
    graph.add_node("architect", architect_node)
    graph.add_node("solutioner", solutioner_node)
    graph.add_node("tester", tester_node)
    graph.add_node("complete", complete_node)
    graph.add_node("escalate", escalate_node)

    # ── Set entry point ─────────────────────────────────────────────
    graph.set_entry_point("planner")

    # ── Edges ───────────────────────────────────────────────────────
    graph.add_edge("planner", "architect")

    graph.add_conditional_edges(
        "architect",
        route_after_architect,
        {
            "solutioner": "solutioner",
            "planner": "planner",
            "escalate": "escalate",
        },
    )

    graph.add_edge("solutioner", "tester")

    graph.add_conditional_edges(
        "tester",
        route_after_tester,
        {
            "complete": "complete",
            "solutioner": "solutioner",
            "escalate": "escalate",
        },
    )

    graph.add_edge("complete", END)
    graph.add_edge("escalate", END)

    return graph.compile()

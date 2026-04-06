"""Workflow state schema shared by all agents and the orchestrator graph."""

from __future__ import annotations

from enum import Enum
from typing import Annotated

from pydantic import BaseModel, Field
from langgraph.graph.message import add_messages
from langchain_core.messages import BaseMessage


class Phase(str, Enum):
    """Deterministic SDLC workflow phases."""

    PLANNING = "planning"
    ARCHITECTURE = "architecture"
    SOLUTIONING = "solutioning"
    TESTING = "testing"
    COMPLETED = "completed"
    FAILED = "failed"


class Verdict(str, Enum):
    """Phase outcome verdicts."""

    APPROVED = "APPROVED"
    NEEDS_REVISION = "NEEDS_REVISION"
    BLOCKED = "BLOCKED"
    PASS = "PASS"
    FAIL = "FAIL"
    PARTIAL = "PARTIAL"


class WorkflowState(BaseModel):
    """Central state object flowing through the LangGraph orchestrator.

    Every node reads from and writes to this shared state.  The
    ``messages`` field uses LangGraph's ``add_messages`` reducer so that
    each node can *append* messages rather than overwrite.
    """

    # ── User request ────────────────────────────────────────────────
    task_description: str = Field(
        default="",
        description="The original user request / task description.",
    )

    # ── Current phase ───────────────────────────────────────────────
    current_phase: Phase = Field(
        default=Phase.PLANNING,
        description="Current workflow phase.",
    )

    # ── Phase artifacts (filled by each agent) ──────────────────────
    plan: str = Field(
        default="",
        description="Structured implementation plan produced by the Planner.",
    )
    architecture_review: str = Field(
        default="",
        description="Architecture review produced by the Architect.",
    )
    architecture_verdict: Verdict | None = Field(
        default=None,
        description="Architect's verdict on the plan.",
    )
    implementation_report: str = Field(
        default="",
        description="Implementation report produced by the Solutioner.",
    )
    test_report: str = Field(
        default="",
        description="Test report produced by the Tester.",
    )
    test_verdict: Verdict | None = Field(
        default=None,
        description="Tester's verdict on the implementation.",
    )

    # ── Iteration counters (enforced limits) ────────────────────────
    plan_architect_iterations: int = Field(
        default=0,
        description="Number of Plan ↔ Architect iterations so far.",
    )
    solution_test_iterations: int = Field(
        default=0,
        description="Number of Solution ↔ Test iterations so far.",
    )

    # ── Conversation history (uses LangGraph add_messages reducer) ──
    messages: Annotated[list[BaseMessage], add_messages] = Field(
        default_factory=list,
    )

    # ── Final summary ───────────────────────────────────────────────
    final_summary: str = Field(
        default="",
        description="Final output summary presented to the user.",
    )

    # ── Error tracking ──────────────────────────────────────────────
    error: str = Field(
        default="",
        description="Error message if the workflow fails.",
    )

    model_config = {"arbitrary_types_allowed": True}

"""Tests for the workflow state and orchestrator graph structure."""

from __future__ import annotations

import pytest

from langgraph.state import Phase, Verdict, WorkflowState
from langgraph.orchestrator import (
    MAX_PLAN_ARCHITECT_ITERATIONS,
    MAX_SOLUTION_TEST_ITERATIONS,
    build_graph,
    route_after_architect,
    route_after_tester,
)


# ── State tests ─────────────────────────────────────────────────────────


class TestWorkflowState:
    def test_default_state(self):
        state = WorkflowState()
        assert state.current_phase == Phase.PLANNING
        assert state.task_description == ""
        assert state.plan == ""
        assert state.plan_architect_iterations == 0
        assert state.solution_test_iterations == 0

    def test_phase_enum(self):
        assert Phase.PLANNING.value == "planning"
        assert Phase.ARCHITECTURE.value == "architecture"
        assert Phase.SOLUTIONING.value == "solutioning"
        assert Phase.TESTING.value == "testing"
        assert Phase.COMPLETED.value == "completed"
        assert Phase.FAILED.value == "failed"

    def test_verdict_enum(self):
        assert Verdict.APPROVED.value == "APPROVED"
        assert Verdict.NEEDS_REVISION.value == "NEEDS_REVISION"
        assert Verdict.BLOCKED.value == "BLOCKED"
        assert Verdict.PASS.value == "PASS"
        assert Verdict.FAIL.value == "FAIL"
        assert Verdict.PARTIAL.value == "PARTIAL"


# ── Routing tests ───────────────────────────────────────────────────────


class TestRouteAfterArchitect:
    def test_approved_goes_to_solutioner(self):
        state = WorkflowState(
            architecture_verdict=Verdict.APPROVED,
            plan_architect_iterations=1,
        )
        assert route_after_architect(state) == "solutioner"

    def test_blocked_goes_to_escalate(self):
        state = WorkflowState(
            architecture_verdict=Verdict.BLOCKED,
            plan_architect_iterations=1,
        )
        assert route_after_architect(state) == "escalate"

    def test_needs_revision_under_limit_goes_to_planner(self):
        state = WorkflowState(
            architecture_verdict=Verdict.NEEDS_REVISION,
            plan_architect_iterations=1,
        )
        assert route_after_architect(state) == "planner"

    def test_needs_revision_at_limit_goes_to_escalate(self):
        state = WorkflowState(
            architecture_verdict=Verdict.NEEDS_REVISION,
            plan_architect_iterations=MAX_PLAN_ARCHITECT_ITERATIONS,
        )
        assert route_after_architect(state) == "escalate"


class TestRouteAfterTester:
    def test_pass_goes_to_complete(self):
        state = WorkflowState(
            test_verdict=Verdict.PASS,
            solution_test_iterations=1,
        )
        assert route_after_tester(state) == "complete"

    def test_fail_under_limit_goes_to_solutioner(self):
        state = WorkflowState(
            test_verdict=Verdict.FAIL,
            solution_test_iterations=1,
        )
        assert route_after_tester(state) == "solutioner"

    def test_fail_at_limit_goes_to_escalate(self):
        state = WorkflowState(
            test_verdict=Verdict.FAIL,
            solution_test_iterations=MAX_SOLUTION_TEST_ITERATIONS,
        )
        assert route_after_tester(state) == "escalate"

    def test_partial_under_limit_goes_to_solutioner(self):
        state = WorkflowState(
            test_verdict=Verdict.PARTIAL,
            solution_test_iterations=2,
        )
        assert route_after_tester(state) == "solutioner"


# ── Graph construction tests ────────────────────────────────────────────


class TestBuildGraph:
    def test_graph_compiles(self):
        graph = build_graph()
        assert graph is not None

    def test_graph_has_expected_nodes(self):
        graph = build_graph()
        # The compiled graph should have nodes for each agent
        node_names = set(graph.get_graph().nodes.keys())
        expected = {"planner", "architect", "solutioner", "tester", "complete", "escalate"}
        assert expected.issubset(node_names)

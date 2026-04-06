"""CLI entry point for the Apex Neural LangGraph SDLC workflow.

Usage::

    # Run a task through the full SDLC pipeline
    python -m langgraph.main "Add a REST endpoint for user profiles"

    # Run maintenance only
    python -m langgraph.main --maintenance

Environment variables::

    OLLAMA_MODEL        Model name (default: llama3.1)
    OLLAMA_BASE_URL     Ollama server URL (default: http://localhost:11434)
    OLLAMA_TEMPERATURE  Sampling temperature (default: 0.2)
    APEX_MEMORY_ROOT    Memory storage directory (default: .github/memory)
"""

from __future__ import annotations

import argparse
import sys

from .agents.maintenance import maintenance_node
from .orchestrator import build_graph
from .state import WorkflowState


def run_workflow(task: str) -> WorkflowState:
    """Execute the full SDLC workflow for a given task description.

    Args:
        task: Natural-language description of the task.

    Returns:
        The final ``WorkflowState`` after the workflow completes.
    """
    graph = build_graph()
    initial_state = WorkflowState(task_description=task)
    result = graph.invoke(initial_state)
    return result


def run_maintenance() -> None:
    """Run the maintenance agent standalone."""
    result = maintenance_node()
    for msg in result.get("messages", []):
        print(msg.content)


def main() -> None:
    """Parse CLI arguments and dispatch to the appropriate workflow."""
    parser = argparse.ArgumentParser(
        prog="apex-neural",
        description="Apex Neural — Deterministic SDLC agent orchestration via LangGraph",
    )
    parser.add_argument(
        "task",
        nargs="?",
        help="Task description for the full SDLC workflow",
    )
    parser.add_argument(
        "--maintenance",
        action="store_true",
        help="Run the maintenance agent instead of the full workflow",
    )

    args = parser.parse_args()

    if args.maintenance:
        run_maintenance()
        return

    if not args.task:
        parser.error("Please provide a task description or use --maintenance")

    result = run_workflow(args.task)

    # Print the final summary
    if isinstance(result, dict):
        print(result.get("final_summary", "No summary produced."))
    else:
        print(result.final_summary or "No summary produced.")


if __name__ == "__main__":
    main()

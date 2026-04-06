"""Maintenance agent — Scheduled task runner.

Mirrors the behaviour defined in ``.github/agents/maintenance.agent.md``.
Runs memory maintenance tasks: pruning, index rebuilding, health checks,
conflict detection, and skill enrichment.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

from langchain_core.messages import AIMessage, SystemMessage

from ..config import get_llm
from ..tools.memory_tool import _get_memory_root, memory_list

SYSTEM_PROMPT = """\
You are the **Maintenance** agent, responsible for running and reporting on \
system maintenance tasks for the Apex Neural agent ecosystem.

## Available Maintenance Tasks

| Task | Default Interval |
|------|-----------------|
| prune-memory | 24h |
| rebuild-index | 1h |
| memory-health | 4h |
| detect-conflicts | 4h |
| memory-to-skill | 7d |

## Process

1. **Assess** — read schedule and last-run timestamps, determine overdue tasks.
2. **Execute** — run overdue tasks.
3. **Report** — summarize results.

## Output Format

```markdown
# Maintenance Report

## Tasks Executed
- [task-name]: [status] — [brief summary]

## Memory Health
- Status: healthy/degraded/empty
- Active memories: N

## Next Scheduled Runs
| Task | Last Run | Interval | Next Due |
|------|----------|----------|----------|
```

## Rules
- Do NOT modify source code.
- Always update schedule-state after running a task.
- Report errors clearly.
"""


def _read_schedule_state() -> dict:
    """Read the maintenance schedule state file."""
    state_path = _get_memory_root() / "schedule-state.json"
    if state_path.exists():
        try:
            return json.loads(state_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def _write_schedule_state(state: dict) -> None:
    """Write the maintenance schedule state file."""
    state_path = _get_memory_root() / "schedule-state.json"
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(
        json.dumps(state, indent=2),
        encoding="utf-8",
    )


def maintenance_node(state: dict | None = None) -> dict:
    """Execute the Maintenance agent.

    This node can be invoked standalone (outside the main SDLC graph).
    It checks the memory system health and produces a report.
    """
    llm = get_llm()

    # Gather memory listing for health assessment
    memory_listing = memory_list.invoke({})

    schedule_state = _read_schedule_state()
    now = datetime.now(timezone.utc)

    # Update schedule state with current run
    schedule_state["last_maintenance_run"] = now.isoformat()
    _write_schedule_state(schedule_state)

    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        SystemMessage(
            content=(
                f"## Current Memory Listing\n\n{memory_listing}\n\n"
                f"## Schedule State\n\n```json\n"
                f"{json.dumps(schedule_state, indent=2)}\n```\n\n"
                f"## Current Time\n\n{now.isoformat()}\n\n"
                "Assess the memory system health and produce a maintenance "
                "report."
            )
        ),
    ]

    response = llm.invoke(messages)
    report_text = response.content if isinstance(response.content, str) else str(response.content)

    return {
        "messages": [AIMessage(content=report_text, name="maintenance")],
    }

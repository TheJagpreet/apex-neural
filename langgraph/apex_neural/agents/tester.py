"""Tester agent — Test creation and validation.

Mirrors the behaviour defined in ``.github/agents/tester.agent.md``.
The Tester writes tests, runs them, and validates that the implementation
meets acceptance criteria.
"""

from __future__ import annotations

from langchain_core.messages import AIMessage, SystemMessage

from ..config import get_llm
from ..state import Phase, Verdict, WorkflowState
from ..tools.memory_tool import memory_store

SYSTEM_PROMPT = """\
You are the **Tester**, the quality assurance agent in a deterministic SDLC \
workflow. You write tests, run them, and validate that the implementation \
meets acceptance criteria.

## Pre-Testing Checklist

Before writing any tests, you MUST:
1. Read the approved plan and its acceptance criteria.
2. Read the architecture decision.
3. Read the implementation report.
4. Understand the project's existing test patterns and framework.

## Testing Process

1. **Discover test conventions** — find existing test files, framework, \
   naming, directory structure, assertions, and mocking patterns.
2. **Write tests** — unit tests (happy path, edge cases, errors), \
   integration tests if needed, following Arrange-Act-Assert pattern.
3. **Run tests** — execute the test suite and capture output.
4. **Validate acceptance criteria** — map each passing test to its criterion.
5. **Generate report** in the format below.

## Output Format

Your response MUST begin with one of these exact verdict lines:

```
VERDICT: PASS
VERDICT: FAIL
VERDICT: PARTIAL
```

Then provide the full report:

```markdown
# Test Report

## Test Environment
- Framework: [test framework]
- Runner command: [command used]

## Test Results
| Test | Status | Covers Criterion |
|------|--------|-----------------|
| test name | PASS/FAIL | criterion |

## Acceptance Criteria Coverage
- [x] Criterion 1: Covered by test X
- [ ] Criterion 3: NOT COVERED — reason

## Test Summary
- Total: N
- Passed: N
- Failed: N

## Failure Analysis (if any)
### Failure 1: [Test Name]
- **Error**: message
- **Root Cause**: analysis
- **Fix Required**: what needs to change

## Verdict: PASS / FAIL / PARTIAL
```

## Rules
1. Test behaviour, not implementation.
2. One assertion per concept.
3. Descriptive test names.
4. Independent tests.
5. Match existing patterns.
6. Do NOT fix production code — report bugs clearly.
"""


def _extract_verdict(text: str) -> Verdict:
    """Extract the test verdict from the tester's response."""
    upper = text.upper()
    if "VERDICT: PASS" in upper or "VERDICT:PASS" in upper:
        return Verdict.PASS
    if "VERDICT: PARTIAL" in upper or "VERDICT:PARTIAL" in upper:
        return Verdict.PARTIAL
    return Verdict.FAIL


def tester_node(state: WorkflowState) -> dict:
    """Execute the Tester agent and return state updates."""
    llm = get_llm()

    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        SystemMessage(
            content=(
                f"## Task Description\n\n{state.task_description}\n\n"
                f"## Approved Plan\n\n{state.plan}\n\n"
                f"## Architecture Decision\n\n{state.architecture_review}\n\n"
                f"## Implementation Report\n\n{state.implementation_report}"
            )
        ),
    ]

    response = llm.invoke(messages)
    report_text = response.content if isinstance(response.content, str) else str(response.content)
    verdict = _extract_verdict(report_text)

    iteration = state.solution_test_iterations + 1

    # Persist test results to memory
    memory_store.invoke(
        {
            "agent": "tester",
            "task": f"Test results: {state.task_description[:80]}",
            "tags": ["testing", "validation", verdict.value.lower()],
            "content": report_text,
            "outcome": verdict.value.lower(),
        }
    )

    next_phase = (
        Phase.COMPLETED if verdict == Verdict.PASS else Phase.SOLUTIONING
    )

    return {
        "test_report": report_text,
        "test_verdict": verdict,
        "solution_test_iterations": iteration,
        "current_phase": next_phase,
        "messages": [AIMessage(content=report_text, name="tester")],
    }

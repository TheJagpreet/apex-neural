#!/usr/bin/env bash
# Phase gate hook — prevents subagents from stopping without required outputs
set -uo pipefail

INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.hookEventName // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Prevent infinite loops — if stop hook already active, let it stop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  echo '{}'
  exit 0
fi

# For the orchestrator's Stop hook, check all phases completed
if [ "$EVENT" = "Stop" ] && [ -z "$AGENT_TYPE" ]; then
  # This is the main orchestrator stopping
  # Check if we have all required session artifacts
  MISSING=""

  # We can't easily check session memory files from here,
  # so we inject a reminder instead
  jq -n '{
    "hookSpecificOutput": {
      "hookEventName": "Stop",
      "additionalContext": "Before stopping, verify: 1) Plan was created and approved, 2) Architecture was validated, 3) Implementation was completed, 4) Tests passed. If any phase was skipped, continue working."
    }
  }'
  exit 0
fi

# For subagent stop events, the agent's own Stop hook fires
# Validate based on agent type
case "$AGENT_TYPE" in
  Planner)
    # Planner must have produced a plan
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "Stop",
        "additionalContext": "Before finishing: Ensure you saved the plan to /memories/session/current-plan.md. The plan must include: Objective, Acceptance Criteria, Affected Files, Task Breakdown, Risk Assessment, and Testing Strategy."
      }
    }'
    ;;
  Architect)
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "Stop",
        "additionalContext": "Before finishing: Ensure you saved the architecture decision to /memories/session/architecture-decision.md. The review must include: Verdict (APPROVED/NEEDS_REVISION/BLOCKED), Pattern Analysis, Reuse Opportunities, and Issues Found."
      }
    }'
    ;;
  Solutioner)
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "Stop",
        "additionalContext": "Before finishing: Ensure you saved the implementation log to /memories/session/implementation-log.md. Check #problems for any errors. Report must include: Tasks Completed, Files Changed, and Deviations from Plan."
      }
    }'
    ;;
  Tester)
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "Stop",
        "additionalContext": "Before finishing: Ensure you saved test results to /memories/session/test-results.md. Report must include: Test Results table, Acceptance Criteria Coverage, and Verdict (PASS/FAIL/PARTIAL)."
      }
    }'
    ;;
  *)
    echo '{}'
    ;;
esac

exit 0

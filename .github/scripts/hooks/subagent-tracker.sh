#!/usr/bin/env bash
# Subagent tracker — logs subagent start/stop events for audit trail
set -uo pipefail

INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.hookEventName // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.sessionId // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Create audit log directory
AUDIT_DIR="${CWD}/.github/audit"
mkdir -p "$AUDIT_DIR"

# Log the event
LOG_FILE="${AUDIT_DIR}/subagent-trace.log"

if [ "$EVENT" = "SubagentStart" ]; then
  echo "[${TIMESTAMP}] SESSION=${SESSION_ID} | START | agent=${AGENT_TYPE} id=${AGENT_ID}" >> "$LOG_FILE"

  # Inject context about the workflow phase
  PHASE_CONTEXT=""
  case "$AGENT_TYPE" in
    Planner)
      PHASE_CONTEXT="You are in PHASE 1 (PLANNING). Produce a structured implementation plan. Do NOT write any source code."
      ;;
    Architect)
      PHASE_CONTEXT="You are in PHASE 2 (ARCHITECTURE). Validate the plan against codebase patterns. Do NOT write any source code."
      ;;
    Solutioner)
      PHASE_CONTEXT="You are in PHASE 3 (SOLUTIONING). Implement code changes following the approved plan and architecture decisions."
      ;;
    Tester)
      PHASE_CONTEXT="You are in PHASE 4 (TESTING). Write and run tests. Do NOT fix production code — report issues instead."
      ;;
    Maintenance)
      PHASE_CONTEXT="You are running MAINTENANCE. Check scheduled tasks, execute overdue ones, and report results. Do NOT modify source code or agent definitions."
      ;;
  esac

  if [ -n "$PHASE_CONTEXT" ]; then
    jq -n --arg ctx "$PHASE_CONTEXT" '{
      "hookSpecificOutput": {
        "hookEventName": "SubagentStart",
        "additionalContext": $ctx
      }
    }'
  else
    echo '{}'
  fi

elif [ "$EVENT" = "SubagentStop" ]; then
  echo "[${TIMESTAMP}] SESSION=${SESSION_ID} | STOP  | agent=${AGENT_TYPE} id=${AGENT_ID}" >> "$LOG_FILE"
  echo '{}'
else
  echo '{}'
fi

exit 0

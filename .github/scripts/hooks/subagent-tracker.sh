#!/bin/sh
# Subagent tracker — logs subagent start/stop events for audit trail
# Cross-platform bash equivalent of subagent-tracker.ps1

# Read input from stdin
RAW_INPUT=$(cat)

# Extract fields
HOOK_EVENT=$(echo "$RAW_INPUT" | sed -n 's/.*"hookEventName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
AGENT_TYPE=$(echo "$RAW_INPUT" | sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
AGENT_ID=$(echo "$RAW_INPUT" | sed -n 's/.*"agent_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
TIMESTAMP=$(echo "$RAW_INPUT" | sed -n 's/.*"timestamp"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
SESSION_ID=$(echo "$RAW_INPUT" | sed -n 's/.*"sessionId"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
CWD=$(echo "$RAW_INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$CWD" ]; then
    CWD="."
fi

# Create audit log directory
AUDIT_DIR="$CWD/.github/audit"
mkdir -p "$AUDIT_DIR"

# Log file
LOG_FILE="$AUDIT_DIR/subagent-trace.log"

if [ "$HOOK_EVENT" = "SubagentStart" ]; then
    echo "[$TIMESTAMP] SESSION=$SESSION_ID | START | agent=$AGENT_TYPE id=$AGENT_ID" >> "$LOG_FILE"

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
        cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"$PHASE_CONTEXT"}}
EOF
    else
        echo '{}'
    fi

elif [ "$HOOK_EVENT" = "SubagentStop" ]; then
    echo "[$TIMESTAMP] SESSION=$SESSION_ID | STOP  | agent=$AGENT_TYPE id=$AGENT_ID" >> "$LOG_FILE"
    echo '{}'
else
    echo '{}'
fi

exit 0

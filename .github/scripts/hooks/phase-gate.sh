#!/bin/sh
# Phase gate hook — prevents subagents from stopping without required outputs
# Cross-platform bash equivalent of phase-gate.ps1

# Read input from stdin
RAW_INPUT=$(cat)

# Extract fields
HOOK_EVENT=$(echo "$RAW_INPUT" | sed -n 's/.*"hookEventName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
AGENT_TYPE=$(echo "$RAW_INPUT" | sed -n 's/.*"agent_type"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
STOP_HOOK_ACTIVE=$(echo "$RAW_INPUT" | sed -n 's/.*"stop_hook_active"[[:space:]]*:[[:space:]]*\([^,}]*\).*/\1/p' | tr -d '"[:space:]')

# Prevent infinite loops — if stop hook already active, let it stop
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    echo '{}'
    exit 0
fi

# For the orchestrator's Stop hook, check all phases completed
if [ "$HOOK_EVENT" = "Stop" ] && [ -z "$AGENT_TYPE" ]; then
    cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Before stopping, verify: 1) Plan was created and approved, 2) Architecture was validated, 3) Implementation was completed, 4) Tests passed. If any phase was skipped, continue working."}}
EOF
    exit 0
fi

# For subagent stop events, validate based on agent type
case "$AGENT_TYPE" in
    Planner)
        cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Before finishing: Ensure you saved the plan using the #memory tool (apex-neural_memory). The plan must include: Objective, Acceptance Criteria, Affected Files, Task Breakdown, Risk Assessment, and Testing Strategy."}}
EOF
        ;;
    Architect)
        cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Before finishing: Ensure you saved the architecture decision using the #memory tool (apex-neural_memory). The review must include: Verdict (APPROVED/NEEDS_REVISION/BLOCKED), Pattern Analysis, Reuse Opportunities, and Issues Found."}}
EOF
        ;;
    Solutioner)
        cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Before finishing: Ensure you saved the implementation log using the #memory tool (apex-neural_memory). Check #problems for any errors. Report must include: Tasks Completed, Files Changed, and Deviations from Plan."}}
EOF
        ;;
    Tester)
        cat <<'EOF'
{"hookSpecificOutput":{"hookEventName":"Stop","additionalContext":"Before finishing: Ensure you saved test results using the #memory tool (apex-neural_memory). Report must include: Test Results table, Acceptance Criteria Coverage, and Verdict (PASS/FAIL/PARTIAL)."}}
EOF
        ;;
    *)
        echo '{}'
        ;;
esac

exit 0

#!/usr/bin/env bash
# Memory auto-capture hook — generates a memory file when a subagent stops
# Triggered on SubagentStop events via safety-and-tracking.json
set -uo pipefail

INPUT=$(cat)

EVENT=$(echo "$INPUT" | jq -r '.hookEventName // empty')
AGENT_TYPE=$(echo "$INPUT" | jq -r '.agent_type // empty')
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
TIMESTAMP=$(echo "$INPUT" | jq -r '.timestamp // empty')
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Only run on SubagentStop events
if [ "$EVENT" != "SubagentStop" ]; then
  echo '{}'
  exit 0
fi

# Map agent type to memory folder
AGENT_LOWER=$(echo "$AGENT_TYPE" | tr '[:upper:]' '[:lower:]')
MEMORY_DIR="${CWD}/.github/memory/${AGENT_LOWER}"

# Skip if no matching memory folder
if [ ! -d "$MEMORY_DIR" ]; then
  echo '{}'
  exit 0
fi

# Generate timestamp for filename
if [ -n "$TIMESTAMP" ]; then
  # Parse ISO timestamp to our format: YYYYMMDD-HHMMSS
  FILE_TS=$(echo "$TIMESTAMP" | sed 's/[-:]//g' | sed 's/T/-/' | sed 's/Z//' | cut -c1-15)
else
  FILE_TS=$(date -u '+%Y%m%d-%H%M%S')
fi

ISO_TS="${TIMESTAMP:-$(date -u '+%Y-%m-%dT%H:%M:%SZ')}"

# Read the template for this agent
TEMPLATE_FILE="${MEMORY_DIR}/TEMPLATE.md"

# Generate a placeholder memory file
# The actual content should be populated by the agent before stopping,
# but this ensures a file always exists as a capture point
MEMORY_FILE="${MEMORY_DIR}/auto-capture-${FILE_TS}.md"

# Don't overwrite if a memory was already manually created in the last minute
RECENT=$(find "$MEMORY_DIR" -name "*.md" -newer "$MEMORY_DIR/TEMPLATE.md" -not -name "TEMPLATE.md" -not -name "auto-capture-*" -mmin -2 2>/dev/null | head -1)
if [ -n "$RECENT" ]; then
  # A recent manual memory exists — skip auto-capture
  echo '{}'
  exit 0
fi

# Check the audit log for context about what this agent did
AUDIT_LOG="${CWD}/.github/audit/subagent-trace.log"
AGENT_CONTEXT=""
if [ -f "$AUDIT_LOG" ]; then
  # Get the START entry for this agent to find the session context
  AGENT_CONTEXT=$(grep "agent=${AGENT_TYPE}" "$AUDIT_LOG" | tail -2 | head -1 | sed 's/.*| //')
fi

# Create the auto-captured memory file with frontmatter
cat > "$MEMORY_FILE" << MEMORY_EOF
---
agent: ${AGENT_LOWER}
date: "${ISO_TS}"
task: "Auto-captured from ${AGENT_TYPE} subagent session"
tags: [auto-capture, ${AGENT_LOWER}]
related_files: []
outcome: completed
confidence: medium
supersedes: null
conflicts_with: null
continues: null
conversation_type: task
---

# Auto-Captured: ${AGENT_TYPE} Session

## Context
Auto-generated memory capture from ${AGENT_TYPE} subagent stop event.
${AGENT_CONTEXT:+Agent activity: ${AGENT_CONTEXT}}

## Decisions Made
- (Populate with key decisions from the session)

## Patterns Discovered
- (Populate with any patterns identified)

## Outcome
Session completed. Details pending manual enrichment.

## Lessons / Notes
- This memory was auto-captured. Review and enrich with specific details from the session.
- If this memory is not useful, delete it or mark it for pruning.
MEMORY_EOF

# Inject context telling the agent to enrich the memory before fully stopping
jq -n --arg file "$MEMORY_FILE" '{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStop",
    "additionalContext": ("A memory file has been auto-created at " + $file + ". Before finishing, update this file with specific decisions, patterns, and outcomes from your session. Use the TEMPLATE.md in your memory folder as a guide for structure.")
  }
}'

exit 0

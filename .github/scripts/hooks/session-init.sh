#!/usr/bin/env bash
# Session initialization hook — injects project context into the agent session
set -euo pipefail

# Read input from stdin
INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Build project context
CONTEXT=""

# Detect project type
if [ -f "${CWD}/package.json" ]; then
  PROJECT_NAME=$(jq -r '.name // "unknown"' "${CWD}/package.json" 2>/dev/null)
  PROJECT_VERSION=$(jq -r '.version // "unknown"' "${CWD}/package.json" 2>/dev/null)
  CONTEXT="${CONTEXT}Project: ${PROJECT_NAME} v${PROJECT_VERSION} (Node.js) | "
elif [ -f "${CWD}/Cargo.toml" ]; then
  CONTEXT="${CONTEXT}Project: Rust (Cargo) | "
elif [ -f "${CWD}/pyproject.toml" ] || [ -f "${CWD}/setup.py" ]; then
  CONTEXT="${CONTEXT}Project: Python | "
elif [ -f "${CWD}/go.mod" ]; then
  CONTEXT="${CONTEXT}Project: Go | "
fi

# Get git info
if command -v git &>/dev/null && [ -d "${CWD}/.git" ]; then
  BRANCH=$(git -C "${CWD}" branch --show-current 2>/dev/null || echo "unknown")
  CONTEXT="${CONTEXT}Branch: ${BRANCH} | "
fi

# Check for existing session state (resume support)
RESUME_INFO=""
if [ -f "${CWD}/.github/agents/session-state.md" ]; then
  RESUME_INFO="Previous session state found."
fi

# Memory is managed by the apex-neural-memory VS Code extension.
# Use the apex-neural_memory tool (#memory) for store/recall/list operations.
MEMORY_HINT="Memory: Use #memory tool (apex-neural_memory) for store/recall/list."

# --- Build final context ---

ADDITIONAL="${CONTEXT}${RESUME_INFO} ${MEMORY_HINT}"
ADDITIONAL="${ADDITIONAL:-No project context detected.}"

# Output JSON response
jq -n --arg ctx "$ADDITIONAL" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ctx
  }
}'

#!/bin/sh
# Session initialization hook — injects project context into the agent session
# Cross-platform bash equivalent of session-init.ps1

set -e

# Read input from stdin
RAW_INPUT=$(cat)

# Extract cwd
CWD=$(echo "$RAW_INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$CWD" ]; then
    CWD="."
fi

# Build project context
CONTEXT=""

# Detect project type
if [ -f "$CWD/package.json" ]; then
    PROJECT_NAME=$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CWD/package.json" | head -1)
    PROJECT_VERSION=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CWD/package.json" | head -1)
    PROJECT_NAME="${PROJECT_NAME:-unknown}"
    PROJECT_VERSION="${PROJECT_VERSION:-unknown}"
    CONTEXT="Project: $PROJECT_NAME v$PROJECT_VERSION (Node.js) | "
elif [ -f "$CWD/Cargo.toml" ]; then
    CONTEXT="Project: Rust (Cargo) | "
elif [ -f "$CWD/pyproject.toml" ] || [ -f "$CWD/setup.py" ]; then
    CONTEXT="Project: Python | "
elif [ -f "$CWD/go.mod" ]; then
    CONTEXT="Project: Go | "
fi

# Get git info
if command -v git >/dev/null 2>&1 && [ -d "$CWD/.git" ]; then
    BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "unknown")
    if [ -z "$BRANCH" ]; then BRANCH="unknown"; fi
    CONTEXT="${CONTEXT}Branch: $BRANCH | "
fi

# Check for existing session state (resume support)
RESUME_INFO=""
if [ -f "$CWD/.github/agents/session-state.md" ]; then
    RESUME_INFO="Previous session state found."
fi

# Memory hint
MEMORY_HINT="Memory: Use #memory tool (apex-neural_memory) for store/recall/list."

# Build final context
ADDITIONAL="${CONTEXT}${RESUME_INFO} ${MEMORY_HINT}"
ADDITIONAL=$(echo "$ADDITIONAL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
if [ -z "$ADDITIONAL" ]; then
    ADDITIONAL="No project context detected."
fi

# Escape special characters for JSON
ESCAPED=$(printf '%s' "$ADDITIONAL" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g')

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"$ESCAPED"}}
EOF

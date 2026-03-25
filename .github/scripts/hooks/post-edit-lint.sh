#!/usr/bin/env bash
# Post-edit linting hook — runs linter/formatter after file edits
set -uo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.filePath // .tool_input.file_path // empty')

# Only run on file-editing tools
case "$TOOL_NAME" in
  editFiles|create_file|replace_string_in_file|multi_replace_string_in_file|edit_notebook_file)
    ;;
  *)
    # Not a file edit tool — skip
    echo '{}' 
    exit 0
    ;;
esac

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
  echo '{}'
  exit 0
fi

CWD=$(echo "$INPUT" | jq -r '.cwd // "."')
ADDITIONAL_CONTEXT=""

# Get file extension
EXT="${FILE_PATH##*.}"

# Run appropriate linter based on file type
case "$EXT" in
  ts|tsx|js|jsx|mjs|cjs)
    # Check for prettier first, then eslint
    if [ -f "${CWD}/node_modules/.bin/prettier" ]; then
      RESULT=$(cd "$CWD" && npx prettier --check "$FILE_PATH" 2>&1) || {
        ADDITIONAL_CONTEXT="Prettier found formatting issues in ${FILE_PATH}: ${RESULT}"
      }
    fi
    ;;
  py)
    if command -v ruff &>/dev/null; then
      RESULT=$(cd "$CWD" && ruff check "$FILE_PATH" 2>&1) || {
        ADDITIONAL_CONTEXT="Ruff found issues in ${FILE_PATH}: ${RESULT}"
      }
    fi
    ;;
  rs)
    # Rust clippy is too slow for a hook — skip
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      RESULT=$(gofmt -l "$FILE_PATH" 2>&1)
      if [ -n "$RESULT" ]; then
        ADDITIONAL_CONTEXT="gofmt: ${FILE_PATH} needs formatting"
      fi
    fi
    ;;
esac

# --- Reactive maintenance: trigger tasks after relevant file changes ---

# If schedule.json was edited, validate its structure
if echo "$FILE_PATH" | grep -qE '\.github/schedule\.json$'; then
  if ! jq empty "${FILE_PATH}" 2>/dev/null; then
    ADDITIONAL_CONTEXT="${ADDITIONAL_CONTEXT:+${ADDITIONAL_CONTEXT} | }WARNING: schedule.json has invalid JSON syntax."
  fi
fi

if [ -n "$ADDITIONAL_CONTEXT" ]; then
  jq -n --arg ctx "$ADDITIONAL_CONTEXT" '{
    "hookSpecificOutput": {
      "hookEventName": "PostToolUse",
      "additionalContext": $ctx
    }
  }'
else
  echo '{}'
fi

exit 0

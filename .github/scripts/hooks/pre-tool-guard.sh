#!/usr/bin/env bash
# Pre-tool safety guard — blocks dangerous operations
set -uo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty')

# Block dangerous terminal commands
if [ "$TOOL_NAME" = "run_in_terminal" ] || [ "$TOOL_NAME" = "terminal" ]; then
  COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

  # Block destructive commands
  BLOCKED_PATTERNS=(
    "rm -rf /"
    "rm -rf ~"
    "rm -rf \$HOME"
    "DROP TABLE"
    "DROP DATABASE"
    "TRUNCATE TABLE"
    ":(){ :|:& };:"
    "mkfs"
    "dd if="
    "> /dev/sda"
    "chmod -R 777 /"
    "git push.*--force.*main"
    "git push.*--force.*master"
    "git reset --hard.*origin"
  )

  for PATTERN in "${BLOCKED_PATTERNS[@]}"; do
    if echo "$COMMAND" | grep -qiE "$PATTERN"; then
      jq -n --arg reason "Blocked by safety guard: command matches dangerous pattern '${PATTERN}'" '{
        "hookSpecificOutput": {
          "hookEventName": "PreToolUse",
          "permissionDecision": "deny",
          "permissionDecisionReason": $reason
        }
      }'
      exit 0
    fi
  done
fi

# Block editing of hook scripts (prevent self-modification)
if [ "$TOOL_NAME" = "editFiles" ] || [ "$TOOL_NAME" = "create_file" ] || [ "$TOOL_NAME" = "replace_string_in_file" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.filePath // .tool_input.file_path // empty')
  if echo "$FILE_PATH" | grep -qE "(\.github/scripts/hooks/|\.github/hooks/)"; then
    jq -n '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": "Agent is attempting to modify hook scripts. Manual approval required."
      }
    }'
    exit 0
  fi
fi

# Allow everything else
echo '{}'
exit 0

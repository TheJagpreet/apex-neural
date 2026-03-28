#!/bin/sh
# Post-edit linting hook — runs linter/formatter after file edits
# Cross-platform bash equivalent of post-edit-lint.ps1

# Read input from stdin
RAW_INPUT=$(cat)

# Extract fields using lightweight JSON parsing
TOOL_NAME=$(echo "$RAW_INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Only run on file-editing tools
case "$TOOL_NAME" in
    editFiles|create_file|replace_string_in_file|multi_replace_string_in_file|edit_notebook_file)
        ;;
    *)
        echo '{}'
        exit 0
        ;;
esac

# Extract file path
FILE_PATH=$(echo "$RAW_INPUT" | sed -n 's/.*"filePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$RAW_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi

# Skip if no file path
if [ -z "$FILE_PATH" ]; then
    echo '{}'
    exit 0
fi

CWD=$(echo "$RAW_INPUT" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
if [ -z "$CWD" ]; then
    CWD="."
fi

ADDITIONAL_CONTEXT=""

# Get file extension
EXT="${FILE_PATH##*.}"

# Run appropriate linter based on file type
case "$EXT" in
    ts|tsx|js|jsx|mjs|cjs)
        if [ -f "$CWD/node_modules/.bin/prettier" ]; then
            if ! RESULT=$(cd "$CWD" && npx prettier --check "$FILE_PATH" 2>&1); then
                ADDITIONAL_CONTEXT="Prettier found formatting issues in ${FILE_PATH}: $RESULT"
            fi
        fi
        ;;
    py)
        if command -v ruff >/dev/null 2>&1; then
            if ! RESULT=$(cd "$CWD" && ruff check "$FILE_PATH" 2>&1); then
                ADDITIONAL_CONTEXT="Ruff found issues in ${FILE_PATH}: $RESULT"
            fi
        fi
        ;;
    go)
        if command -v gofmt >/dev/null 2>&1; then
            RESULT=$(gofmt -l "$FILE_PATH" 2>&1)
            if [ -n "$RESULT" ]; then
                ADDITIONAL_CONTEXT="gofmt: $FILE_PATH needs formatting"
            fi
        fi
        ;;
esac

# Reactive maintenance: trigger tasks after relevant file changes
if echo "$FILE_PATH" | grep -qE '\.github[/\\]schedule\.json$'; then
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json; json.load(open('$FILE_PATH'))" 2>/dev/null
        if [ $? -ne 0 ]; then
            if [ -n "$ADDITIONAL_CONTEXT" ]; then
                ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT | WARNING: schedule.json has invalid JSON syntax."
            else
                ADDITIONAL_CONTEXT="WARNING: schedule.json has invalid JSON syntax."
            fi
        fi
    elif command -v node >/dev/null 2>&1; then
        node -e "JSON.parse(require('fs').readFileSync('$FILE_PATH','utf8'))" 2>/dev/null
        if [ $? -ne 0 ]; then
            if [ -n "$ADDITIONAL_CONTEXT" ]; then
                ADDITIONAL_CONTEXT="$ADDITIONAL_CONTEXT | WARNING: schedule.json has invalid JSON syntax."
            else
                ADDITIONAL_CONTEXT="WARNING: schedule.json has invalid JSON syntax."
            fi
        fi
    fi
fi

if [ -n "$ADDITIONAL_CONTEXT" ]; then
    # Escape special characters for JSON
    ESCAPED_CONTEXT=$(printf '%s' "$ADDITIONAL_CONTEXT" | sed "s/\\\\/\\\\\\\\/g; s/\"/\\\\\"/g; s/$(printf '\t')/\\\\t/g")
    cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"$ESCAPED_CONTEXT"}}
EOF
else
    echo '{}'
fi

exit 0

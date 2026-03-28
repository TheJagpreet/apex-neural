#!/bin/sh
# Pre-tool safety guard — blocks dangerous operations
# Cross-platform bash equivalent of pre-tool-guard.ps1

# Read input from stdin
RAW_INPUT=$(cat)

# Extract tool_name using lightweight JSON parsing
TOOL_NAME=$(echo "$RAW_INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

# Block dangerous terminal commands
if [ "$TOOL_NAME" = "run_in_terminal" ] || [ "$TOOL_NAME" = "terminal" ]; then
    COMMAND=$(echo "$RAW_INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

    # Check against blocked patterns
    BLOCKED=""
    case "$COMMAND" in
        *"rm -rf /"*)           BLOCKED="rm -rf /" ;;
        *"rm -rf ~"*)           BLOCKED="rm -rf ~" ;;
        *'rm -rf $HOME'*)       BLOCKED='rm -rf $HOME' ;;
        *"Remove-Item -Recurse -Force /"*) BLOCKED="Remove-Item -Recurse -Force /" ;;
        *"Remove-Item -Recurse -Force \\"*) BLOCKED="Remove-Item -Recurse -Force \\" ;;
        *"Remove-Item -Recurse -Force ~"*) BLOCKED="Remove-Item -Recurse -Force ~" ;;
        *"DROP TABLE"*)         BLOCKED="DROP TABLE" ;;
        *"DROP DATABASE"*)      BLOCKED="DROP DATABASE" ;;
        *"TRUNCATE TABLE"*)     BLOCKED="TRUNCATE TABLE" ;;
        *"Format-Volume"*)      BLOCKED="Format-Volume" ;;
        *"Clear-Disk"*)         BLOCKED="Clear-Disk" ;;
        *"del /s /q C:\\"*)     BLOCKED="del /s /q C:\\" ;;
        *"rd /s /q C:\\"*)      BLOCKED="rd /s /q C:\\" ;;
    esac

    # Check regex-like patterns with grep
    if [ -z "$BLOCKED" ]; then
        if echo "$COMMAND" | grep -qE 'format [a-zA-Z]:'; then
            BLOCKED="format drive"
        elif echo "$COMMAND" | grep -qE 'git push.*--force.*main'; then
            BLOCKED="git push --force main"
        elif echo "$COMMAND" | grep -qE 'git push.*--force.*master'; then
            BLOCKED="git push --force master"
        elif echo "$COMMAND" | grep -qE 'git reset --hard.*origin'; then
            BLOCKED="git reset --hard origin"
        fi
    fi

    if [ -n "$BLOCKED" ]; then
        cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Blocked by safety guard: command matches dangerous pattern '$BLOCKED'"}}
EOF
        exit 0
    fi
fi

# Block editing of hook scripts (prevent self-modification)
case "$TOOL_NAME" in
    editFiles|create_file|replace_string_in_file)
        FILE_PATH=$(echo "$RAW_INPUT" | sed -n 's/.*"filePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        if [ -z "$FILE_PATH" ]; then
            FILE_PATH=$(echo "$RAW_INPUT" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        fi
        if echo "$FILE_PATH" | grep -qE '\.github[/\\]scripts[/\\]hooks[/\\]|\.github[/\\]hooks[/\\]'; then
            cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Agent is attempting to modify hook scripts. Manual approval required."}}
EOF
            exit 0
        fi
        ;;
esac

# Allow everything else
echo '{}'
exit 0

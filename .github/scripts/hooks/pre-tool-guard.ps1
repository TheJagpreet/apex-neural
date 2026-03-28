# Pre-tool safety guard — blocks dangerous operations

# Read input from stdin
$RawInput = $input | Out-String
$InputObj = $RawInput | ConvertFrom-Json

$ToolName = $InputObj.tool_name

# Block dangerous terminal commands
if ($ToolName -eq 'run_in_terminal' -or $ToolName -eq 'terminal') {
    $Command = $InputObj.tool_input.command

    # Block destructive commands
    $BlockedPatterns = @(
        'rm -rf /',
        'rm -rf ~',
        'rm -rf \$HOME',
        'Remove-Item -Recurse -Force [/\\]$',
        'Remove-Item -Recurse -Force ~',
        'DROP TABLE',
        'DROP DATABASE',
        'TRUNCATE TABLE',
        'Format-Volume',
        'Clear-Disk',
        'format [a-zA-Z]:',
        'del /s /q C:\\',
        'rd /s /q C:\\',
        'git push.*--force.*main',
        'git push.*--force.*master',
        'git reset --hard.*origin'
    )

    foreach ($Pattern in $BlockedPatterns) {
        if ($Command -match $Pattern) {
            @{
                hookSpecificOutput = @{
                    hookEventName = "PreToolUse"
                    permissionDecision = "deny"
                    permissionDecisionReason = "Blocked by safety guard: command matches dangerous pattern '$Pattern'"
                }
            } | ConvertTo-Json -Depth 3
            exit 0
        }
    }
}

# Block editing of hook scripts (prevent self-modification)
if ($ToolName -in @('editFiles', 'create_file', 'replace_string_in_file')) {
    $FilePath = if ($InputObj.tool_input.filePath) { $InputObj.tool_input.filePath } else { $InputObj.tool_input.file_path }
    if ($FilePath -match '(\.github[\\/]scripts[\\/]hooks[\\/]|\.github[\\/]hooks[\\/])') {
        @{
            hookSpecificOutput = @{
                hookEventName = "PreToolUse"
                permissionDecision = "ask"
                permissionDecisionReason = "Agent is attempting to modify hook scripts. Manual approval required."
            }
        } | ConvertTo-Json -Depth 3
        exit 0
    }
}

# Allow everything else
Write-Output '{}'
exit 0

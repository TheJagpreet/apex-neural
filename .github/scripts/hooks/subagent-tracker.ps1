# Subagent tracker — logs subagent start/stop events for audit trail

# Read input from stdin
$RawInput = $input | Out-String
$InputObj = $RawInput | ConvertFrom-Json

$HookEvent = $InputObj.hookEventName
$AgentType = $InputObj.agent_type
$AgentId = $InputObj.agent_id
$Timestamp = $InputObj.timestamp
$SessionId = $InputObj.sessionId
$Cwd = if ($InputObj.cwd) { $InputObj.cwd } else { "." }

# Create audit log directory
$AuditDir = Join-Path $Cwd ".github\audit"
if (-not (Test-Path $AuditDir)) {
    New-Item -ItemType Directory -Path $AuditDir -Force | Out-Null
}

# Log the event
$LogFile = Join-Path $AuditDir "subagent-trace.log"

if ($HookEvent -eq 'SubagentStart') {
    Add-Content -Path $LogFile -Value "[$Timestamp] SESSION=$SessionId | START | agent=$AgentType id=$AgentId"

    # Inject context about the workflow phase
    $PhaseContext = switch ($AgentType) {
        'Planner'     { "You are in PHASE 1 (PLANNING). Produce a structured implementation plan. Do NOT write any source code." }
        'Architect'   { "You are in PHASE 2 (ARCHITECTURE). Validate the plan against codebase patterns. Do NOT write any source code." }
        'Solutioner'  { "You are in PHASE 3 (SOLUTIONING). Implement code changes following the approved plan and architecture decisions." }
        'Tester'      { "You are in PHASE 4 (TESTING). Write and run tests. Do NOT fix production code — report issues instead." }
        'Maintenance' { "You are running MAINTENANCE. Check scheduled tasks, execute overdue ones, and report results. Do NOT modify source code or agent definitions." }
        default       { $null }
    }

    if ($PhaseContext) {
        @{
            hookSpecificOutput = @{
                hookEventName = "SubagentStart"
                additionalContext = $PhaseContext
            }
        } | ConvertTo-Json -Depth 3
    } else {
        Write-Output '{}'
    }

} elseif ($HookEvent -eq 'SubagentStop') {
    Add-Content -Path $LogFile -Value "[$Timestamp] SESSION=$SessionId | STOP  | agent=$AgentType id=$AgentId"
    Write-Output '{}'
} else {
    Write-Output '{}'
}

exit 0

# Phase gate hook — prevents subagents from stopping without required outputs

# Read input from stdin
$RawInput = $input | Out-String
$InputObj = $RawInput | ConvertFrom-Json

$HookEvent = $InputObj.hookEventName
$AgentType = $InputObj.agent_type
$StopHookActive = $InputObj.stop_hook_active

# Prevent infinite loops — if stop hook already active, let it stop
if ($StopHookActive -eq 'true' -or $StopHookActive -eq $true) {
    Write-Output '{}'
    exit 0
}

# For the orchestrator's Stop hook, check all phases completed
if ($HookEvent -eq 'Stop' -and -not $AgentType) {
    @{
        hookSpecificOutput = @{
            hookEventName = "Stop"
            additionalContext = "Before stopping, verify: 1) Plan was created and approved, 2) Architecture was validated, 3) Implementation was completed, 4) Tests passed. If any phase was skipped, continue working."
        }
    } | ConvertTo-Json -Depth 3
    exit 0
}

# For subagent stop events, validate based on agent type
$Result = switch ($AgentType) {
    'Planner' {
        @{
            hookSpecificOutput = @{
                hookEventName = "Stop"
                additionalContext = "Before finishing: Ensure you saved the plan using the #apex_memory tool (apex-neural_memory). The plan must include: Objective, Acceptance Criteria, Affected Files, Task Breakdown, Risk Assessment, and Testing Strategy."
            }
        }
    }
    'Architect' {
        @{
            hookSpecificOutput = @{
                hookEventName = "Stop"
                additionalContext = "Before finishing: Ensure you saved the architecture decision using the #apex_memory tool (apex-neural_memory). The review must include: Verdict (APPROVED/NEEDS_REVISION/BLOCKED), Pattern Analysis, Reuse Opportunities, and Issues Found."
            }
        }
    }
    'Solutioner' {
        @{
            hookSpecificOutput = @{
                hookEventName = "Stop"
                additionalContext = "Before finishing: Ensure you saved the implementation log using the #apex_memory tool (apex-neural_memory). Check #problems for any errors. Report must include: Tasks Completed, Files Changed, and Deviations from Plan."
            }
        }
    }
    'Tester' {
        @{
            hookSpecificOutput = @{
                hookEventName = "Stop"
                additionalContext = "Before finishing: Ensure you saved test results using the #apex_memory tool (apex-neural_memory). Report must include: Test Results table, Acceptance Criteria Coverage, and Verdict (PASS/FAIL/PARTIAL)."
            }
        }
    }
    default { $null }
}

if ($Result) {
    $Result | ConvertTo-Json -Depth 3
} else {
    Write-Output '{}'
}

exit 0

# Post-edit linting hook — runs linter/formatter after file edits

# Read input from stdin
$RawInput = $input | Out-String
$InputObj = $RawInput | ConvertFrom-Json

$ToolName = $InputObj.tool_name
$FilePath = if ($InputObj.tool_input.filePath) { $InputObj.tool_input.filePath } else { $InputObj.tool_input.file_path }

# Only run on file-editing tools
$EditTools = @('editFiles', 'create_file', 'replace_string_in_file', 'multi_replace_string_in_file', 'edit_notebook_file')
if ($ToolName -notin $EditTools) {
    Write-Output '{}'
    exit 0
}

# Skip if no file path
if (-not $FilePath) {
    Write-Output '{}'
    exit 0
}

$Cwd = if ($InputObj.cwd) { $InputObj.cwd } else { "." }
$AdditionalContext = ""

# Get file extension
$Ext = [System.IO.Path]::GetExtension($FilePath).TrimStart('.')

# Run appropriate linter based on file type
switch -Regex ($Ext) {
    '^(ts|tsx|js|jsx|mjs|cjs)$' {
        $PrettierPath = Join-Path $Cwd "node_modules\.bin\prettier.cmd"
        if (Test-Path $PrettierPath) {
            try {
                Push-Location $Cwd
                $Result = & npx prettier --check $FilePath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $AdditionalContext = "Prettier found formatting issues in ${FilePath}: $Result"
                }
            } finally {
                Pop-Location
            }
        }
    }
    '^py$' {
        if (Get-Command ruff -ErrorAction SilentlyContinue) {
            try {
                Push-Location $Cwd
                $Result = & ruff check $FilePath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $AdditionalContext = "Ruff found issues in ${FilePath}: $Result"
                }
            } finally {
                Pop-Location
            }
        }
    }
    '^go$' {
        if (Get-Command gofmt -ErrorAction SilentlyContinue) {
            $Result = & gofmt -l $FilePath 2>&1
            if ($Result) {
                $AdditionalContext = "gofmt: $FilePath needs formatting"
            }
        }
    }
}

# Reactive maintenance: trigger tasks after relevant file changes
if ($FilePath -match '\.github[\\/]schedule\.json$') {
    try {
        Get-Content $FilePath -Raw | ConvertFrom-Json | Out-Null
    } catch {
        if ($AdditionalContext) {
            $AdditionalContext += " | WARNING: schedule.json has invalid JSON syntax."
        } else {
            $AdditionalContext = "WARNING: schedule.json has invalid JSON syntax."
        }
    }
}

if ($AdditionalContext) {
    @{
        hookSpecificOutput = @{
            hookEventName = "PostToolUse"
            additionalContext = $AdditionalContext
        }
    } | ConvertTo-Json -Depth 3
} else {
    Write-Output '{}'
}

exit 0

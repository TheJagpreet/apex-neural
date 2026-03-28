# Session initialization hook — injects project context into the agent session
$ErrorActionPreference = 'Stop'

# Read input from stdin
$RawInput = $input | Out-String
$InputObj = $RawInput | ConvertFrom-Json

$Cwd = $InputObj.cwd

# Build project context
$Context = ""

# Detect project type
if (Test-Path (Join-Path $Cwd "package.json")) {
    $PkgJson = Get-Content (Join-Path $Cwd "package.json") -Raw | ConvertFrom-Json
    $ProjectName = if ($PkgJson.name) { $PkgJson.name } else { "unknown" }
    $ProjectVersion = if ($PkgJson.version) { $PkgJson.version } else { "unknown" }
    $Context += "Project: $ProjectName v$ProjectVersion (Node.js) | "
} elseif (Test-Path (Join-Path $Cwd "Cargo.toml")) {
    $Context += "Project: Rust (Cargo) | "
} elseif ((Test-Path (Join-Path $Cwd "pyproject.toml")) -or (Test-Path (Join-Path $Cwd "setup.py"))) {
    $Context += "Project: Python | "
} elseif (Test-Path (Join-Path $Cwd "go.mod")) {
    $Context += "Project: Go | "
}

# Get git info
if ((Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path (Join-Path $Cwd ".git"))) {
    $Branch = git -C $Cwd branch --show-current 2>$null
    if (-not $Branch) { $Branch = "unknown" }
    $Context += "Branch: $Branch | "
}

# Check for existing session state (resume support)
$ResumeInfo = ""
if (Test-Path (Join-Path $Cwd ".github\agents\session-state.md")) {
    $ResumeInfo = "Previous session state found."
}

# Memory is managed by the apex-neural-memory VS Code extension.
# Use the apex-neural_memory tool (#memory) for store/recall/list operations.
$MemoryHint = "Memory: Use #memory tool (apex-neural_memory) for store/recall/list."

# Build final context
$Additional = "$Context$ResumeInfo $MemoryHint"
if (-not $Additional.Trim()) {
    $Additional = "No project context detected."
}

# Output JSON response
@{
    hookSpecificOutput = @{
        hookEventName = "SessionStart"
        additionalContext = $Additional
    }
} | ConvertTo-Json -Depth 3

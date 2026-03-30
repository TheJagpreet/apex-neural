# Apex Neural — Workspace Setup Script (PowerShell)
#
# Cross-platform PowerShell setup for Windows (and PowerShell Core on Linux/macOS).
# Mirrors the functionality of scripts/setup.js.
#
# Usage:
#   .\scripts\setup.ps1
#   .\scripts\setup.ps1 -Workspace C:\path\to\workspace

param(
    [string]$Workspace
)

$ErrorActionPreference = 'Stop'

# ─── Helpers ─────────────────────────────────────────────────────────────────

function Write-Info($msg)    { Write-Host "ℹ  $msg" -ForegroundColor Cyan }
function Write-Success($msg) { Write-Host "✔  $msg" -ForegroundColor Green }
function Write-Warn($msg)    { Write-Host "⚠  $msg" -ForegroundColor Yellow }
function Write-Err($msg)     { Write-Host "✖  $msg" -ForegroundColor Red }

function Copy-DirectoryRecursive($Source, $Destination) {
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    foreach ($item in Get-ChildItem -Path $Source) {
        $destPath = Join-Path $Destination $item.Name
        if ($item.PSIsContainer) {
            Copy-DirectoryRecursive -Source $item.FullName -Destination $destPath
        } else {
            Copy-Item -Path $item.FullName -Destination $destPath -Force
        }
    }
}

function Get-FileCountRecursive($Dir) {
    return (Get-ChildItem -Path $Dir -Recurse -File).Count
}

# ─── Resolve paths ───────────────────────────────────────────────────────────

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$SourceGithub = Join-Path $RepoRoot ".github"
$SourceReadme = Join-Path $RepoRoot "README.md"
$SourceMcpJson = Join-Path $RepoRoot ".vscode" "mcp.json"
$ExtensionDir = Join-Path $RepoRoot "extensions" "apex-neural-memory"

# ─── Validate sources ────────────────────────────────────────────────────────

if (-not (Test-Path $SourceGithub)) {
    Write-Err ".github/ folder not found at: $SourceGithub"
    Write-Err "Please run this script from the apex-neural repository root."
    exit 1
}

if (-not (Test-Path $SourceReadme)) {
    Write-Err "README.md not found at: $SourceReadme"
    exit 1
}

# ─── Banner ──────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       Apex Neural — Workspace Setup           ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ─── Determine workspace ─────────────────────────────────────────────────────

$DefaultWorkspace = Split-Path -Parent $RepoRoot

if ($Workspace) {
    $WorkspaceRoot = Resolve-Path $Workspace -ErrorAction Stop
} else {
    $Input = Read-Host "Workspace root directory (parent of all repos) [$DefaultWorkspace]"
    $WorkspaceRoot = if ($Input) { Resolve-Path $Input -ErrorAction Stop } else { $DefaultWorkspace }
}

if (-not (Test-Path $WorkspaceRoot)) {
    Write-Err "Workspace directory does not exist: $WorkspaceRoot"
    exit 1
}

$DestGithub = Join-Path $WorkspaceRoot ".github"
$DestReadme = Join-Path $DestGithub "apex-neural-README.md"
$DestVscode = Join-Path $WorkspaceRoot ".vscode"
$DestMcpJson = Join-Path $DestVscode "mcp.json"
$FileCount = Get-FileCountRecursive $SourceGithub

# ─── Summary ─────────────────────────────────────────────────────────────────

Write-Host ""
Write-Info "The following actions will be performed:"
Write-Host ""
Write-Host "  1. Copy .github/ → $DestGithub"
Write-Host "     ($FileCount files)"
Write-Host "  2. Copy README.md → $DestReadme"
Write-Host "  3. Copy .vscode/mcp.json → $DestMcpJson (Playwright MCP server)"
Write-Host "  4. Install VS Code extension: apex-neural-memory"
Write-Host ""

if (Test-Path $DestGithub) {
    Write-Warn "$DestGithub already exists. Files will be overwritten."
    Write-Host ""
}

$Confirm = Read-Host "Proceed with setup? (y/n)"
if ($Confirm -notmatch '^[yY]') {
    Write-Info "Setup cancelled."
    exit 0
}

Write-Host ""

# ─── Step 1: Copy .github/ ──────────────────────────────────────────────────

Write-Info "Copying .github/ folder..."
Copy-DirectoryRecursive -Source $SourceGithub -Destination $DestGithub
Write-Success ".github/ copied to $DestGithub"

# ─── Step 2: Copy README ────────────────────────────────────────────────────

Write-Info "Copying README.md..."
Copy-Item -Path $SourceReadme -Destination $DestReadme -Force
Write-Success "README.md copied as $DestReadme"

# ─── Step 3: Copy .vscode/mcp.json ─────────────────────────────────────────

if (Test-Path $SourceMcpJson) {
    Write-Info "Copying .vscode/mcp.json (Playwright MCP server config)..."
    if (-not (Test-Path $DestVscode)) {
        New-Item -ItemType Directory -Path $DestVscode -Force | Out-Null
    }
    Copy-Item -Path $SourceMcpJson -Destination $DestMcpJson -Force
    Write-Success ".vscode/mcp.json copied to $DestMcpJson"
} else {
    Write-Warn ".vscode/mcp.json not found in the repository — skipping MCP config."
}

# ─── Step 4: Install extension ───────────────────────────────────────────────

$VsixPath = $null
if (Test-Path $ExtensionDir) {
    $VsixFile = Get-ChildItem -Path $ExtensionDir -Filter "*.vsix" -File | Select-Object -First 1
    if ($VsixFile) {
        $VsixPath = $VsixFile.FullName
    }
}

if (-not $VsixPath) {
    Write-Warn "No .vsix file found in extensions/apex-neural-memory/."
    Write-Warn "Build it with: cd extensions\apex-neural-memory && npm run package"
} else {
    $InstallExt = Read-Host "Install the apex-neural-memory VS Code extension now? (y/n)"
    if ($InstallExt -match '^[yY]') {
        Write-Info "Installing VS Code extension..."
        try {
            & code --install-extension $VsixPath 2>$null
            Write-Success "apex-neural-memory extension installed."
        } catch {
            Write-Warn "Could not install the extension automatically."
            Write-Host ""
            Write-Info "To install manually, run:"
            Write-Host "     code --install-extension $VsixPath"
        }
    } else {
        Write-Info "Skipped extension installation."
        Write-Info "To install manually later, run:"
        Write-Host "     code --install-extension $VsixPath"
    }
}

# ─── Done ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "╔════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║            Setup complete! 🚀                  ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Info "Next steps:"
Write-Host "  1. Open the workspace folder in VS Code"
Write-Host "  2. Enable these settings in your VS Code settings:"
Write-Host '     "chat.useCustomAgentHooks": true' -ForegroundColor Cyan
Write-Host '     "chat.plugins.enabled": true' -ForegroundColor Cyan
Write-Host "  3. Ensure the apex-neural-memory extension is installed"
Write-Host "  4. Open VS Code Chat and select Orchestrator to get started"
Write-Host ""
Write-Info "Alternative: Install as a VS Code Copilot agent plugin:"
Write-Host "  Run Chat: Install Plugin From Source in the Command Palette" -ForegroundColor Cyan
Write-Host "  and enter: https://github.com/TheJagpreet/apex-neural" -ForegroundColor Cyan
Write-Host ""

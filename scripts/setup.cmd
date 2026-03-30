@echo off
REM Apex Neural — Workspace Setup (Windows batch wrapper)
REM
REM This wrapper detects PowerShell and runs setup.ps1.
REM Falls back to the Node.js setup if PowerShell is unavailable.
REM
REM Usage:
REM   scripts\setup.cmd
REM   scripts\setup.cmd --workspace C:\path\to\workspace

setlocal

set "SCRIPT_DIR=%~dp0"

REM Try PowerShell Core (pwsh) first, then Windows PowerShell
where pwsh >nul 2>&1
if %ERRORLEVEL% equ 0 (
    pwsh -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup.ps1" %*
    exit /b %ERRORLEVEL%
)

where powershell >nul 2>&1
if %ERRORLEVEL% equ 0 (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%setup.ps1" %*
    exit /b %ERRORLEVEL%
)

REM Fallback to Node.js setup
where node >nul 2>&1
if %ERRORLEVEL% equ 0 (
    node "%SCRIPT_DIR%setup.js" %*
    exit /b %ERRORLEVEL%
)

echo ERROR: Neither PowerShell nor Node.js found. Please install one of them.
exit /b 1

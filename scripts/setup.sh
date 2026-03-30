#!/bin/sh
# Apex Neural — Workspace Setup Script (Bash)
#
# Cross-platform bash setup for Linux and macOS.
# Mirrors the functionality of scripts/setup.js.
#
# Usage:
#   ./scripts/setup.sh
#   ./scripts/setup.sh --workspace /path/to/workspace

set -e

# ─── Colors ──────────────────────────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
CYAN="\033[36m"
RESET="\033[0m"

info()    { printf "${CYAN}ℹ${RESET}  %s\n" "$1"; }
success() { printf "${GREEN}✔${RESET}  %s\n" "$1"; }
warn()    { printf "${YELLOW}⚠${RESET}  %s\n" "$1"; }
error()   { printf "${RED}✖${RESET}  %s\n" "$1"; }

# ─── Resolve paths ───────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_GITHUB="$REPO_ROOT/.github"
SOURCE_README="$REPO_ROOT/README.md"
SOURCE_MCP_JSON="$REPO_ROOT/.vscode/mcp.json"
EXTENSION_DIR="$REPO_ROOT/extensions/apex-neural-memory"

# ─── Parse arguments ─────────────────────────────────────────────────────────
WORKSPACE_ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)
      shift
      WORKSPACE_ARG="$1"
      ;;
  esac
  shift
done

# ─── Validate sources ────────────────────────────────────────────────────────
if [ ! -d "$SOURCE_GITHUB" ]; then
  error ".github/ folder not found at: $SOURCE_GITHUB"
  error "Please run this script from the apex-neural repository root."
  exit 1
fi

if [ ! -f "$SOURCE_README" ]; then
  error "README.md not found at: $SOURCE_README"
  exit 1
fi

# ─── Banner ──────────────────────────────────────────────────────────────────
echo ""
printf "${BOLD}${CYAN}╔════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${CYAN}║       Apex Neural — Workspace Setup           ║${RESET}\n"
printf "${BOLD}${CYAN}╚════════════════════════════════════════════════╝${RESET}\n"
echo ""

# ─── Determine workspace ─────────────────────────────────────────────────────
DEFAULT_WORKSPACE="$(cd "$REPO_ROOT/.." && pwd)"

if [ -n "$WORKSPACE_ARG" ]; then
  WORKSPACE_ROOT="$WORKSPACE_ARG"
else
  printf "${BOLD}Workspace root directory (parent of all repos)${RESET} [%s]: " "$DEFAULT_WORKSPACE"
  read -r WORKSPACE_ROOT
  WORKSPACE_ROOT="${WORKSPACE_ROOT:-$DEFAULT_WORKSPACE}"
fi

# Resolve to absolute path
WORKSPACE_ROOT="$(cd "$WORKSPACE_ROOT" 2>/dev/null && pwd)" || {
  error "Workspace directory does not exist: $WORKSPACE_ROOT"
  exit 1
}

DEST_GITHUB="$WORKSPACE_ROOT/.github"
DEST_README="$DEST_GITHUB/apex-neural-README.md"
DEST_VSCODE="$WORKSPACE_ROOT/.vscode"
DEST_MCP_JSON="$DEST_VSCODE/mcp.json"

# Count source files
FILE_COUNT=$(find "$SOURCE_GITHUB" -type f | wc -l | tr -d ' ')

# ─── Summary ─────────────────────────────────────────────────────────────────
echo ""
info "The following actions will be performed:"
echo ""
printf "  ${BOLD}1.${RESET} Copy ${CYAN}.github/${RESET} → ${CYAN}%s${RESET}\n" "$DEST_GITHUB"
printf "     (%s files)\n" "$FILE_COUNT"
printf "  ${BOLD}2.${RESET} Copy ${CYAN}README.md${RESET} → ${CYAN}%s${RESET}\n" "$DEST_README"
printf "  ${BOLD}3.${RESET} Copy ${CYAN}.vscode/mcp.json${RESET} → ${CYAN}%s${RESET} (Playwright MCP server)\n" "$DEST_MCP_JSON"
printf "  ${BOLD}4.${RESET} Install VS Code extension: ${CYAN}apex-neural-memory${RESET}\n"
echo ""

if [ -d "$DEST_GITHUB" ]; then
  warn "$DEST_GITHUB already exists. Files will be overwritten."
  echo ""
fi

printf "${BOLD}Proceed with setup?${RESET} (y/n): "
read -r CONFIRM
case "$CONFIRM" in
  [yY]*) ;;
  *)
    info "Setup cancelled."
    exit 0
    ;;
esac

echo ""

# ─── Step 1: Copy .github/ ──────────────────────────────────────────────────
info "Copying .github/ folder..."
mkdir -p "$DEST_GITHUB"
cp -R "$SOURCE_GITHUB/"* "$DEST_GITHUB/"
success ".github/ copied to $DEST_GITHUB"

# ─── Step 2: Copy README ────────────────────────────────────────────────────
info "Copying README.md..."
cp "$SOURCE_README" "$DEST_README"
success "README.md copied as $DEST_README"

# ─── Step 3: Copy .vscode/mcp.json ─────────────────────────────────────────
if [ -f "$SOURCE_MCP_JSON" ]; then
  info "Copying .vscode/mcp.json (Playwright MCP server config)..."
  mkdir -p "$DEST_VSCODE"
  cp "$SOURCE_MCP_JSON" "$DEST_MCP_JSON"
  success ".vscode/mcp.json copied to $DEST_MCP_JSON"
else
  warn ".vscode/mcp.json not found in the repository — skipping MCP config."
fi

# ─── Step 4: Install extension ───────────────────────────────────────────────
VSIX_PATH=""
if [ -d "$EXTENSION_DIR" ]; then
  VSIX_PATH=$(find "$EXTENSION_DIR" -maxdepth 1 -name "*.vsix" -type f | head -1)
fi

if [ -z "$VSIX_PATH" ]; then
  warn "No .vsix file found in extensions/apex-neural-memory/."
  warn "Build it with: cd extensions/apex-neural-memory && npm run package"
else
  printf "${BOLD}Install the apex-neural-memory VS Code extension now?${RESET} (y/n): "
  read -r INSTALL_EXT
  case "$INSTALL_EXT" in
    [yY]*)
      info "Installing VS Code extension..."
      if code --install-extension "$VSIX_PATH" 2>/dev/null; then
        success "apex-neural-memory extension installed."
      else
        warn "Could not install the extension automatically."
        echo ""
        info "To install manually, run:"
        echo "     code --install-extension $VSIX_PATH"
      fi
      ;;
    *)
      info "Skipped extension installation."
      info "To install manually later, run:"
      echo "     code --install-extension $VSIX_PATH"
      ;;
  esac
fi

# ─── Done ────────────────────────────────────────────────────────────────────
echo ""
printf "${BOLD}${GREEN}╔════════════════════════════════════════════════╗${RESET}\n"
printf "${BOLD}${GREEN}║            Setup complete! 🚀                  ║${RESET}\n"
printf "${BOLD}${GREEN}╚════════════════════════════════════════════════╝${RESET}\n"
echo ""
info "Next steps:"
echo "  1. Open the workspace folder in VS Code"
echo "  2. Enable these settings in your VS Code settings:"
printf "     ${CYAN}\"chat.useCustomAgentHooks\": true${RESET}\n"
printf "     ${CYAN}\"chat.plugins.enabled\": true${RESET}\n"
echo "  3. Ensure the apex-neural-memory extension is installed"
printf "  4. Open VS Code Chat and select ${BOLD}Orchestrator${RESET} to get started\n"
echo ""
info "Alternative: Install as a VS Code Copilot agent plugin:"
printf "  Run ${CYAN}Chat: Install Plugin From Source${RESET} in the Command Palette\n"
printf "  and enter: ${CYAN}https://github.com/TheJagpreet/apex-neural${RESET}\n"
echo ""

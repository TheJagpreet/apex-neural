#!/usr/bin/env bash
# Session initialization hook — injects project context and memory digest into the agent session
set -euo pipefail

# Read input from stdin
INPUT=$(cat)

CWD=$(echo "$INPUT" | jq -r '.cwd // empty')

# Build project context
CONTEXT=""

# Detect project type
if [ -f "${CWD}/package.json" ]; then
  PROJECT_NAME=$(jq -r '.name // "unknown"' "${CWD}/package.json" 2>/dev/null)
  PROJECT_VERSION=$(jq -r '.version // "unknown"' "${CWD}/package.json" 2>/dev/null)
  CONTEXT="${CONTEXT}Project: ${PROJECT_NAME} v${PROJECT_VERSION} (Node.js) | "
elif [ -f "${CWD}/Cargo.toml" ]; then
  CONTEXT="${CONTEXT}Project: Rust (Cargo) | "
elif [ -f "${CWD}/pyproject.toml" ] || [ -f "${CWD}/setup.py" ]; then
  CONTEXT="${CONTEXT}Project: Python | "
elif [ -f "${CWD}/go.mod" ]; then
  CONTEXT="${CONTEXT}Project: Go | "
fi

# Get git info
if command -v git &>/dev/null && [ -d "${CWD}/.git" ]; then
  BRANCH=$(git -C "${CWD}" branch --show-current 2>/dev/null || echo "unknown")
  CONTEXT="${CONTEXT}Branch: ${BRANCH} | "
fi

# Check for existing session memory (resume support)
RESUME_INFO=""
if [ -f "${CWD}/.github/agents/session-state.md" ]; then
  RESUME_INFO="Previous session state found. Check .github/memory/ for continuity."
fi

# Check for any existing plans in the new memory system
PLAN_STATUS=""
if [ -d "${CWD}/.github/memory/planner" ]; then
  LATEST_PLAN=$(find "${CWD}/.github/memory/planner" -name "current-plan-*.md" -not -name "TEMPLATE.md" -type f 2>/dev/null | sort -r | head -1)
  if [ -n "$LATEST_PLAN" ]; then
    PLAN_STATUS="Active plan found in memory. Resume or start fresh: ${LATEST_PLAN}"
  fi
fi

# --- Memory-Aware Enhancements ---

MEMORY_DIR="${CWD}/.github/memory"
MEMORY_CONTEXT=""

# 1. Load project context summary from base memory
if [ -f "${MEMORY_DIR}/base/project-context.md" ]; then
  # Extract the Overview section (first ~5 lines after ## Overview)
  PROJECT_SUMMARY=$(sed -n '/^## Overview/,/^## /{/^## Overview/d;/^## /d;p}' "${MEMORY_DIR}/base/project-context.md" | head -5 | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-300)
  if [ -n "$PROJECT_SUMMARY" ]; then
    MEMORY_CONTEXT="${MEMORY_CONTEXT}Project context: ${PROJECT_SUMMARY} | "
  fi
fi

# 2. Scan recent memories (last 10) across all agent folders and build a digest
RECENT_WORK=""
RECENT_COUNT=0
if [ -d "$MEMORY_DIR" ]; then
  while IFS= read -r mem_file; do
    BASENAME=$(basename "$mem_file")
    # Skip templates, READMEs, and other non-memory files
    if [[ "$BASENAME" == "TEMPLATE.md" ]] || [[ "$BASENAME" == "README.md" ]] || [[ "$BASENAME" == "conventions-changelog.md" ]] || [[ "$BASENAME" == ".gitkeep" ]]; then
      continue
    fi

    # Extract task from YAML frontmatter
    if head -1 "$mem_file" | grep -q '^---$' 2>/dev/null; then
      TASK=$(sed -n '/^---$/,/^---$/p' "$mem_file" | grep '^task:' | sed 's/^task:[[:space:]]*//' | tr -d '"' | tr -d "'" | cut -c1-80)
      if [ -n "$TASK" ]; then
        RECENT_WORK="${RECENT_WORK}${TASK}, "
        RECENT_COUNT=$((RECENT_COUNT + 1))
      fi
    fi
  done < <(find "$MEMORY_DIR" -name "*.md" -not -path "*/archive/*" -not -path "*/base/*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -10 | awk '{print $2}')

  if [ -n "$RECENT_WORK" ]; then
    # Trim trailing comma and space
    RECENT_WORK="${RECENT_WORK%, }"
    MEMORY_CONTEXT="${MEMORY_CONTEXT}Recent work (${RECENT_COUNT} memories): [${RECENT_WORK}] | "
  fi
fi

# 3. Run memory maintenance scripts (pruning, indexing, health, conflict detection)
# These run quickly and maintain the memory system

# Prune old memories
if [ -x "${CWD}/.github/scripts/hooks/prune-memory.sh" ]; then
  bash "${CWD}/.github/scripts/hooks/prune-memory.sh" "$CWD" 2>/dev/null || true
fi

# Rebuild the memory index
if [ -x "${CWD}/.github/scripts/hooks/rebuild-memory-index.sh" ]; then
  bash "${CWD}/.github/scripts/hooks/rebuild-memory-index.sh" "$CWD" 2>/dev/null || true
fi

# Generate memory health report
if [ -x "${CWD}/.github/scripts/hooks/memory-health.sh" ]; then
  bash "${CWD}/.github/scripts/hooks/memory-health.sh" "$CWD" 2>/dev/null || true
fi

# Check for memory conflicts
CONFLICT_INFO=""
if [ -x "${CWD}/.github/scripts/hooks/detect-memory-conflicts.sh" ]; then
  CONFLICT_INFO=$(bash "${CWD}/.github/scripts/hooks/detect-memory-conflicts.sh" "$CWD" 2>/dev/null || echo "")
  if [ -n "$CONFLICT_INFO" ]; then
    MEMORY_CONTEXT="${MEMORY_CONTEXT}${CONFLICT_INFO} | "
  fi
fi

# 4. Report memory health summary
if [ -f "${MEMORY_DIR}/memory-health.json" ]; then
  HEALTH_STATUS=$(jq -r '.health_status // "unknown"' "${MEMORY_DIR}/memory-health.json" 2>/dev/null)
  TOTAL_MEMORIES=$(jq -r '.summary.total_active_memories // 0' "${MEMORY_DIR}/memory-health.json" 2>/dev/null)
  MEMORY_CONTEXT="${MEMORY_CONTEXT}Memory system: ${HEALTH_STATUS} (${TOTAL_MEMORIES} active memories) | "
fi

# --- Build final context ---

ADDITIONAL="${CONTEXT}${RESUME_INFO} ${PLAN_STATUS} ${MEMORY_CONTEXT}"
ADDITIONAL="${ADDITIONAL:-No project context detected.}"

# Output JSON response
jq -n --arg ctx "$ADDITIONAL" '{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $ctx
  }
}'

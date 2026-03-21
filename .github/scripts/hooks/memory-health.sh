#!/usr/bin/env bash
# Memory health metrics — generates memory-health.json with system stats
# Called from session-init.sh on SessionStart
set -uo pipefail

CWD="${1:-.}"
MEMORY_DIR="${CWD}/.github/memory"
HEALTH_FILE="${MEMORY_DIR}/memory-health.json"

if [ ! -d "$MEMORY_DIR" ]; then
  echo '{"status":"no_memory_dir"}' > "$HEALTH_FILE"
  exit 0
fi

NOW=$(date +%s)
NOW_ISO=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Agent directories to check
AGENT_DIRS=("orchestrator" "planner" "architect" "solutioner" "tester" "shared")

AGENT_STATS="[]"
TOTAL_FILES=0
TOTAL_ARCHIVED=0

for AGENT_DIR in "${AGENT_DIRS[@]}"; do
  AGENT_PATH="${MEMORY_DIR}/${AGENT_DIR}"

  if [ ! -d "$AGENT_PATH" ]; then
    continue
  fi

  # Count active memory files (excluding templates, READMEs, .gitkeep)
  FILE_COUNT=$(find "$AGENT_PATH" -maxdepth 1 -name "*.md" -type f \
    -not -name "TEMPLATE.md" -not -name "README.md" 2>/dev/null | wc -l)

  # Count archived files
  ARCHIVE_COUNT=0
  if [ -d "${AGENT_PATH}/archive" ]; then
    ARCHIVE_COUNT=$(find "${AGENT_PATH}/archive" -name "*.md" -type f 2>/dev/null | wc -l)
  fi

  # Find most recent memory file
  NEWEST_FILE=$(find "$AGENT_PATH" -maxdepth 1 -name "*.md" -type f \
    -not -name "TEMPLATE.md" -not -name "README.md" 2>/dev/null | \
    xargs -r ls -t 2>/dev/null | head -1)

  NEWEST_AGE_DAYS="-1"
  NEWEST_DATE=""
  if [ -n "$NEWEST_FILE" ]; then
    NEWEST_MTIME=$(stat -c '%Y' "$NEWEST_FILE" 2>/dev/null || stat -f '%m' "$NEWEST_FILE" 2>/dev/null || echo "0")
    NEWEST_AGE_DAYS=$(( (NOW - NEWEST_MTIME) / 86400 ))
    NEWEST_DATE=$(date -u -d "@${NEWEST_MTIME}" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -r "$NEWEST_MTIME" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || echo "unknown")
  fi

  # Count auto-capture vs manual files
  AUTO_COUNT=$(find "$AGENT_PATH" -maxdepth 1 -name "auto-capture-*.md" -type f 2>/dev/null | wc -l)
  MANUAL_COUNT=$((FILE_COUNT - AUTO_COUNT))

  # Staleness classification
  STALENESS="active"
  if [ "$NEWEST_AGE_DAYS" -eq -1 ]; then
    STALENESS="empty"
  elif [ "$NEWEST_AGE_DAYS" -gt 30 ]; then
    STALENESS="stale"
  elif [ "$NEWEST_AGE_DAYS" -gt 7 ]; then
    STALENESS="aging"
  fi

  TOTAL_FILES=$((TOTAL_FILES + FILE_COUNT))
  TOTAL_ARCHIVED=$((TOTAL_ARCHIVED + ARCHIVE_COUNT))

  # Build agent stats entry
  STAT=$(jq -n \
    --arg agent "$AGENT_DIR" \
    --argjson file_count "$FILE_COUNT" \
    --argjson archive_count "$ARCHIVE_COUNT" \
    --argjson auto_count "$AUTO_COUNT" \
    --argjson manual_count "$MANUAL_COUNT" \
    --arg newest_date "$NEWEST_DATE" \
    --argjson newest_age_days "$NEWEST_AGE_DAYS" \
    --arg staleness "$STALENESS" \
    '{
      agent: $agent,
      active_memories: $file_count,
      archived_memories: $archive_count,
      auto_captured: $auto_count,
      manually_created: $manual_count,
      newest_memory_date: $newest_date,
      newest_age_days: $newest_age_days,
      staleness: $staleness
    }')

  AGENT_STATS=$(echo "$AGENT_STATS" | jq --argjson stat "$STAT" '. + [$stat]')
done

# Check index health
INDEX_STATUS="missing"
INDEX_ENTRIES=0
if [ -f "${MEMORY_DIR}/index.json" ]; then
  INDEX_STATUS="present"
  INDEX_ENTRIES=$(jq '.entry_count // 0' "${MEMORY_DIR}/index.json" 2>/dev/null || echo 0)
fi

# Compaction recommendation
NEEDS_COMPACTION="false"
if [ "$TOTAL_FILES" -gt 50 ]; then
  NEEDS_COMPACTION="true"
fi

# Overall health status
HEALTH_STATUS="healthy"
STALE_COUNT=$(echo "$AGENT_STATS" | jq '[.[] | select(.staleness == "stale")] | length')
EMPTY_COUNT=$(echo "$AGENT_STATS" | jq '[.[] | select(.staleness == "empty")] | length')
if [ "$STALE_COUNT" -gt 2 ]; then
  HEALTH_STATUS="degraded"
fi
if [ "$TOTAL_FILES" -eq 0 ]; then
  HEALTH_STATUS="empty"
fi

# Write health report
jq -n \
  --arg generated_at "$NOW_ISO" \
  --arg health_status "$HEALTH_STATUS" \
  --argjson total_active "$TOTAL_FILES" \
  --argjson total_archived "$TOTAL_ARCHIVED" \
  --arg index_status "$INDEX_STATUS" \
  --argjson index_entries "$INDEX_ENTRIES" \
  --argjson needs_compaction "$NEEDS_COMPACTION" \
  --argjson stale_agents "$STALE_COUNT" \
  --argjson empty_agents "$EMPTY_COUNT" \
  --argjson agents "$AGENT_STATS" \
  '{
    generated_at: $generated_at,
    health_status: $health_status,
    summary: {
      total_active_memories: $total_active,
      total_archived_memories: $total_archived,
      index_status: $index_status,
      index_entries: $index_entries,
      needs_compaction: $needs_compaction,
      stale_agent_count: $stale_agents,
      empty_agent_count: $empty_agents
    },
    agents: $agents
  }' > "$HEALTH_FILE"

echo "Memory health report generated: status=${HEALTH_STATUS}, active=${TOTAL_FILES}, archived=${TOTAL_ARCHIVED}" >&2
exit 0

#!/usr/bin/env bash
# Memory pruning and compaction — manages memory lifecycle
# Called from session-init.sh on SessionStart
set -uo pipefail

CWD="${1:-.}"
MEMORY_DIR="${CWD}/.github/memory"

# Configuration
TTL_DAYS="${MEMORY_TTL_DAYS:-90}"       # Archive memories older than this
COMPACT_ENABLED="${MEMORY_COMPACT:-true}" # Enable tag-based compaction

# Ensure memory directory exists
if [ ! -d "$MEMORY_DIR" ]; then
  exit 0
fi

PRUNED=0
ARCHIVED=0

# Agent directories to process
AGENT_DIRS=("orchestrator" "planner" "architect" "solutioner" "tester" "shared")

for AGENT_DIR in "${AGENT_DIRS[@]}"; do
  AGENT_PATH="${MEMORY_DIR}/${AGENT_DIR}"
  if [ ! -d "$AGENT_PATH" ]; then
    continue
  fi

  # Create archive directory if needed
  ARCHIVE_PATH="${AGENT_PATH}/archive"

  # Find memories older than TTL_DAYS
  while IFS= read -r file; do
    BASENAME=$(basename "$file")

    # Skip templates, READMEs, and already-archived files
    if [[ "$BASENAME" == "TEMPLATE.md" ]] || [[ "$BASENAME" == "README.md" ]] || [[ "$BASENAME" == ".gitkeep" ]]; then
      continue
    fi

    # Check file age
    FILE_AGE_DAYS=$(( ($(date +%s) - $(stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file" 2>/dev/null || echo "0")) / 86400 ))

    if [ "$FILE_AGE_DAYS" -gt "$TTL_DAYS" ]; then
      # Move to archive
      mkdir -p "$ARCHIVE_PATH"
      mv "$file" "$ARCHIVE_PATH/"
      ARCHIVED=$((ARCHIVED + 1))
    fi
  done < <(find "$AGENT_PATH" -maxdepth 1 -name "*.md" -type f 2>/dev/null)
done

# Compaction: merge auto-capture files that were never enriched
if [ "$COMPACT_ENABLED" = "true" ]; then
  for AGENT_DIR in "${AGENT_DIRS[@]}"; do
    AGENT_PATH="${MEMORY_DIR}/${AGENT_DIR}"
    if [ ! -d "$AGENT_PATH" ]; then
      continue
    fi

    # Find auto-capture files that still have placeholder content
    # (they contain "Auto-generated memory capture" and were never enriched)
    STALE_AUTOCAPTURES=()
    while IFS= read -r file; do
      if grep -q "Auto-generated memory capture" "$file" 2>/dev/null; then
        # Check if it's older than 7 days (give time to enrich)
        FILE_AGE_DAYS=$(( ($(date +%s) - $(stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file" 2>/dev/null || echo "0")) / 86400 ))
        if [ "$FILE_AGE_DAYS" -gt 7 ]; then
          STALE_AUTOCAPTURES+=("$file")
        fi
      fi
    done < <(find "$AGENT_PATH" -maxdepth 1 -name "auto-capture-*.md" -type f 2>/dev/null)

    # If there are multiple stale auto-captures, compact them into one digest
    if [ "${#STALE_AUTOCAPTURES[@]}" -gt 2 ]; then
      COMPACT_TS=$(date -u '+%Y%m%d-%H%M%S')
      COMPACT_FILE="${AGENT_PATH}/compacted-digest-${COMPACT_TS}.md"
      AGENT_LOWER=$(echo "$AGENT_DIR" | tr '[:upper:]' '[:lower:]')
      MONTH=$(date -u '+%Y-%m')

      cat > "$COMPACT_FILE" << COMPACT_EOF
---
agent: ${AGENT_LOWER}
date: "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
task: "Compacted digest of ${#STALE_AUTOCAPTURES[@]} unenriched auto-captures"
tags: [compacted, digest, ${AGENT_LOWER}]
related_files: []
outcome: completed
confidence: low
supersedes: null
conflicts_with: null
continues: null
conversation_type: digest
---

# Compacted Digest: ${AGENT_DIR} (${MONTH})

${#STALE_AUTOCAPTURES[@]} auto-captured memories were compacted because they were not enriched within 7 days.

## Source Files
COMPACT_EOF

      for stale_file in "${STALE_AUTOCAPTURES[@]}"; do
        echo "- $(basename "$stale_file")" >> "$COMPACT_FILE"
        rm "$stale_file"
        PRUNED=$((PRUNED + 1))
      done

      echo "" >> "$COMPACT_FILE"
      echo "## Note" >> "$COMPACT_FILE"
      echo "These sessions completed without detailed memory capture. If important context was lost, check the audit log at \`.github/audit/subagent-trace.log\`." >> "$COMPACT_FILE"
    fi
  done
fi

if [ "$ARCHIVED" -gt 0 ] || [ "$PRUNED" -gt 0 ]; then
  echo "Memory pruning: archived=${ARCHIVED}, compacted=${PRUNED}" >&2
fi

exit 0

#!/usr/bin/env bash
# Rebuild memory index — scans all memory files and builds a searchable index.json
# Called from session-init.sh on SessionStart
set -uo pipefail

CWD="${1:-.}"
MEMORY_DIR="${CWD}/.github/memory"
INDEX_FILE="${MEMORY_DIR}/index.json"

# Ensure memory directory exists
if [ ! -d "$MEMORY_DIR" ]; then
  echo '{"entries":[],"rebuilt_at":"'$(date -u '+%Y-%m-%dT%H:%M:%SZ')'"}' > "$INDEX_FILE"
  exit 0
fi

# Start building the index
ENTRIES="[]"

# Find all .md files in memory subdirectories (skip README.md, TEMPLATE.md, and the index itself)
while IFS= read -r file; do
  # Skip non-memory files
  BASENAME=$(basename "$file")
  if [[ "$BASENAME" == "README.md" ]] || [[ "$BASENAME" == "TEMPLATE.md" ]] || [[ "$BASENAME" == "conventions-changelog.md" ]]; then
    continue
  fi

  # Extract relative path from memory dir
  REL_PATH="${file#${MEMORY_DIR}/}"

  # Determine agent from directory path
  AGENT_DIR=$(echo "$REL_PATH" | cut -d'/' -f1)

  # Try to extract YAML frontmatter fields
  AGENT=""
  DATE=""
  TASK=""
  TAGS="[]"
  OUTCOME=""
  CONFIDENCE=""
  SUPERSEDES="null"
  CONFLICTS_WITH="null"
  CONTINUES="null"
  CONVERSATION_TYPE=""
  RELATED_FILES="[]"

  # Check if file has YAML frontmatter (starts with ---)
  if head -1 "$file" | grep -q '^---$'; then
    # Extract frontmatter block (between first and second ---)
    FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')

    AGENT=$(echo "$FRONTMATTER" | grep '^agent:' | sed 's/^agent:[[:space:]]*//' | tr -d '"' | tr -d "'")
    DATE=$(echo "$FRONTMATTER" | grep '^date:' | sed 's/^date:[[:space:]]*//' | tr -d '"' | tr -d "'")
    TASK=$(echo "$FRONTMATTER" | grep '^task:' | sed 's/^task:[[:space:]]*//' | tr -d '"' | tr -d "'")
    OUTCOME=$(echo "$FRONTMATTER" | grep '^outcome:' | sed 's/^outcome:[[:space:]]*//' | tr -d '"' | tr -d "'")
    CONFIDENCE=$(echo "$FRONTMATTER" | grep '^confidence:' | sed 's/^confidence:[[:space:]]*//' | tr -d '"' | tr -d "'")
    CONVERSATION_TYPE=$(echo "$FRONTMATTER" | grep '^conversation_type:' | sed 's/^conversation_type:[[:space:]]*//' | tr -d '"' | tr -d "'")

    # Extract tags array: tags: [tag1, tag2, tag3]
    TAGS_RAW=$(echo "$FRONTMATTER" | grep '^tags:' | sed 's/^tags:[[:space:]]*//')
    if [ -n "$TAGS_RAW" ]; then
      TAGS=$(echo "$TAGS_RAW" | tr -d '[]' | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)
    fi

    # Extract related_files array
    RELATED_RAW=$(echo "$FRONTMATTER" | grep -A 50 '^related_files:' | tail -n +2 | grep '^\s*-' | sed 's/^\s*-\s*//' | head -20)
    if [ -n "$RELATED_RAW" ]; then
      RELATED_FILES=$(echo "$RELATED_RAW" | jq -R . | jq -s .)
    fi

    # Extract scalar nullable fields
    SUPERSEDES_RAW=$(echo "$FRONTMATTER" | grep '^supersedes:' | sed 's/^supersedes:[[:space:]]*//' | tr -d '"' | tr -d "'")
    if [ -n "$SUPERSEDES_RAW" ] && [ "$SUPERSEDES_RAW" != "null" ]; then
      SUPERSEDES="\"$SUPERSEDES_RAW\""
    fi

    CONFLICTS_RAW=$(echo "$FRONTMATTER" | grep '^conflicts_with:' | sed 's/^conflicts_with:[[:space:]]*//' | tr -d '"' | tr -d "'")
    if [ -n "$CONFLICTS_RAW" ] && [ "$CONFLICTS_RAW" != "null" ]; then
      CONFLICTS_WITH="\"$CONFLICTS_RAW\""
    fi

    CONTINUES_RAW=$(echo "$FRONTMATTER" | grep '^continues:' | sed 's/^continues:[[:space:]]*//' | tr -d '"' | tr -d "'")
    if [ -n "$CONTINUES_RAW" ] && [ "$CONTINUES_RAW" != "null" ]; then
      CONTINUES="\"$CONTINUES_RAW\""
    fi
  fi

  # Fallback: use directory name as agent if frontmatter didn't have it
  AGENT="${AGENT:-$AGENT_DIR}"

  # Extract first heading as title
  TITLE=$(grep '^# ' "$file" | head -1 | sed 's/^# //')
  TITLE="${TITLE:-$BASENAME}"

  # Get file modification time
  FILE_MTIME=$(stat -c '%Y' "$file" 2>/dev/null || stat -f '%m' "$file" 2>/dev/null || echo "0")

  # Build entry JSON
  ENTRY=$(jq -n \
    --arg path "$REL_PATH" \
    --arg agent "$AGENT" \
    --arg date "$DATE" \
    --arg task "$TASK" \
    --arg title "$TITLE" \
    --argjson tags "$TAGS" \
    --argjson related_files "$RELATED_FILES" \
    --arg outcome "$OUTCOME" \
    --arg confidence "$CONFIDENCE" \
    --argjson supersedes "$SUPERSEDES" \
    --argjson conflicts_with "$CONFLICTS_WITH" \
    --argjson continues "$CONTINUES" \
    --arg conversation_type "$CONVERSATION_TYPE" \
    --arg mtime "$FILE_MTIME" \
    '{
      path: $path,
      agent: $agent,
      date: $date,
      task: $task,
      title: $title,
      tags: $tags,
      related_files: $related_files,
      outcome: $outcome,
      confidence: $confidence,
      supersedes: $supersedes,
      conflicts_with: $conflicts_with,
      continues: $continues,
      conversation_type: $conversation_type,
      file_mtime: ($mtime | tonumber)
    }')

  ENTRIES=$(echo "$ENTRIES" | jq --argjson entry "$ENTRY" '. + [$entry]')

done < <(find "$MEMORY_DIR" -name "*.md" -not -path "*/archive/*" | sort)

# Write the index
REBUILT_AT=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
ENTRY_COUNT=$(echo "$ENTRIES" | jq 'length')

jq -n \
  --argjson entries "$ENTRIES" \
  --arg rebuilt_at "$REBUILT_AT" \
  --argjson count "$ENTRY_COUNT" \
  '{
    rebuilt_at: $rebuilt_at,
    entry_count: $count,
    entries: $entries
  }' > "$INDEX_FILE"

echo "Memory index rebuilt: ${ENTRY_COUNT} entries at ${REBUILT_AT}" >&2
exit 0

#!/usr/bin/env bash
# Detect memory conflicts — scans for unresolved conflicts_with fields
# Called from session-init.sh on SessionStart
set -uo pipefail

CWD="${1:-.}"
MEMORY_DIR="${CWD}/.github/memory"

if [ ! -d "$MEMORY_DIR" ]; then
  echo ""
  exit 0
fi

CONFLICTS=""
CONFLICT_COUNT=0

# Scan all memory files for conflicts_with that isn't null
while IFS= read -r file; do
  BASENAME=$(basename "$file")

  # Skip non-memory files
  if [[ "$BASENAME" == "README.md" ]] || [[ "$BASENAME" == "TEMPLATE.md" ]] || [[ "$BASENAME" == "conventions-changelog.md" ]] || [[ "$BASENAME" == ".gitkeep" ]]; then
    continue
  fi

  # Check if file has YAML frontmatter
  if ! head -1 "$file" | grep -q '^---$'; then
    continue
  fi

  # Extract conflicts_with field
  FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$file" | sed '1d;$d')
  CONFLICTS_WITH=$(echo "$FRONTMATTER" | grep '^conflicts_with:' | sed 's/^conflicts_with:[[:space:]]*//' | tr -d '"' | tr -d "'")

  if [ -n "$CONFLICTS_WITH" ] && [ "$CONFLICTS_WITH" != "null" ]; then
    REL_PATH="${file#${MEMORY_DIR}/}"
    TASK=$(echo "$FRONTMATTER" | grep '^task:' | sed 's/^task:[[:space:]]*//' | tr -d '"' | tr -d "'")

    CONFLICTS="${CONFLICTS}⚠ CONFLICT: '${REL_PATH}' conflicts with '${CONFLICTS_WITH}' — Task: ${TASK}\n"
    CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
  fi
done < <(find "$MEMORY_DIR" -name "*.md" -not -path "*/archive/*" | sort)

# Also check for potential implicit conflicts:
# memories with same tags but different outcomes (approved vs rejected)
# This is a lightweight heuristic check
INDEX_FILE="${MEMORY_DIR}/index.json"
IMPLICIT_CONFLICTS=""
if [ -f "$INDEX_FILE" ]; then
  # Find entries with outcome "rejected" or "blocked" that might conflict with "approved" entries
  REJECTED=$(jq -r '.entries[] | select(.outcome == "rejected" or .outcome == "blocked") | .path' "$INDEX_FILE" 2>/dev/null)
  if [ -n "$REJECTED" ]; then
    while IFS= read -r rejected_path; do
      REJECTED_TAGS=$(jq -r --arg path "$rejected_path" '.entries[] | select(.path == $path) | .tags | join(",")' "$INDEX_FILE" 2>/dev/null)
      # Check if any approved memory shares tags
      MATCHING=$(jq -r --arg path "$rejected_path" --arg tags "$REJECTED_TAGS" '
        .entries[]
        | select(.outcome == "approved" and .path != $path)
        | select(.tags | map(. as $t | ($tags | split(",") | index($t))) | any)
        | .path
      ' "$INDEX_FILE" 2>/dev/null | head -1)

      if [ -n "$MATCHING" ]; then
        IMPLICIT_CONFLICTS="${IMPLICIT_CONFLICTS}⚡ POTENTIAL: '${rejected_path}' (rejected/blocked) may conflict with '${MATCHING}' (approved) — shared tags\n"
        CONFLICT_COUNT=$((CONFLICT_COUNT + 1))
      fi
    done <<< "$REJECTED"
  fi
fi

# Output results
if [ "$CONFLICT_COUNT" -gt 0 ]; then
  echo -e "Found ${CONFLICT_COUNT} memory conflict(s):\n${CONFLICTS}${IMPLICIT_CONFLICTS}"
else
  echo ""
fi

exit 0

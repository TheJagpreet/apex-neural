#!/usr/bin/env bash
# Memory-to-skill pipeline — distills recurring patterns from memories into skill updates
# Run manually or periodically: .github/scripts/memory-to-skill.sh [cwd]
set -uo pipefail

CWD="${1:-.}"
MEMORY_DIR="${CWD}/.github/memory"
SKILLS_DIR="${CWD}/.github/skills"
INDEX_FILE="${MEMORY_DIR}/index.json"

if [ ! -f "$INDEX_FILE" ]; then
  echo "Error: Memory index not found. Run rebuild-memory-index.sh first." >&2
  exit 1
fi

if [ ! -d "$SKILLS_DIR" ]; then
  echo "Error: Skills directory not found at ${SKILLS_DIR}" >&2
  exit 1
fi

echo "=== Memory → Skill Pipeline ==="
echo "Analyzing memory patterns for skill enrichment..."
echo ""

# 1. Extract tag frequency across all memories
echo "## Tag Frequency Analysis"
echo ""
TAG_FREQ=$(jq -r '.entries[].tags[]' "$INDEX_FILE" 2>/dev/null | sort | uniq -c | sort -rn)
echo "$TAG_FREQ"
echo ""

# 2. Find recurring patterns per agent
echo "## Recurring Patterns by Agent"
echo ""

AGENT_DIRS=("orchestrator" "planner" "architect" "solutioner" "tester")
SKILL_MAP=(
  "architect:implementation-patterns"
  "solutioner:implementation-patterns"
  "tester:test-strategy"
  "planner:codebase-analysis"
)

for mapping in "${SKILL_MAP[@]}"; do
  AGENT="${mapping%%:*}"
  SKILL="${mapping##*:}"

  echo "### ${AGENT} → ${SKILL}"

  # Count memories for this agent
  MEMORY_COUNT=$(jq --arg agent "$AGENT" '[.entries[] | select(.agent == $agent)] | length' "$INDEX_FILE" 2>/dev/null)
  echo "  Memories: ${MEMORY_COUNT}"

  if [ "$MEMORY_COUNT" -lt 3 ]; then
    echo "  Status: Insufficient data (need at least 3 memories for pattern extraction)"
    echo ""
    continue
  fi

  # Extract common tags for this agent
  AGENT_TAGS=$(jq -r --arg agent "$AGENT" '.entries[] | select(.agent == $agent) | .tags[]' "$INDEX_FILE" 2>/dev/null | sort | uniq -c | sort -rn | head -5)
  echo "  Top tags: "
  echo "$AGENT_TAGS" | while read -r count tag; do
    echo "    - ${tag} (${count} occurrences)"
  done

  # Find repeated outcomes
  OUTCOMES=$(jq -r --arg agent "$AGENT" '.entries[] | select(.agent == $agent) | .outcome' "$INDEX_FILE" 2>/dev/null | sort | uniq -c | sort -rn)
  echo "  Outcomes:"
  echo "$OUTCOMES" | while read -r count outcome; do
    echo "    - ${outcome}: ${count}"
  done

  # Extract patterns from memory files (look for "Patterns Discovered" or "Gotchas" sections)
  echo "  Extractable patterns:"
  AGENT_PATH="${MEMORY_DIR}/${AGENT}"
  if [ -d "$AGENT_PATH" ]; then
    PATTERN_COUNT=0
    while IFS= read -r file; do
      BASENAME=$(basename "$file")
      if [[ "$BASENAME" == "TEMPLATE.md" ]] || [[ "$BASENAME" == "README.md" ]]; then
        continue
      fi

      # Look for pattern/gotcha/trick sections
      PATTERNS=$(grep -A 3 '## Patterns Discovered\|## Gotchas Found\|## Implementation Tricks\|## Design Decisions' "$file" 2>/dev/null | grep '^- ' | head -3)
      if [ -n "$PATTERNS" ]; then
        echo "$PATTERNS" | while IFS= read -r line; do
          echo "    ${line} (from: ${BASENAME})"
          PATTERN_COUNT=$((PATTERN_COUNT + 1))
        done
      fi
    done < <(find "$AGENT_PATH" -maxdepth 1 -name "*.md" -type f 2>/dev/null | sort -r | head -10)
  fi

  # Check if skill file needs update
  SKILL_FILE="${SKILLS_DIR}/${SKILL}/SKILL.md"
  if [ -f "$SKILL_FILE" ]; then
    SKILL_SIZE=$(wc -l < "$SKILL_FILE")
    echo "  Skill file: ${SKILL_FILE} (${SKILL_SIZE} lines)"
    echo "  Recommendation: Review patterns above and manually update skill if recurring themes emerge"
  fi

  echo ""
done

# 3. Generate a summary of potential skill updates
echo "## Skill Update Recommendations"
echo ""
echo "To enrich skills with accumulated memory patterns:"
echo "1. Review the patterns extracted above"
echo "2. Identify recurring themes (3+ occurrences)"
echo "3. Add project-specific guidance to the relevant SKILL.md file"
echo "4. Patterns should be generalized (not task-specific) before adding to skills"
echo ""
echo "This pipeline is advisory — human review is required before modifying skills."
echo ""
echo "=== Pipeline Complete ==="

exit 0

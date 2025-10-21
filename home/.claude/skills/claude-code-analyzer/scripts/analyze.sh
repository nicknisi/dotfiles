#!/usr/bin/env bash
set -euo pipefail

# Claude Code History Analyzer - Fixed Version
# Key fixes:
# 1. Simplified jq syntax (remove != null checks)
# 2. Better error handling for empty results
# 3. Validate temp files before JSON generation
# 4. More robust file processing

# Parse arguments
CURRENT_PROJECT_ONLY=false
SINGLE_FILE=""
SETTINGS_FILE="${HOME}/.claude/settings.json"
DISCOVER_GITHUB=true

while [[ $# -gt 0 ]]; do
  case $1 in
  --current-project)
    CURRENT_PROJECT_ONLY=true
    shift
    ;;
  --file)
    SINGLE_FILE="$2"
    shift 2
    ;;
  --discover-github)
    DISCOVER_GITHUB=true
    shift
    ;;
  *)
    shift
    ;;
  esac
done

CLAUDE_PROJECTS_DIR="${HOME}/.claude/projects"

# Colors for status output (to stderr)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if jq is installed
if ! command -v jq &>/dev/null; then
  echo -e "${RED}Error: jq is required but not installed${NC}" >&2
  echo "Install with: brew install jq (macOS) or apt install jq (Linux)" >&2
  exit 1
fi

# Create temporary files for aggregation
TEMP_DIR=$(mktemp -d)
TOOLS_FILE="$TEMP_DIR/tools.txt"
PROJECTS_FILE="$TEMP_DIR/projects.txt"
MODELS_FILE="$TEMP_DIR/models.txt"
AUTO_ALLOWED_FILE="$TEMP_DIR/auto_allowed.txt"

# Cleanup on exit
trap "rm -rf '$TEMP_DIR'" EXIT

# Read existing auto-allowed tools from settings
if [ -f "$SETTINGS_FILE" ]; then
  jq -r '.autoAllowedTools[]? // empty' "$SETTINGS_FILE" 2>/dev/null | sort >"$AUTO_ALLOWED_FILE" || touch "$AUTO_ALLOWED_FILE"
else
  touch "$AUTO_ALLOWED_FILE"
fi

echo -e "${BLUE}Claude Code History Analyzer${NC}" >&2
echo -e "${BLUE}=============================${NC}\n" >&2

# Determine which files to analyze
if [ -n "$SINGLE_FILE" ]; then
  if [ ! -f "$SINGLE_FILE" ]; then
    echo -e "${RED}Error: File not found: $SINGLE_FILE${NC}" >&2
    exit 1
  fi
  echo -e "Analyzing single file: ${GREEN}$(basename "$SINGLE_FILE")${NC}\n" >&2
  FILES_TO_ANALYZE=("$SINGLE_FILE")
  SCOPE="single_file"
  SCOPE_DETAIL="$(basename "$SINGLE_FILE")"

elif [ "$CURRENT_PROJECT_ONLY" = true ]; then
  CURRENT_DIR=$(pwd)
  PROJECT_PATH=$(echo "$CURRENT_DIR" | sed 's/\//-/g')
  PROJECT_DIR="${CLAUDE_PROJECTS_DIR}/${PROJECT_PATH}"

  if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${RED}Error: No Claude Code history found for current project${NC}" >&2
    echo -e "Looking for: $PROJECT_DIR" >&2
    exit 1
  fi

  echo -e "Analyzing current project: ${GREEN}${CURRENT_DIR}${NC}\n" >&2
  mapfile -t FILES_TO_ANALYZE < <(find "$PROJECT_DIR" -name "*.jsonl" 2>/dev/null)
  SCOPE="current_project"
  SCOPE_DETAIL="$CURRENT_DIR"

else
  if [ ! -d "$CLAUDE_PROJECTS_DIR" ]; then
    echo -e "${RED}Error: Claude Code projects directory not found at $CLAUDE_PROJECTS_DIR${NC}" >&2
    exit 1
  fi

  mapfile -t FILES_TO_ANALYZE < <(find "$CLAUDE_PROJECTS_DIR" -name "*.jsonl" 2>/dev/null)
  SCOPE="all_projects"
  SCOPE_DETAIL=""
fi

TOTAL_FILES=${#FILES_TO_ANALYZE[@]}
echo -e "Found ${GREEN}${TOTAL_FILES}${NC} conversation file(s)\n" >&2

if [ "$TOTAL_FILES" -eq 0 ]; then
  echo -e "${RED}No conversation files found${NC}" >&2
  exit 1
fi

# Extract all tool usage - FIXED: Simplified jq syntax
echo -e "${YELLOW}Extracting tool usage...${NC}" >&2
for file in "${FILES_TO_ANALYZE[@]}"; do
  # Process one file at a time to avoid memory issues
  jq -r 'select(.message.content) | .message.content[] | select(.type == "tool_use") | .name' "$file" 2>/dev/null || true
done | sort | uniq -c | sort -rn >"$TOOLS_FILE"

# Check if we got any results
if [ ! -s "$TOOLS_FILE" ]; then
  echo -e "${YELLOW}Warning: No tool usage found in conversation files${NC}" >&2
  touch "$TOOLS_FILE" # Create empty file to continue
fi

# Extract project paths (only if analyzing all projects)
if [ "$CURRENT_PROJECT_ONLY" = false ] && [ -z "$SINGLE_FILE" ]; then
  echo -e "${YELLOW}Extracting project distribution...${NC}" >&2
  find "$CLAUDE_PROJECTS_DIR" -type d -mindepth 1 -maxdepth 1 2>/dev/null |
    while read -r dir; do
      count=$(find "$dir" -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')
      basename=$(basename "$dir")
      echo "$count $basename"
    done | sort -rn >"$PROJECTS_FILE"
fi

# Extract model usage - FIXED: Simplified jq syntax
echo -e "${YELLOW}Extracting model usage...${NC}" >&2
for file in "${FILES_TO_ANALYZE[@]}"; do
  jq -r 'select(.message.model) | .message.model' "$file" 2>/dev/null || true
done | sort | uniq -c | sort -rn >"$MODELS_FILE"

# Check if we got any results
if [ ! -s "$MODELS_FILE" ]; then
  echo -e "${YELLOW}Warning: No model usage found in conversation files${NC}" >&2
  touch "$MODELS_FILE"
fi

echo -e "${GREEN}✓ Data extraction complete!${NC}\n" >&2
echo -e "${BLUE}Outputting structured data for analysis...${NC}\n" >&2

# Output structured data as JSON for Claude to interpret
cat <<EOF
{
  "metadata": {
    "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")",
    "scope": "$SCOPE",
    "scope_detail": "$SCOPE_DETAIL",
    "total_conversations": $TOTAL_FILES
  },
  "tool_usage": [
EOF

# Tool usage array - FIXED: Handle empty file
if [ -s "$TOOLS_FILE" ]; then
  first=true
  while read -r count tool; do
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    # Escape tool name for JSON
    tool_escaped=$(echo "$tool" | sed 's/"/\\"/g')
    printf '    {"tool": "%s", "count": %d}' "$tool_escaped" "$count"
  done <"$TOOLS_FILE"
  echo ""
fi

cat <<EOF
  ],
  "auto_allowed_tools": [
EOF

# Auto-allowed tools array - FIXED: Handle empty file
if [ -s "$AUTO_ALLOWED_FILE" ]; then
  first=true
  while read -r tool; do
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    tool_escaped=$(echo "$tool" | sed 's/"/\\"/g')
    usage=$(grep -w "$tool" "$TOOLS_FILE" 2>/dev/null | awk '{print $1}' || echo "0")
    printf '    {"tool": "%s", "usage_count": %d}' "$tool_escaped" "$usage"
  done <"$AUTO_ALLOWED_FILE"
  echo ""
fi

cat <<EOF
  ],
  "model_usage": [
EOF

# Model usage array - FIXED: Handle empty file
if [ -s "$MODELS_FILE" ]; then
  first=true
  while read -r count model; do
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    model_escaped=$(echo "$model" | sed 's/"/\\"/g')
    printf '    {"model": "%s", "count": %d}' "$model_escaped" "$count"
  done <"$MODELS_FILE"
  echo ""
fi

echo "  ]"

# Add project activity if available
if [ "$CURRENT_PROJECT_ONLY" = false ] && [ -z "$SINGLE_FILE" ] && [ -s "$PROJECTS_FILE" ]; then
  cat <<EOF
,
  "project_activity": [
EOF

  first=true
  while read -r count project; do
    if [ "$first" = true ]; then
      first=false
    else
      echo ","
    fi
    # Decode project path
    project_decoded=$(echo "$project" | sed 's/-/\//g' | sed 's/^/~/')
    project_escaped=$(echo "$project_decoded" | sed 's/"/\\"/g')
    printf '    {"project": "%s", "conversations": %d}' "$project_escaped" "$count"
  done <"$PROJECTS_FILE"

  echo ""
  echo "  ]"
fi

echo "}"

# Add GitHub discovery data if requested
if [ "$DISCOVER_GITHUB" = true ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  echo -e "\n${BLUE}Running GitHub discovery...${NC}" >&2

  # Run GitHub discovery and capture output
  if [ -f "$SCRIPT_DIR/github-discovery.sh" ]; then
    # FIXED: Only add JSON continuation if GitHub discovery succeeds
    if output=$(bash "$SCRIPT_DIR/github-discovery.sh" all 2>/dev/null); then
      echo ","
      echo '"github_discovery": '
      echo "$output"
    else
      echo -e "${YELLOW}Warning: GitHub discovery failed or returned no results${NC}" >&2
    fi
  else
    echo -e "${YELLOW}Warning: github-discovery.sh not found${NC}" >&2
  fi
fi

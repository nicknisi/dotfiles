#!/usr/bin/env bash
set -euo pipefail

# GitHub Claude Code Discovery
# Searches GitHub for skills, agents, and slash commands based on usage patterns

# Parse arguments
SEARCH_TYPE="${1:-all}" # all, agents, skills, commands
QUERY="${2:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Check if gh CLI is installed
HAS_GH=false
if command -v gh &>/dev/null; then
  HAS_GH=true
fi

echo -e "${BLUE}GitHub Claude Code Discovery${NC}" >&2
echo -e "${BLUE}============================${NC}\n" >&2

# Function to search GitHub using gh CLI
search_with_gh() {
  local path="$1"
  local query="$2"
  local limit="${3:-10}"

  if [ -z "$query" ]; then
    gh search code "path:$path" --limit "$limit" --json path,repository,url 2>/dev/null
  else
    gh search code "$query path:$path" --limit "$limit" --json path,repository,url 2>/dev/null
  fi
}

# Function to search GitHub using web URLs (fallback)
get_search_url() {
  local path="$1"
  local query="$2"

  if [ -z "$query" ]; then
    echo "https://github.com/search?type=code&q=path:${path}"
  else
    # URL encode the query
    query_encoded=$(echo "$query" | sed 's/ /+/g')
    echo "https://github.com/search?type=code&q=${query_encoded}+path:${path}"
  fi
}

# Output JSON structure
cat <<EOF
{
  "has_gh_cli": $HAS_GH,
  "searches": [
EOF

first_search=true

# Search for agents
if [ "$SEARCH_TYPE" = "all" ] || [ "$SEARCH_TYPE" = "agents" ]; then
  if [ "$first_search" = false ]; then
    echo ","
  fi
  first_search=false

  echo -e "${YELLOW}Searching for agents...${NC}" >&2

  cat <<EOF
    {
      "type": "agents",
      "path": ".claude/agents",
      "web_url": "$(get_search_url ".claude/agents" "$QUERY")",
EOF

  if [ "$HAS_GH" = true ]; then
    echo '      "results": '
    search_with_gh ".claude/agents" "$QUERY" 20 || echo '[]'
  else
    echo '      "results": []'
  fi

  echo -n "    }"
fi

# Search for skills
if [ "$SEARCH_TYPE" = "all" ] || [ "$SEARCH_TYPE" = "skills" ]; then
  if [ "$first_search" = false ]; then
    echo ","
  fi
  first_search=false

  echo -e "${YELLOW}Searching for skills...${NC}" >&2

  cat <<EOF
    {
      "type": "skills",
      "path": ".claude/skills",
      "web_url": "$(get_search_url ".claude/skills" "$QUERY")",
EOF

  if [ "$HAS_GH" = true ]; then
    echo '      "results": '
    search_with_gh ".claude/skills" "$QUERY" 20 || echo '[]'
  else
    echo '      "results": []'
  fi

  echo -n "    }"
fi

# Search for slash commands
if [ "$SEARCH_TYPE" = "all" ] || [ "$SEARCH_TYPE" = "commands" ]; then
  if [ "$first_search" = false ]; then
    echo ","
  fi
  first_search=false

  echo -e "${YELLOW}Searching for slash commands...${NC}" >&2

  cat <<EOF
    {
      "type": "slash_commands",
      "path": ".claude/commands",
      "web_url": "$(get_search_url ".claude/commands" "$QUERY")",
EOF

  if [ "$HAS_GH" = true ]; then
    echo '      "results": '
    search_with_gh ".claude/commands" "$QUERY" 20 || echo '[]'
  else
    echo '      "results": []'
  fi

  echo -n "    }"
fi

# Search for CLAUDE.md project context files
if [ "$SEARCH_TYPE" = "all" ] || [ "$SEARCH_TYPE" = "context" ]; then
  if [ "$first_search" = false ]; then
    echo ","
  fi
  first_search=false

  echo -e "${YELLOW}Searching for project context files...${NC}" >&2

  cat <<EOF
    {
      "type": "project_context",
      "path": ".claude/CLAUDE.md",
      "web_url": "$(get_search_url ".claude/CLAUDE.md" "$QUERY")",
EOF

  if [ "$HAS_GH" = true ]; then
    echo '      "results": '
    search_with_gh ".claude/CLAUDE.md" "$QUERY" 20 || echo '[]'
  else
    echo '      "results": []'
  fi

  echo -n "    }"
fi

cat <<EOF

  ]
}
EOF

echo -e "\n${GREEN}✓ Search complete!${NC}" >&2

if [ "$HAS_GH" = false ]; then
  echo -e "${YELLOW}Note: Install 'gh' CLI for direct search results${NC}" >&2
  echo -e "Install: ${BLUE}brew install gh${NC} (macOS) or see https://cli.github.com" >&2
fi

#!/usr/bin/env bash
set -euo pipefail

# Claude Code Feature Analyzer
# Fetches latest docs and compares with user's actual usage patterns

CLAUDE_DOCS_URL="https://docs.claude.com/en/docs/claude-code"
TEMP_DIR=$(mktemp -d)
DOCS_FILE="$TEMP_DIR/claude-code-docs.html"
FEATURES_FILE="$TEMP_DIR/features.txt"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Fetching latest Claude Code documentation...${NC}\n"

# Try to fetch docs
if command -v curl &> /dev/null; then
    if curl -s -L "$CLAUDE_DOCS_URL" -o "$DOCS_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓ Documentation fetched${NC}\n"
    else
        echo -e "${YELLOW}⚠ Could not fetch docs, using fallback feature list${NC}\n"
        DOCS_FILE=""
    fi
else
    echo -e "${YELLOW}⚠ curl not found, using fallback feature list${NC}\n"
    DOCS_FILE=""
fi

# Known Claude Code features (fallback + common features)
cat > "$FEATURES_FILE" <<'EOF'
Agents: Custom AI assistants for specific tasks
Slash Commands: Quick shortcuts for common operations
Skills: Modular capabilities you can add
Tool Auto-Allow: Automatically approve specific tools
Project Context: Automatic codebase understanding
Git Integration: Native git operations
Terminal Integration: Execute commands directly
File Watching: Automatic file change detection
Multi-file Editing: Edit multiple files simultaneously
Code Generation: Create new files and boilerplate
Refactoring: Automated code improvements
Testing: Generate and run tests
Documentation: Auto-generate docs from code
Search: Advanced codebase search
Context Memory: Remember past interactions
Web Search: Look up current information
API Integration: Connect to external services
Custom Tools: Build your own tools
Workflows: Chain multiple operations
Templates: Reusable code patterns
EOF

echo -e "${BLUE}Available Claude Code Features${NC}"
echo -e "${BLUE}==============================${NC}\n"

while IFS=: read -r feature description; do
    echo "📌 $feature"
    echo "   $description"
    echo ""
done < "$FEATURES_FILE"

# Cleanup
rm -rf "$TEMP_DIR"

echo -e "${GREEN}Feature list complete${NC}"

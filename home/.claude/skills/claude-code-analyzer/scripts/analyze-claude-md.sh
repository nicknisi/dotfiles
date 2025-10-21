#!/bin/bash

# Analyze project and suggest CLAUDE.md improvements
# Usage: bash scripts/analyze-claude-md.sh [project-path]

set -e

PROJECT_PATH="${1:-.}"

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Project path not found: $PROJECT_PATH"
    exit 1
fi

cd "$PROJECT_PATH"

echo "{"
echo '  "project_path": "'"$(pwd)"'",'
echo '  "timestamp": "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'",'

# Check if CLAUDE.md exists
if [ -f ".claude/CLAUDE.md" ]; then
    echo '  "claude_md_exists": true,'
    echo '  "claude_md_location": ".claude/CLAUDE.md",'
    echo '  "claude_md_size": '"$(wc -l < .claude/CLAUDE.md)"','
else
    echo '  "claude_md_exists": false,'
fi

# Detect package manager and commands
echo '  "detected_package_manager": {'

if [ -f "package.json" ]; then
    echo '    "type": "npm",'
    echo '    "has_package_json": true,'
    
    # Extract scripts
    if command -v jq &> /dev/null && [ -f "package.json" ]; then
        SCRIPTS=$(jq -r '.scripts | keys[]' package.json 2>/dev/null | head -20)
        if [ -n "$SCRIPTS" ]; then
            echo '    "scripts": ['
            echo "$SCRIPTS" | while IFS= read -r script; do
                echo "      \"$script\","
            done | sed '$ s/,$//'
            echo '    ],'
        fi
    fi
    
    if [ -f "pnpm-lock.yaml" ]; then
        echo '    "lockfile": "pnpm"'
    elif [ -f "yarn.lock" ]; then
        echo '    "lockfile": "yarn"'
    elif [ -f "package-lock.json" ]; then
        echo '    "lockfile": "npm"'
    else
        echo '    "lockfile": "none"'
    fi
elif [ -f "Cargo.toml" ]; then
    echo '    "type": "cargo",'
    echo '    "has_cargo_toml": true'
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    echo '    "type": "python",'
    if [ -f "pyproject.toml" ]; then
        echo '    "has_pyproject": true'
    else
        echo '    "has_requirements": true'
    fi
elif [ -f "go.mod" ]; then
    echo '    "type": "go",'
    echo '    "has_go_mod": true'
else
    echo '    "type": "unknown"'
fi

echo '  },'

# Detect testing framework
echo '  "testing": {'

if [ -f "package.json" ]; then
    if grep -q '"vitest"' package.json 2>/dev/null; then
        echo '    "framework": "vitest"'
    elif grep -q '"jest"' package.json 2>/dev/null; then
        echo '    "framework": "jest"'
    elif grep -q '"mocha"' package.json 2>/dev/null; then
        echo '    "framework": "mocha"'
    else
        echo '    "framework": "unknown"'
    fi
elif [ -f "pytest.ini" ] || grep -r "pytest" . 2>/dev/null | head -1 &> /dev/null; then
    echo '    "framework": "pytest"'
elif [ -f "Cargo.toml" ]; then
    echo '    "framework": "cargo test"'
elif [ -f "go.mod" ]; then
    echo '    "framework": "go test"'
else
    echo '    "framework": "unknown"'
fi

echo '  },'

# Detect framework
echo '  "framework": {'

if [ -f "package.json" ]; then
    if grep -q '"next"' package.json 2>/dev/null; then
        echo '    "type": "nextjs"'
    elif grep -q '"react"' package.json 2>/dev/null; then
        echo '    "type": "react"'
    elif grep -q '"vue"' package.json 2>/dev/null; then
        echo '    "type": "vue"'
    elif grep -q '"@angular/core"' package.json 2>/dev/null; then
        echo '    "type": "angular"'
    elif grep -q '"express"' package.json 2>/dev/null; then
        echo '    "type": "express"'
    elif grep -q '"fastify"' package.json 2>/dev/null; then
        echo '    "type": "fastify"'
    else
        echo '    "type": "unknown"'
    fi
elif [ -f "Cargo.toml" ]; then
    if grep -q "actix-web" Cargo.toml 2>/dev/null; then
        echo '    "type": "actix-web"'
    elif grep -q "rocket" Cargo.toml 2>/dev/null; then
        echo '    "type": "rocket"'
    else
        echo '    "type": "rust"'
    fi
elif [ -f "requirements.txt" ] || [ -f "pyproject.toml" ]; then
    if grep -r "django" . 2>/dev/null | head -1 &> /dev/null; then
        echo '    "type": "django"'
    elif grep -r "flask" . 2>/dev/null | head -1 &> /dev/null; then
        echo '    "type": "flask"'
    elif grep -r "fastapi" . 2>/dev/null | head -1 &> /dev/null; then
        echo '    "type": "fastapi"'
    else
        echo '    "type": "python"'
    fi
else
    echo '    "type": "unknown"'
fi

echo '  },'

# Check for common files
echo '  "project_files": {'
echo '    "has_readme": '"$([ -f "README.md" ] && echo "true" || echo "false")"','
echo '    "has_dockerfile": '"$([ -f "Dockerfile" ] && echo "true" || echo "false")"','
echo '    "has_ci": '"$([ -d ".github/workflows" ] || [ -f ".gitlab-ci.yml" ] || [ -f ".circleci/config.yml" ] && echo "true" || echo "false")"','
echo '    "has_gitignore": '"$([ -f ".gitignore" ] && echo "true" || echo "false")"','
echo '    "has_editorconfig": '"$([ -f ".editorconfig" ] && echo "true" || echo "false")"''
echo '  },'

# Directory structure
echo '  "directory_structure": {'

DIRS_TO_CHECK=("src" "lib" "app" "pages" "components" "api" "tests" "test" "__tests__" "scripts" "docs")
FOUND_DIRS=""

for dir in "${DIRS_TO_CHECK[@]}"; do
    if [ -d "$dir" ]; then
        FOUND_DIRS="$FOUND_DIRS\"$dir\", "
    fi
done

if [ -n "$FOUND_DIRS" ]; then
    echo '    "key_directories": ['"${FOUND_DIRS%, }"']'
else
    echo '    "key_directories": []'
fi

echo '  },'

# Suggest CLAUDE.md improvements
echo '  "claude_md_suggestions": ['

SUGGESTIONS=()

# Check for package.json scripts
if [ -f "package.json" ] && command -v jq &> /dev/null; then
    SCRIPTS=$(jq -r '.scripts | keys[]' package.json 2>/dev/null)
    if [ -n "$SCRIPTS" ]; then
        SUGGESTIONS+=('    "Document npm scripts (dev, build, test, lint) in CLAUDE.md"')
    fi
fi

# Check for testing
if [ -f "package.json" ]; then
    if grep -q '"vitest"' package.json 2>/dev/null || grep -q '"jest"' package.json 2>/dev/null; then
        SUGGESTIONS+=('    "Document testing approach and test commands"')
    fi
fi

# Check for TypeScript
if [ -f "tsconfig.json" ]; then
    SUGGESTIONS+=('    "Document TypeScript configuration and type checking commands"')
fi

# Check for linting
if [ -f ".eslintrc" ] || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ]; then
    SUGGESTIONS+=('    "Document linting rules and lint commands"')
fi

# Check for Docker
if [ -f "Dockerfile" ]; then
    SUGGESTIONS+=('    "Document Docker build and run commands"')
fi

# Check for environment variables
if [ -f ".env.example" ] || [ -f ".env.local.example" ]; then
    SUGGESTIONS+=('    "Document required environment variables and setup"')
fi

# Check for monorepo
if [ -f "pnpm-workspace.yaml" ] || [ -f "lerna.json" ]; then
    SUGGESTIONS+=('    "Document monorepo structure and workspace commands"')
fi

# Check for CI/CD
if [ -d ".github/workflows" ]; then
    SUGGESTIONS+=('    "Document CI/CD workflow and deployment process"')
fi

# Check for database
if grep -r "prisma" . 2>/dev/null | head -1 &> /dev/null || [ -f "prisma/schema.prisma" ]; then
    SUGGESTIONS+=('    "Document database schema and migration commands"')
fi

# Print suggestions
for i in "${!SUGGESTIONS[@]}"; do
    if [ $i -eq $((${#SUGGESTIONS[@]} - 1)) ]; then
        echo "${SUGGESTIONS[$i]}"
    else
        echo "${SUGGESTIONS[$i]},"
    fi
done

echo '  ]'
echo "}"

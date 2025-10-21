---
name: claude-code-analyzer
description: Analyzes Claude Code usage patterns and provides comprehensive recommendations. Runs usage analysis, discovers GitHub community resources, suggests CLAUDE.md improvements, and fetches latest docs on-demand. Use when user wants to optimize their Claude Code workflow, create configurations (agents/skills/commands), or set up project documentation.
---

# Claude Code History Analyzer

Complete workflow optimization for Claude Code through usage analysis, community discovery, and intelligent configuration generation.

## Core Capabilities

This skill provides a complete Claude Code optimization workflow:

**1. Usage Analysis** - Extracts patterns from Claude Code history
- Tool usage frequency
- Auto-allowed tools vs actual usage
- Model distribution
- Project activity levels

**2. GitHub Discovery** - Finds community resources automatically
- Skills matching your tools
- Agents for your workflows  
- Slash commands for common operations
- CLAUDE.md examples from similar projects

**3. Project Analysis** - Detects tech stack and suggests documentation
- Package manager and scripts
- Framework and testing setup
- Docker, CI/CD, TypeScript configuration
- Project-specific CLAUDE.md sections

**4. On-Demand Documentation** - Fetches latest Claude Code docs
- Agents/subagents structure and configuration
- Skills architecture and bundled resources
- Slash commands with MCP integration
- CLAUDE.md best practices from Anthropic teams
- Settings and environment variables

## Complete Analysis Workflow

When user asks to optimize their Claude Code setup, follow this workflow:

### Step 1: Run Usage Analysis
```bash
bash scripts/analyze.sh --current-project
```

This automatically:
- Extracts tool usage from JSONL files
- Checks auto-allowed tools configuration
- Analyzes model distribution
- **Searches GitHub for community resources** (always enabled)

### Step 2: Run Project Analysis
```bash
bash scripts/analyze-claude-md.sh
```

This detects:
- Package manager (npm, pnpm, yarn, cargo, go, python)
- Framework (Next.js, React, Django, FastAPI, etc.)
- Testing setup (Vitest, Jest, pytest, etc.)
- CI/CD, Docker, TypeScript, linting configuration

### Step 3: Interpret Combined Results

Combine insights from both analyses:

**Usage patterns** show:
- Tools used frequently but requiring approval → Add to auto-allows
- Auto-allowed tools never used → Remove from config
- Repetitive bash commands → Create slash commands
- Complex workflows → Create dedicated agents
- Domain-specific tasks → Build custom skills

**GitHub discovery** provides:
- Similar configurations from community
- Proven patterns for your tool usage
- Example agents/skills/commands to adapt

**Project analysis** reveals:
- Required CLAUDE.md sections
- Framework-specific conventions to document
- Testing and build commands to include

### Step 4: Fetch Docs and Create Configurations

Based on recommendations, fetch latest docs and create:

**For frequently used tools** → Update auto-allows:
```bash
# Fetch settings docs
web_fetch: https://docs.claude.com/en/docs/claude-code/settings
# Update ~/.claude/settings.json
```

**For repetitive commands** → Create slash command:
```bash
# Fetch slash commands docs
web_fetch: https://docs.claude.com/en/docs/claude-code/slash-commands
# Create .claude/commands/[command-name].md
```

**For complex workflows** → Create agent:
```bash
# Fetch agents docs
web_fetch: https://docs.claude.com/en/docs/claude-code/sub-agents
# Create .claude/agents/[agent-name].md
```

**For reusable domain knowledge** → Build skill:
```bash
# Fetch skills docs
web_fetch: https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview
# Create .claude/skills/[skill-name]/SKILL.md
```

**For project context** → Write CLAUDE.md:
```bash
# Fetch CLAUDE.md best practices
web_fetch: https://www.anthropic.com/engineering/claude-code-best-practices
# Create .claude/CLAUDE.md with detected info
```

## Example: Complete Optimization Session

**User**: "Help me optimize my Claude Code setup"

**Claude executes**:

1. **Analyze usage patterns**
   ```bash
   bash scripts/analyze.sh --current-project
   ```
   Finds: Bash tool used 150 times, Read 80 times, Write 45 times
   Auto-allows: None configured
   GitHub: Discovers community skills for TypeScript testing

2. **Analyze project structure**
   ```bash
   bash scripts/analyze-claude-md.sh
   ```
   Detects: Next.js project with Vitest, npm scripts: dev, build, test, lint
   Missing: CLAUDE.md doesn't exist

3. **Make recommendations**
   "I analyzed your Claude Code usage. Here's what I recommend:
   
   **Auto-Allows**: You use Bash (150×), Read (80×), and Write (45×) constantly. Let me add them to auto-allows.
   
   **Slash Command**: You run tests frequently. I'll create /test command.
   
   **CLAUDE.md**: Your Next.js project needs documentation. I'll create one with your npm scripts and testing setup.
   
   **Community Resource**: I found a TypeScript testing skill on GitHub that matches your workflow."

4. **Fetch docs and create configs**
   
   Fetch settings docs → Update `~/.claude/settings.json`:
   ```json
   {
     "autoAllowedTools": ["Bash", "Read", "Write"]
   }
   ```
   
   Fetch slash commands docs → Create `.claude/commands/test.md`:
   ```markdown
   ---
   name: /test
   description: Run tests for current file or project
   allowed-tools: [Bash]
   ---
   Run tests: !npm test
   ```
   
   Fetch CLAUDE.md best practices → Create `.claude/CLAUDE.md`:
   ```markdown
   # Project Context
   
   ## Commands
   - Dev: `npm run dev` (port 3000)
   - Build: `npm run build`
   - Test: `npm test`
   - Lint: `npm run lint`
   
   ## Tech Stack
   - Next.js 14
   - TypeScript
   - Vitest for testing
   
   ## Testing
   Run tests before commits: `npm test`
   ```

5. **Share GitHub findings**
   "I also found this community skill for TypeScript testing that you might find useful: [GitHub link]"

## When to Use Each Tool

### Use analyze.sh when:
- User asks to "analyze my workflow"
- Optimizing Claude Code setup
- Finding unused auto-allows
- Discovering community resources
- Understanding usage patterns

### Use analyze-claude-md.sh when:
- Creating CLAUDE.md
- Setting up new project
- User asks "what should I document?"
- Need project-specific recommendations

### Fetch docs when:
- Creating any configuration file
- User asks "how do I create an agent/skill/command?"
- Explaining configuration options
- Need current best practices

### Use GitHub discovery for:
- Finding proven patterns
- Learning from community
- Getting configuration examples
- Discovering new approaches

## Critical Documentation URLs

Always fetch latest docs before creating configurations:

| Type | URL |
|------|-----|
| Agents | https://docs.claude.com/en/docs/claude-code/sub-agents |
| Skills | https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview |
| Slash Commands | https://docs.claude.com/en/docs/claude-code/slash-commands |
| Settings | https://docs.claude.com/en/docs/claude-code/settings |
| CLAUDE.md | https://www.anthropic.com/engineering/claude-code-best-practices |

## Key Configuration Facts (from latest docs)

**Agents** (.md files with YAML frontmatter):
- Required: name, description
- Optional: tools (comma-separated), model (sonnet/opus/haiku/inherit)
- Location: `.claude/agents/` (project) or `~/.claude/agents/` (user)
- NOT .yaml files!

**Skills** (directory with SKILL.md):
- Structure: `skill-name/SKILL.md`
- Bundled resources: scripts/, references/, assets/
- Progressive loading: metadata → instructions → resources
- Location: `.claude/skills/`

**Slash Commands** (.md files):
- Required: name (with / prefix)
- Arguments: $ARGUMENTS, $1, $2
- Optional: allowed-tools, model, argument-hint
- Location: `.claude/commands/`

**CLAUDE.md** (project documentation):
- Hierarchical: user-level → parent → project → nested
- Include: commands, style guidelines, testing, issues
- Keep concise and actionable
- Location: `.claude/CLAUDE.md`

## Output Formats

### Usage Analysis JSON
```json
{
  "tool_usage": [{"tool": "Bash", "count": 122}],
  "auto_allowed_tools": [{"tool": "Read", "usage_count": 49}],
  "model_usage": [{"model": "claude-sonnet-4-5-20250929", "count": 634}],
  "github_discovery": {"searches": [...]}
}
```

### Project Analysis JSON
```json
{
  "detected_package_manager": {"type": "npm", "scripts": ["dev", "test"]},
  "testing": {"framework": "vitest"},
  "framework": {"type": "nextjs"},
  "claude_md_suggestions": ["Document npm scripts", "Document testing"]
}
```

## Requirements

- `jq` (install: `brew install jq` or `apt install jq`)
- Claude Code projects at `~/.claude/projects`
- Optional: `gh` CLI for direct GitHub search

## Why This Approach Works

**Comprehensive**: Combines usage analysis + community discovery + project detection
**Current**: Fetches latest docs on-demand, never stale
**Actionable**: Provides specific, implementable recommendations
**Automated**: GitHub discovery runs automatically, no flags needed
**Integrated**: All tools work together for complete workflow optimization

When helping users optimize Claude Code, always run both analyses, interpret results together, fetch latest docs, and create configurations with current best practices.

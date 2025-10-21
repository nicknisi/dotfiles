---
name: claude-code-analyzer
description: Analyzes Claude Code chat history and outputs structured JSON data for Claude to interpret. Extracts tool usage, auto-allow settings, model distribution, and project activity. Claude then provides intelligent, context-aware recommendations based on the data.
---

# Claude Code History Analyzer

Extracts structured usage data from Claude Code history for intelligent analysis.

## How It Works

The skill runs a bash script that:
1. Extracts tool usage, model distribution, and project activity from JSONL files
2. Reads your current auto-allow settings from `~/.claude/settings.json`
3. Outputs structured JSON data to stdout
4. Claude receives this data and provides context-aware recommendations

This approach lets Claude make intelligent recommendations based on:
- Your actual workflow patterns
- Current configuration vs usage
- Project-specific context
- Cross-project comparisons
- Feature discovery opportunities

## Usage

**Analyze current project**:
```bash
bash scripts/analyze.sh --current-project
```

**Analyze all projects**:
```bash
bash scripts/analyze.sh
```

**Analyze single file**:
```bash
bash scripts/analyze.sh --file /path/to/conversation.jsonl
```

## Output Format

The script outputs JSON containing:

```json
{
  "metadata": {
    "generated_at": "2025-01-15T10:30:00Z",
    "scope": "current_project",
    "scope_detail": "/Users/you/project",
    "total_conversations": 12
  },
  "tool_usage": [
    {"tool": "Bash", "count": 122},
    {"tool": "Read", "count": 49}
  ],
  "auto_allowed_tools": [
    {"tool": "Bash", "usage_count": 122},
    {"tool": "Read", "usage_count": 49}
  ],
  "model_usage": [
    {"tool": "claude-sonnet-4-5-20250929", "count": 634}
  ],
  "project_activity": [
    {"project": "~/authkit/tanstack/start", "conversations": 37}
  ]
}
```

Claude interprets this data to provide:
- Auto-allow recommendations (excluding already configured tools)
- Configuration validation
- Workflow optimization suggestions
- Feature recommendations
- Project-specific insights

## Why JSON Output?

Instead of hard-coding recommendations in bash, the script extracts raw data and lets Claude:
- Understand full context of your workflow
- Make nuanced recommendations based on patterns
- Adapt suggestions to your specific situation
- Explain the reasoning behind recommendations
- Answer follow-up questions about the data

## Modes

**Current Project** (`--current-project`)
Analyzes only the current working directory's history. Provides project-specific recommendations.

**All Projects** (default)
Comprehensive analysis across all Claude Code projects. Shows cross-project patterns.

**Single File** (`--file`)
Analyzes a specific conversation file. Useful for Claude Desktop users or spot checks.

## What Claude Analyzes

**Tool Usage Patterns**
- Which tools you use most
- Tools you approve manually every time
- Workflow efficiency opportunities

**Configuration Validation**
- Auto-allowed tools you actually use
- Tools that should be auto-allowed
- Unused auto-allows to consider removing

**Project Activity** (all-projects mode)
- High-activity projects
- Candidates for custom skills or agents

**Model Distribution**
- Which Claude models you use
- Usage patterns across conversations

**Feature Opportunities**
- Agents for repetitive workflows
- Slash commands for frequent operations
- Multi-file editing patterns
- Search optimization

## Requirements

- `jq` must be installed
- Claude Code projects at `~/.claude/projects`
- Bash shell

Install jq:
- macOS: `brew install jq`
- Linux: `apt install jq` or `yum install jq`

## Additional Scripts

**Feature Discovery**

Browse all available Claude Code features:
```bash
bash scripts/fetch-features.sh
```

Use this when you want to explore what Claude Code can do. The main analyzer recommends features based on your usage patterns, but this script shows the complete catalog of capabilities. Useful for discovering features you didn't know existed.

## Use Cases

**Project optimization**: Analyze your current project's workflow

**Configuration cleanup**: Find unused auto-allows

**Cross-project insights**: Compare patterns across codebases

**Desktop integration**: Analyze exported conversation files

**Feature discovery**: Learn about capabilities that match your usage

**Workflow improvement**: Get personalized optimization suggestions

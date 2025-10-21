# Claude Code Configuration Best Practices

This reference contains best practices for creating agents, skills, slash commands, and project context based on Anthropic's documentation.

## Agents

**File Format**: `.md` (Markdown)
**Location**: `.claude/agents/`
**Naming**: `agent-name.md` (kebab-case)

### Agent Structure

```markdown
---
name: Agent Name
description: Brief description of what this agent does
---

# Agent Name

## Purpose
Clear statement of the agent's role and when to use it.

## Capabilities
- Specific task 1
- Specific task 2
- Specific task 3

## Instructions
Detailed instructions for how the agent should behave, including:
- Context it should consider
- Tools it should use
- Output format expectations
- Edge cases to handle

## Examples
Concrete examples of how to invoke and use the agent.
```

### Agent Best Practices

1. **Use Markdown format** - Agents are `.md` files, not YAML
2. **Clear naming** - Name reflects the agent's purpose
3. **Specific scope** - Focused on a particular task or domain
4. **Explicit instructions** - Clear about what the agent should do
5. **Tool preferences** - Specify which tools the agent should favor
6. **Context awareness** - Include relevant project/domain knowledge

### Example Agent

```markdown
---
name: TypeScript Test Generator
description: Generates comprehensive test files for TypeScript modules using Vitest
---

# TypeScript Test Generator

## Purpose
Automatically generate test files for TypeScript modules with proper imports, setup, and test cases.

## Capabilities
- Analyze TypeScript source files
- Generate Vitest test suites
- Include edge cases and error scenarios
- Follow project testing conventions

## Instructions
1. Read the target TypeScript file
2. Identify exported functions, classes, and types
3. Create a corresponding `.test.ts` file
4. Generate test cases covering:
   - Happy path scenarios
   - Edge cases
   - Error conditions
5. Use proper Vitest syntax and assertions
6. Match project's existing test patterns

## Examples
"Generate tests for src/utils/parser.ts"
"Create comprehensive test coverage for the User class"
```

## Skills

**File Format**: Directory with `SKILL.md`
**Location**: `.claude/skills/skill-name/`
**Structure**:
```
.claude/skills/
  my-skill/
    SKILL.md          # Required: Skill documentation
    scripts/          # Optional: Executable scripts
    references/       # Optional: Reference docs
    assets/           # Optional: Templates/files
```

### SKILL.md Structure

```markdown
---
name: skill-name
description: What the skill does and when to use it
---

# Skill Name

## Overview
Brief explanation of what this skill enables.

## Usage
How to use the skill, including examples.

## Requirements
Any dependencies or prerequisites.

## Examples
Concrete usage examples.
```

### Skill Best Practices

1. **Frontmatter required** - Always include `name` and `description`
2. **Modular resources** - Separate scripts, docs, and assets
3. **Self-contained** - Include everything needed to use the skill
4. **Clear documentation** - Explain when and how to use it
5. **Executable scripts** - Make scripts executable (`chmod +x`)

## Slash Commands

**File Format**: `.md` (Markdown)
**Location**: `.claude/commands/`
**Naming**: `command-name.md` (kebab-case)

### Command Structure

```markdown
---
name: /command-name
description: Brief description of what this command does
---

# Command Name

## Purpose
What this command accomplishes.

## Usage
/command-name [arguments]

## Behavior
Detailed explanation of what happens when the command runs.

## Examples
- /command-name example1
- /command-name example2
```

### Slash Command Best Practices

1. **Markdown format** - Commands are `.md` files
2. **Name prefix** - Include `/` in the name frontmatter
3. **Clear trigger** - Name should match what user types
4. **Concise action** - Commands should do one thing well
5. **Fast execution** - Optimize for quick operations
6. **Argument handling** - Document expected arguments

### Example Slash Command

```markdown
---
name: /test
description: Run tests for the current file or project
---

# Test Command

## Purpose
Quickly run tests for the current file or entire test suite.

## Usage
- /test - Run all tests
- /test current - Run tests for current file only
- /test watch - Run tests in watch mode

## Behavior
1. Detect the test framework (Vitest, Jest, etc.)
2. Run appropriate test command
3. Display results inline
4. Highlight failures

## Examples
- /test - Runs `npm test`
- /test current - Runs tests for the active file
```

## Project Context (CLAUDE.md)

**File Format**: `.md` (Markdown)
**Location**: `.claude/CLAUDE.md`
**Purpose**: Provide project-specific context

### CLAUDE.md Structure

```markdown
# Project Context

## Overview
Brief description of the project.

## Architecture
Key architectural decisions and patterns.

## Development Workflow
How to build, test, and deploy.

## Conventions
- Code style guidelines
- Naming conventions
- Testing patterns
- Documentation standards

## Common Tasks
Frequent operations and how to perform them.

## Important Files
Key files and their purposes.

## Notes
Any other relevant context for working on this project.
```

### Project Context Best Practices

1. **Project-specific** - Unique to this codebase
2. **Actionable** - Include practical information
3. **Up-to-date** - Keep current as project evolves
4. **Conventions** - Document patterns and standards
5. **Common tasks** - Reduce repetitive explanations
6. **Architecture notes** - Explain key design decisions

## File Format Summary

| Type | Format | Extension | Location |
|------|--------|-----------|----------|
| Agent | Markdown | `.md` | `.claude/agents/` |
| Skill | Directory + Markdown | `SKILL.md` | `.claude/skills/skill-name/` |
| Slash Command | Markdown | `.md` | `.claude/commands/` |
| Project Context | Markdown | `.md` | `.claude/CLAUDE.md` |

## Common Mistakes to Avoid

1. **Using YAML for agents** - Agents are Markdown files, not YAML
2. **Missing frontmatter** - Always include name and description
3. **Wrong file extensions** - Use `.md`, not `.yaml` or `.yml`
4. **Vague descriptions** - Be specific about purpose and usage
5. **No examples** - Include concrete usage examples
6. **Missing documentation** - Every feature needs clear docs

## Creating Effective Configurations

### For Agents
- Focus on a specific domain or task
- Provide clear, actionable instructions
- Include examples of good output
- Specify preferred tools and approaches

### For Skills
- Create reusable, modular capabilities
- Include all necessary resources
- Document requirements and dependencies
- Provide clear usage examples

### For Slash Commands
- Make them fast and focused
- Use clear, memorable names
- Handle common arguments
- Provide inline feedback

### For Project Context
- Document the "why" not just the "what"
- Include team conventions
- List common gotchas
- Keep it current and relevant

## References

- Anthropic Claude Code Documentation: https://docs.claude.com/en/docs/claude-code
- Example configurations: Search GitHub for `.claude/` directories
- Community resources: Browse public dotfiles repositories

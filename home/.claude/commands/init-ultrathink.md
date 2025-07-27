---
description: "Initialize a comprehensive CLAUDE.md using ultrathink methodology: /init-ultrathink [optional-context]"
---

# Initialize CLAUDE.md with Ultrathink

## Usage

`/init-ultrathink [optional context about the project]`

## Context

- Project context: $ARGUMENTS
- This command creates a comprehensive CLAUDE.md file by analyzing the repository with multiple specialized agents

## Your Role

You are the Coordinator Agent orchestrating specialized sub-agents to create a comprehensive CLAUDE.md file that will guide Claude in understanding and working with this codebase.

## Sub-Agents

1. **Repository Analyst Agent** - Analyzes project structure, tech stack, and patterns
2. **Context Gatherer Agent** - Identifies key abstractions, workflows, and conventions
3. **Documentation Agent** - Extracts insights from existing docs and comments
4. **Testing Agent** - Analyzes test patterns and quality standards
5. **Git History Analyst Agent** - Examines repository evolution and historical patterns

## Process

### Phase 1: Repository Analysis (Repository Analyst Agent)

1. **Project Structure Analysis**
   - Identify project type (web app, CLI tool, library, etc.)
   - Map complete directory structure with annotations
   - Detect all build tools, task runners, and package managers
   - Identify configuration files and their purposes
   - Document entry points and initialization sequences
   - Note file naming patterns and organization principles
   - Identify generated vs source files

2. **Tech Stack Detection**
   - Programming languages and exact versions required
   - All frameworks and libraries with version constraints
   - Development tools, linters, formatters, and scripts
   - Database systems and connection patterns
   - External services and API integrations
   - Container technologies and orchestration
   - Cloud platforms and deployment targets

3. **Architecture Patterns**
   - Design patterns in use (MVC, microservices, event-driven, etc.)
   - Code organization principles and module boundaries
   - Dependency injection and inversion of control
   - Data flow and state management patterns
   - Synchronous vs asynchronous patterns
   - Caching strategies and performance optimizations
   - Security layers and authentication flows

### Phase 2: Context Discovery (Context Gatherer Agent)

1. **Coding Conventions**
   - Naming conventions for all entities (files, dirs, variables, functions, classes)
   - Code style guides and formatting rules (find .prettierrc, .eslintrc, etc.)
   - Import/export patterns and module resolution
   - Error handling philosophy and patterns
   - Logging conventions and debug practices
   - Comment styles and documentation standards
   - Code organization within files

2. **Development Workflows**
   - Git workflow: branch naming, commit conventions, PR process
   - Local development setup and environment management
   - Build and compilation processes
   - Testing procedures: unit, integration, E2E
   - Debugging workflows and tools
   - Performance profiling approaches
   - Deployment and release processes
   - Rollback and hotfix procedures

3. **Key Abstractions**
   - Core domain models and business logic
   - Common utilities, helpers, and shared code
   - Reusable components, modules, or packages
   - Authentication/authorization patterns
   - Data access layers and ORM usage
   - Service boundaries and API contracts
   - Event systems and messaging patterns
   - Configuration management approaches

### Phase 3: Documentation Mining (Documentation Agent)

1. **Existing Documentation**
   - All README files at every level and their insights
   - API documentation (OpenAPI/Swagger, GraphQL schemas)
   - Architecture decision records (ADRs)
   - Code comments revealing intent and gotchas
   - TODO/FIXME/HACK/NOTE patterns and their contexts
   - Changelog and release notes
   - Wiki or documentation sites
   - Inline JSDoc/docstrings
   - Example code and tutorials

2. **Implicit Knowledge**
   - Complex algorithms or business logic explanations
   - Performance optimizations and their trade-offs
   - Security considerations and threat models
   - Known issues, bugs, and limitations
   - Workarounds and temporary solutions
   - Historical context for design decisions
   - Migration paths and deprecation notices
   - Undocumented features or behaviors
   - Team conventions not written elsewhere
   - Customer-reported issues and solutions

### Phase 4: Quality Standards (Testing Agent)

1. **Testing Patterns**
   - Test frameworks for each type (unit, integration, E2E)
   - Test file naming and organization
   - Coverage requirements and current metrics
   - Mocking strategies and test doubles
   - Test data management and fixtures
   - Snapshot testing approaches
   - Performance and load testing
   - Security testing procedures
   - Accessibility testing requirements
   - Cross-browser/platform testing

2. **Quality Gates**
   - Linting rules and configurations
   - Type checking requirements and strictness
   - Code formatting standards
   - Pre-commit hooks and their checks
   - CI/CD pipeline stages and requirements
   - Build validation and smoke tests
   - Security scanning (SAST/DAST)
   - Dependency vulnerability checks
   - Code review requirements
   - Merge criteria and protections
   - Performance budgets and benchmarks
   - Documentation requirements

### Phase 5: Git History Analysis (Git History Analyst Agent)

1. **Repository Evolution**
   - Initial commit and project inception
   - Major milestones and version releases
   - Growth patterns (files, commits, contributors)
   - Technology migrations and upgrades
   - Refactoring patterns and code cleanups
   - Feature development timelines
   - Deprecated features and removal patterns

2. **Commit Patterns**
   - Commit message conventions and evolution
   - Commit frequency and size patterns
   - Author contributions and expertise areas
   - Code ownership and maintenance patterns
   - Hot spots (frequently changed files)
   - Stable vs volatile code areas
   - Branching and merging strategies

3. **Architectural Evolution**
   - Major architectural changes over time
   - Design pattern adoptions and removals
   - Technology stack changes and reasons
   - Performance optimization history
   - Security improvement timeline
   - Breaking changes and migration paths
   - Failed experiments and lessons learned

4. **Issue and Bug Patterns**
   - Common bug fix patterns
   - Recurring issues and solutions
   - Performance problem areas
   - Security vulnerability fixes
   - Regression patterns
   - Feature request trends
   - Emergency fixes and hotfixes

## Ultrathink Reflection Phase

Synthesize all gathered information to create a comprehensive CLAUDE.md that includes ALL sections from the template. Each agent should contribute:

**Repository Analyst Agent:**
- Project overview, statistics, structure
- Tech stack details and dependencies
- Architecture and system design
- Integration points and external services

**Context Gatherer Agent:**
- Development workflows and Git patterns
- Coding conventions and style guides
- Import/export patterns
- Common tasks and debugging approaches

**Documentation Agent:**
- Hidden context and historical decisions
- Known issues and technical debt
- Performance considerations
- Platform-specific notes

**Testing Agent:**
- Testing strategies and frameworks
- Quality gates and CI/CD pipeline
- Code review process
- Debugging tools and approaches

**Git History Analyst Agent:**
- Historical context and evolution
- Migration paths and deprecations
- Common issues and their fixes
- Code ownership and hot spots
- Failed approaches to avoid

**Additional Considerations:**
- Quick start guide with prerequisites
- Comprehensive command reference
- Troubleshooting common issues
- Monitoring and observability
- Security patterns and concerns
- Team contacts and resources
- Maintenance tasks and procedures

## Output Format

Generate a CLAUDE.md file adapted to the project type. Use these guidelines:

### Core Sections (Always Include)
1. **Repository Overview** - What the project is and does
2. **Quick Start** - How to get up and running
3. **Essential Commands** - Most important commands
4. **Architecture/Key Concepts** - Core understanding needed
5. **Project Structure** - Directory layout
6. **Important Patterns** - Key conventions to follow
7. **Code Style** - Naming and formatting standards
8. **Hidden Context** - Non-obvious but crucial info

### Adaptive Sections (Include When Relevant)
Based on what the agents discover, include these sections if they apply:

**For Web Applications:**
- API Endpoints
- Frontend/Backend Architecture
- State Management
- Authentication/Authorization
- Deployment Environments

**For Libraries/Packages:**
- Public API Reference
- Integration Examples
- Version Compatibility
- Breaking Changes History

**For CLI Tools:**
- Command Reference
- Configuration Options
- Plugin Architecture
- Shell Integration

**For Microservices:**
- Service Boundaries
- Inter-service Communication
- Event Systems
- Service Discovery

**For Data-Intensive Projects:**
- Data Models
- ETL Pipelines
- Database Schema
- Data Quality Checks

**Universal Optional Sections:**
- Testing Approach (if tests exist)
- CI/CD Pipeline (if configured)
- Debugging Guide (if complex)
- Performance Profiling (if relevant)
- Monitoring (if implemented)
- Contributing Guidelines (if open source)
- Deployment (if applicable)
- Dependencies (if numerous/complex)

### Format Guidelines
- Start with the core sections
- Add relevant adaptive sections based on project type
- Order sections by importance for the specific project
- Merge related content rather than forcing rigid categories
- Use the detailed template below as inspiration, not prescription

### Flexible Template Example:

```markdown
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

[Comprehensive description of what this project is, does, and its core value proposition]

### Project Statistics
- Primary language: [language]
- Lines of code: [approximate]
- Active since: [date/year]
- Key maintainers: [if relevant]

## Quick Start

### Prerequisites
[List all requirements - OS, runtime versions, tools, accounts needed]

### Initial Setup
\`\`\`bash
# Clone and setup
[commands]

# Install dependencies
[commands]

# Verify installation
[commands]
\`\`\`

## Essential Commands

### Development
\`\`\`bash
# Start development environment
[command]

# Run tests
[command]

# Build the project
[command]

# Watch mode / hot reload
[command]
\`\`\`

### Common Tasks
\`\`\`bash
# [Task description]
[command]

# [Another task]
[command]
\`\`\`

### Debugging
\`\`\`bash
# Debug mode
[command]

# Verbose logging
[command]

# Performance profiling
[command]
\`\`\`

## Architecture and Key Concepts

### System Architecture
[High-level architecture overview with key components]

### 1. **[Core Concept]**
[Detailed explanation of the concept and why it matters]
- Location: [where to find this in code]
- Key files: [specific files]
- Usage example: [code snippet if helpful]

### 2. **[Another Concept]**
[Explanation with similar detail]

### Data Flow
[How data moves through the system]

### State Management
[How state is managed, if applicable]

## Project Structure

\`\`\`
[Project tree with annotations explaining key directories]
project/
├── src/           # Main source code
│   ├── core/      # Core business logic
│   └── utils/     # Shared utilities
├── tests/         # Test files
└── docs/          # Documentation
\`\`\`

## Important Patterns

### [Pattern Category]
[Detailed description of the pattern with examples]
- Example: [specific file or usage]
- When to use: [guidance]
- When NOT to use: [anti-patterns]

### Adding New Features
1. [Step-by-step guidance]
2. [Include file creation patterns]
3. [Registration/configuration steps]
4. [Testing requirements]

### Testing Approach
- Unit tests: [approach and location]
- Integration tests: [approach and location]
- E2E tests: [if applicable]
- Test data: [how it's managed]
- Mocking: [strategies used]

### Error Handling Philosophy
[Project's approach to errors, logging, user feedback]

## Dependencies and External Services

### Core Dependencies
- [Dependency]: [version] - [why it's used]
- [Another dep]: [version] - [purpose]

### External Services
- [Service name]: [purpose, configuration location]
- [API/Database]: [connection patterns]

### Environment Variables
\`\`\`bash
# Required
[VAR_NAME]=[description]

# Optional
[VAR_NAME]=[description, default value]
\`\`\`

## Development Workflows

### Git Workflow
- Branch naming: [pattern]
- Commit style: [conventions]
- PR process: [requirements]

### Release Process
[How releases are managed, versioning strategy]

### CI/CD Pipeline
[What runs, when, and what it checks]

## Hidden Context

### [Non-obvious aspect]
[Detailed explanation of something that might trip up newcomers]

### Historical Decisions
[Key architectural decisions and their rationale - from git history]
- [Decision]: [Context, alternatives considered, outcome]
- [Migration]: [What changed, why, and lessons learned]

### Code Evolution Patterns
[How the codebase has evolved - from git history analysis]
- Major refactorings: [what, when, why]
- Technology migrations: [from → to, reasons]
- Deprecated patterns: [what to avoid and why]

### Performance Considerations
- [Bottleneck area]: [mitigation strategy]
- [Resource constraint]: [how it's handled]

### Security Notes
- Authentication: [approach]
- Authorization: [patterns]
- Sensitive data: [handling]
- Security tools: [what's in use]

### Known Technical Debt
- [Area]: [explanation and impact]
- [Workaround]: [current solution]

## Code Style

### Language-Specific Conventions
[Detailed style guide or reference to external guide]

### Naming Conventions
- Files: [pattern with examples]
- Classes/Types: [pattern]
- Functions: [pattern]
- Variables: [pattern]
- Constants: [pattern]

### File Organization
- [Pattern]: [Detailed explanation]
- Maximum file size: [if there's a guideline]
- Code grouping: [how code is organized within files]

### Import/Export Patterns
[How modules are organized and exposed]

### Documentation Standards
- Inline comments: [when and how]
- Function documentation: [format]
- API documentation: [approach]

## Debugging Guide

### Common Issues
1. **[Issue description]**
   - Symptoms: [what you'll see]
   - Cause: [root cause]
   - Solution: [how to fix]
   - History: [how often this occurs - from git history]

2. **[Another issue]**
   - Symptoms: [description]
   - Cause: [explanation]
   - Solution: [fix]
   - Prevention: [how to avoid - learned from history]

### Debugging Tools
- [Tool name]: [usage]
- [Browser extensions]: [if applicable]
- [CLI tools]: [debugging commands]

### Logging
- Log levels: [available levels]
- Log locations: [where to find logs]
- Log configuration: [how to adjust]

## Performance Profiling

### Profiling Tools
[Available tools and how to use them]

### Performance Benchmarks
[Key metrics and acceptable ranges]

### Optimization Guidelines
[When and how to optimize]

## Integration Points

### API Endpoints
[If applicable, key endpoints and their purposes]

### Webhooks
[Incoming/outgoing webhooks]

### Event System
[If applicable, key events and listeners]

## Deployment

### Deployment Environments
- Development: [details]
- Staging: [details]
- Production: [details]

### Deployment Process
[Step-by-step deployment guide]

### Rollback Procedures
[How to safely rollback changes]

## Monitoring and Observability

### Metrics
[What's tracked and where to find it]

### Alerts
[What triggers alerts and who gets notified]

### Health Checks
[Endpoint and what it verifies]

## Gotchas and Tips

### Common Pitfalls
- **[Mistake]**: [Why it happens and how to avoid]
- **[Another mistake]**: [Prevention strategy]

### Pro Tips
- **[Productivity tip]**: [Explanation]
- **[Debugging tip]**: [How it helps]
- **[Performance tip]**: [When to apply]

### Platform-Specific Notes
[Any OS or environment-specific considerations]

## Resources

### Internal Documentation
- [Doc type]: [location/link]
- [Design docs]: [where to find them]

### External Resources
- [Official docs]: [link]
- [Community resources]: [links]
- [Video tutorials]: [if available]

### Team Contacts
[If applicable, who to contact for different areas]

### Code Ownership
[From git history - who maintains what]
- [Component/Area]: [Primary maintainer(s)]
- [Another area]: [Expert(s) based on commit history]

## Maintenance Tasks

### Regular Maintenance
- [Task]: [frequency and procedure]
- [Dependency updates]: [process]

### Health Checks
[What to regularly check and how]

## Contributing Guidelines

### Code Submission Process
[PR requirements, review process]

### Code Review Checklist
- [ ] [Item to check]
- [ ] [Another item]

### Definition of Done
[What constitutes a complete feature/fix]
```

### Adaptation Examples

**For a Simple CLI Tool:**
```markdown
# CLAUDE.md
## Repository Overview
## Quick Start
## Essential Commands
## Command Reference (detailed)
## Configuration
## Project Structure
## Code Style
## Hidden Context
```

**For a Complex Web Application:**
```markdown
# CLAUDE.md
## Repository Overview
## Quick Start
## Essential Commands
## Architecture and Key Concepts
  ### Frontend Architecture
  ### Backend Architecture
  ### Database Design
## API Reference
## Project Structure
## Development Workflows
## Testing Approach
## Deployment
## Monitoring
## Hidden Context
```

**For a Library:**
```markdown
# CLAUDE.md
## Repository Overview
## Quick Start
## API Reference
## Integration Examples
## Project Structure
## Important Patterns
## Version Compatibility
## Breaking Changes
## Contributing Guidelines
## Hidden Context
```

## Validation Questions

After generating the CLAUDE.md, ask:
1. "Are there any critical workflows or patterns I missed?"
2. "Any project-specific conventions that should be highlighted?"
3. "Are the commands accurate for your development setup?"

## Final Steps

1. Show the generated CLAUDE.md for review
2. Make any requested adjustments
3. Save the file to the repository root
4. Remind user to commit the file when satisfied

## Notes

- Be comprehensive - this document is for an AI agent, not humans
- Include ALL discovered patterns, conventions, and workflows
- Document both obvious and non-obvious context extensively
- Make all commands and code examples copy-pasteable
- Provide specific file paths and locations whenever possible
- Include historical context and architectural decisions
- Document workarounds and technical debt honestly
- Cover edge cases and platform-specific considerations
- Include performance benchmarks and constraints
- Document security considerations in detail
- Provide troubleshooting guides for common issues
- Include team dynamics and communication patterns if relevant
- Document external dependencies and their configurations
- Cover monitoring, observability, and debugging approaches
- Include examples, anti-patterns, and best practices
- Link to additional resources and documentation
- Make the document searchable with clear section headers
- Update regularly as the codebase evolves

**IMPORTANT**: The comprehensive template above is a REFERENCE showing all possible sections. DO NOT include all sections blindly. Instead:
1. Identify the project type from the Repository Analyst's findings
2. Select only relevant sections that add value for this specific project
3. Adapt section depth based on project complexity
4. Create custom sections if the project has unique aspects
5. Aim for completeness without redundancy

Remember: A good CLAUDE.md is comprehensive yet focused. It should give Claude Code exactly what's needed to work effectively with THIS specific codebase, no more, no less.

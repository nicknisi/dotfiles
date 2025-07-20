# Create PRP

## Feature file: $ARGUMENTS

Generate a complete PRP for feature implementation with thorough research. Read the feature file first to understand requirements and context.

## Research Process

1. **Codebase Analysis**
   - Search for similar patterns in the codebase
   - Identify TypeScript/JavaScript conventions
   - Check existing test patterns (Jest, Vitest, etc.)
   - Note build tools and package manager (npm, yarn, pnpm)

2. **External Research**
   - Library documentation with specific URLs
   - TypeScript implementation examples
   - Best practices for the tech stack
   - Common integration patterns

3. **Project Context**
   - Framework being used (React, Next.js, Node.js, etc.)
   - Testing strategy and tools
   - Build and deployment processes

## PRP Generation

Using PRPs/templates/prp_base.md as template:

### Critical Context
- **Documentation URLs**: Specific sections for libraries/frameworks
- **Code Examples**: Real patterns from the codebase
- **Tech Stack**: Framework, build tools, testing setup
- **Patterns**: Existing approaches to mirror

### Implementation Blueprint
- Pseudocode showing the approach
- Reference files for patterns to follow
- Error handling strategy
- **Incremental milestones** for step-by-step validation

### Validation Gates (Tech Stack Specific)
```bash
# TypeScript/Build validation
npm run type-check
npm run lint
npm run build

# Testing
npm run test

# Custom validation commands based on project
Implementation Phases
Break implementation into phases:

Setup Phase: File structure, types, interfaces
Core Phase: Main functionality implementation
Integration Phase: Connect with existing systems
Testing Phase: Unit and integration tests
Polish Phase: Error handling, edge cases

Each phase should have:

Clear deliverables
Validation commands
Manual testing instructions

Output
Save as: PRPs/{feature-name}.md
Score the PRP on confidence level (1-10) for successful incremental implementation.

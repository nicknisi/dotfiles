# Execute Feature Specification

## Spec File: $ARGUMENTS

Execute feature specifications with intelligent automation, comprehensive validation, and progress tracking.

## Pre-Execution Setup

### 1. Load and Validate Specification
```bash
# Load specification
SPEC_FILE="$ARGUMENTS"
SPEC_NAME=$(basename "$SPEC_FILE" .md)
PRP_FILE="PRPs/${SPEC_NAME}.md"

# Auto-generate or update PRP if needed
if [ ! -f "$PRP_FILE" ] || [ "$SPEC_FILE" -nt "$PRP_FILE" ]; then
  echo "Generating PRP from spec..."
  /generate-prp "$SPEC_FILE"
fi

# Extract metadata from spec
COMPLEXITY_SCORE=$(grep "Complexity Score:" "$SPEC_FILE" | cut -d: -f2)
ESTIMATED_EFFORT=$(grep "Estimated Effort:" "$SPEC_FILE" | cut -d: -f2)
```

### 2. Project Context Discovery
```bash
# Discover project structure and conventions
find . -maxdepth 3 -name "*.config.*" -o -name "*rc.*" -o -name "Makefile"

# Identify test patterns
find . -type f -name "*test*" -o -name "*spec*" | head -5

# Check for existing similar features
grep -r "similar_pattern" --include="*.ts" --include="*.js" --include="*.py"
```

### 3. Execution Plan Generation
Based on spec complexity score:
- **1-3 (Simple)**: Direct implementation with minimal checkpoints
- **4-6 (Medium)**: Phased approach with validation points
- **7-10 (Complex)**: Incremental delivery with extensive validation

## Spec-Driven Execution Phases

### Phase 1: Foundation
**From Spec Section: Technical Architecture**

1. **Database Changes** (if specified in spec)
   - Create/modify schema as defined
   - Add migrations if project uses them
   - Update models/entities

2. **API Structure** (if specified in spec)
   - Create endpoint definitions
   - Add request/response types
   - Set up routing

3. **Core Data Structures**
   - Implement interfaces from spec
   - Create types/classes as defined
   - Set up state management

**Validation Checkpoint:**
- Verify all foundation elements exist
- Check that types/interfaces compile
- Confirm database changes applied

### Phase 2: Core Implementation
**From Spec Section: Implementation Checklist**

Work through each item in the spec's implementation checklist:
1. Read the specific requirement
2. Implement exactly as specified
3. Validate implementation works
4. Mark item complete in tracking

**Continuous Validation:**
- After each file modification
- Check for syntax errors
- Verify imports resolve
- Ensure no breaking changes

### Phase 3: Integration
**From Spec Section: Dependencies and Integration**

1. **Connect Components**
   - Wire up services as specified
   - Integrate with existing systems
   - Add configuration as needed

2. **Data Flow**
   - Implement data pipelines
   - Connect frontend to backend
   - Set up event handlers

**Validation Checkpoint:**
- Test integration points work
- Verify data flows correctly
- Check error handling

### Phase 4: Testing & Validation
**From Spec Section: Testing Strategy**

Execute test plan from specification:
1. Create tests for acceptance criteria
2. Implement test scenarios from spec
3. Validate success metrics

**Coverage Areas:**
- Unit tests for new functions
- Integration tests for workflows
- Manual testing checklist items

### Phase 5: Documentation & Polish
**From Spec Section: User Stories**

1. **Code Documentation**
   - Add comments for complex logic
   - Document public APIs
   - Update type definitions

2. **User Documentation**
   - Create usage examples
   - Document configuration options
   - Add troubleshooting notes

## Progress Tracking

### Implementation Checklist Tracking
Track progress through spec requirements:
```
[✓] Database schema created
[✓] API endpoints defined
[⏳] Frontend components built
[ ] Integration complete
[ ] Tests passing
[ ] Documentation updated
```

### Execution Report Template
```markdown
## Implementation Progress

### Completed
- [List completed spec requirements]

### In Progress  
- [Current work items]

### Remaining
- [Outstanding spec requirements]

### Issues & Blockers
- [Any problems encountered]

### Validation Results
- [Test results if available]
- [Manual testing outcomes]
```

## Control Commands

### During Execution
- `continue` - Proceed to next phase
- `status` - Show current progress
- `validate` - Run validation checks
- `pause` - Stop for manual work
- `skip` - Skip current item (with warning)
- `retry` - Retry failed operation

### Validation Commands
- `check-spec` - Verify against specification
- `test` - Run relevant tests
- `lint` - Check code quality

### Reporting
- `report` - Generate progress report
- `checklist` - Show implementation checklist
- `metrics` - Display execution metrics

## Smart Checkpoints

### Automatic Progression
Continue automatically when:
- Current phase implementation complete
- No errors detected
- Spec requirements met for phase

### Manual Checkpoint Required
Pause for confirmation when:
- Complexity score > 7
- Errors or warnings detected
- Spec has explicit "manual review" notes
- Major architectural changes made

## Error Recovery

### Common Recovery Actions
1. **Missing Dependencies**: Note what's needed
2. **Type/Syntax Errors**: Attempt fixes
3. **Test Failures**: Isolate and document
4. **Integration Issues**: Rollback and retry

### Manual Intervention
Required for:
- Spec ambiguities
- Architectural decisions
- Security concerns
- Performance issues

## Spec Compliance Validation

### Continuous Checks
- Are we following the spec's Technical Architecture?
- Have we completed Implementation Checklist items?
- Do changes match the API Design?
- Are Success Metrics being met?

### Final Validation
1. **Spec Requirements**: Check all requirements implemented
2. **Acceptance Criteria**: Verify all criteria met
3. **Test Coverage**: Ensure test scenarios covered
4. **Documentation**: Confirm docs updated

## Configuration

### Project-Specific Settings
The command adapts to project conventions:
- Reads existing config files
- Follows established patterns
- Uses project's test framework
- Respects code style rules

### Execution Modes
- **Guided**: Step-by-step with confirmations
- **Auto**: Automatic progression where safe
- **Review**: Implementation with detailed review points
- **Fast**: Minimal checkpoints for simple features

## Usage Examples

```bash
# Execute a specification
/execute-spec specs/user-auth-spec.md

# Execute with auto-progression
/execute-spec specs/feature-spec.md --auto

# Execute specific phase
/execute-spec specs/api-spec.md --phase=3

# Dry run to preview changes
/execute-spec specs/new-feature.md --dry-run
```

## Key Principles

1. **Follow the Spec Literally**: Implement exactly what's specified
2. **Validate Continuously**: Check work at each step
3. **Track Progress**: Maintain clear status of implementation
4. **Adapt to Project**: Use project's patterns and conventions
5. **Fail Safely**: Pause when uncertain rather than guess

The execution is driven entirely by the specification document, ensuring that implementation matches requirements exactly while adapting to each project's unique structure and conventions.
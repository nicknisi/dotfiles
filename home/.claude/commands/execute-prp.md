# Execute PRP

Execute PRP with Incremental Validation
PRP File: $ARGUMENTS
Execute a PRP in phases with validation points between each step.

## Execution Process

### Load and Plan

Read the PRP file completely
Understand all requirements and context
Create implementation plan using TodoWrite tool
Identify the phases and validation points


### Phase-by-Phase Execution

For each phase:

- Announce the phase you're starting
- Implement only that phase's requirements
- Run phase-specific validation commands
- Wait for user confirmation before proceeding

### Phase Structure:

Setup → Core → Integration → Testing → Polish
Each phase outputs working, testable code
Manual testing instructions provided

### Validation Protocol

ash# Run validation commands from PRP
# Report results clearly
# Fix any failures before proceeding

User Checkpoints
After each phase:

Show what was implemented
Provide manual testing steps
Wait for user feedback/approval
Allow for course correction if needed


Completion

Final validation suite
Confirm all PRP requirements met
Provide usage documentation



Control Commands During Execution

"continue" - proceed to next phase
"fix [issue]" - address specific problem
"pause" - stop for manual intervention
"restart phase" - redo current phase
"skip to [phase]" - jump ahead (with warning)

Note: Always wait for user confirmation between phases unless explicitly told to continue automatically.


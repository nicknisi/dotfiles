# Execute Feature Specification

## Spec File: $ARGUMENTS

Execute a feature specification in phases with validation points between each step.

## Execution Process

1. **Load Spec and Prepare PRP**
   - Read the specification file completely
   - Check if corresponding PRP exists at `PRPs/{spec-name}.md`
   - If no PRP exists, automatically generate one using `/generate-prp`
   - If PRP exists but spec is newer, regenerate PRP
   - Load the PRP for implementation guidance

2. **Plan Implementation**
   - Understand all requirements and context from spec
   - Review PRP research and implementation phases
   - Create implementation plan using TodoWrite tool
   - Identify the phases and validation points

3. **Phase-by-Phase Execution**
   
   **For each phase (from PRP):**
   - Announce the phase you're starting
   - Reference spec requirements for this phase
   - Implement only that phase's requirements
   - Run phase-specific validation commands
   - Wait for user confirmation before proceeding
   
   **Phase Structure:**
   - Setup → Core → Integration → Testing → Polish
   - Each phase outputs working, testable code
   - Manual testing instructions provided
   - Validate against spec acceptance criteria

4. **Validation Protocol**
   ```bash
   # Run validation commands from PRP
   # Test against spec requirements
   # Report results clearly
   # Fix any failures before proceeding
   ```

5. **User Checkpoints**
   After each phase:
   - Show what was implemented
   - Reference which spec requirements were addressed
   - Provide manual testing steps
   - Wait for user feedback/approval
   - Allow for course correction if needed

6. **Completion**
   - Final validation suite
   - Confirm all spec requirements met
   - Check against spec acceptance criteria
   - Provide usage documentation

## Automatic PRP Management
- If `PRPs/{spec-name}.md` doesn't exist, generate it automatically
- If spec file is newer than PRP, offer to regenerate PRP
- PRP generation follows same research process as `/generate-prp`
- User can inspect generated PRP before proceeding

## Control Commands During Execution
- "continue" - proceed to next phase
- "fix [issue]" - address specific problem  
- "pause" - stop for manual intervention
- "restart phase" - redo current phase
- "skip to [phase]" - jump ahead (with warning)
- "regenerate prp" - create new PRP from current spec
- "show prp" - display the PRP being used

Note: Always wait for user confirmation between phases unless explicitly told to continue automatically.

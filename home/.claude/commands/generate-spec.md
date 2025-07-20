# Generate Feature Specification

## Feature description: $ARGUMENTS

Create a comprehensive feature specification from a high-level description or idea.

## Analysis Process

1. **Requirement Clarification**
   - Parse the feature description
   - Identify core functionality needed
   - Extract user stories and use cases
   - Note any constraints or preferences mentioned

2. **Context Discovery**
   - Search existing codebase for related features
   - Identify current user flows and patterns
   - Check existing UI/UX patterns to follow
   - Note authentication, data storage, and API patterns

3. **Scope Definition**
   - Break down into logical components
   - Identify MVP vs nice-to-have features
   - Consider integration points with existing systems
   - Flag potential technical challenges

4. **User Experience Planning**
   - Map user journeys and workflows
   - Consider different user types/roles
   - Identify error states and edge cases
   - Plan responsive/accessibility considerations

## Specification Template

### Feature Overview
- **Name**: Clear, descriptive feature name
- **Purpose**: Why this feature is needed
- **Success Criteria**: How to measure success

### User Stories
- **Primary Users**: Who will use this feature
- **Core User Stories**: "As a [user], I want [goal] so that [benefit]"
- **Edge Cases**: Less common but important scenarios

### Functional Requirements
- **Core Features**: Must-have functionality
- **User Interface**: Key screens/components needed
- **Data Requirements**: What data needs to be stored/processed
- **Integration Points**: How it connects to existing systems

### Technical Constraints
- **Performance**: Response time, load requirements
- **Security**: Authentication, authorization, data protection
- **Compatibility**: Browser, device, API version requirements
- **Scalability**: Expected usage growth

### Acceptance Criteria
- **Definition of Done**: Specific, testable criteria
- **Test Scenarios**: Key flows to validate
- **Error Handling**: Expected error states and responses

### Out of Scope
- **Future Enhancements**: Ideas for later iterations
- **Explicitly Excluded**: What this feature will NOT do

## Interactive Questions

Ask clarifying questions if the description lacks:
- Target users and their needs
- Success metrics or business goals
- Technical preferences or constraints
- Integration requirements
- Timeline or priority considerations

## Output
Save as: `features/{feature-name}.md`

The resulting spec should be detailed enough to:
- Hand off to another developer
- Generate accurate time estimates
- Create comprehensive PRPs
- Validate against user needs

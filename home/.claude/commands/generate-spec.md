# Generate Feature Specification

## Feature description: $ARGUMENTS

Create a comprehensive, actionable feature specification with automated codebase analysis.

## Phase 1: Automated Discovery

### Codebase Pattern Analysis
```bash
# Find similar features
rg -l "similar_feature_keywords" --type ts --type tsx
# Identify existing patterns
find . -name "*.spec.ts" -path "*/features/*" | head -5
# Check authentication patterns
rg "useAuth|requireAuth|withAuth" --type ts -A 2
# Database schema patterns
find . -name "*.prisma" -o -name "*.sql" -o -name "*migration*"
```

### Dependency Mapping
- Search for related imports: `rg "import.*{feature_related}" --type ts`
- Check existing API endpoints: `rg "router\.(get|post|put|delete)" --type ts`
- Find UI components: `find ./src/components -name "*.tsx" | grep -i feature_area`

## Phase 2: Requirements Analysis

### User Story Mining
**Format**: As a [user_type], I want [capability] so that [business_value]

**Required Classifications**:
- Critical path (blocks other features)
- Core functionality (MVP)
- Enhancement (can ship without)
- Future consideration (v2)

### Technical Complexity Scoring
Calculate automatically:
- Files to modify: `git ls-files | xargs grep -l "pattern" | wc -l`
- New dependencies: Check against package.json
- Database changes: Schema modifications needed
- API surface: New endpoints required

**Complexity Score**: 
- 1-3: Simple (< 5 files, no deps, no DB)
- 4-6: Medium (5-15 files, deps OR DB)
- 7-10: Complex (> 15 files, deps AND DB)

## Phase 3: Specification Generation

### 1. Executive Summary
- **Feature Name**: [Descriptive, searchable name]
- **Business Value**: [Specific metric improvement expected]
- **Complexity Score**: [Auto-calculated from above]
- **Estimated Effort**: [Based on complexity and similar features]

### 2. Technical Architecture

#### Database Schema
```sql
-- Required changes
ALTER TABLE existing_table ADD COLUMN new_field TYPE;
CREATE TABLE IF NOT EXISTS new_table (...);
```

#### API Design
```typescript
// New endpoints
POST /api/feature
GET /api/feature/:id
PUT /api/feature/:id
DELETE /api/feature/:id

// Request/Response types
interface FeatureRequest { ... }
interface FeatureResponse { ... }
```

#### Frontend Components
```typescript
// Component hierarchy
<FeatureContainer>
  <FeatureList />
  <FeatureDetail />
  <FeatureForm />
</FeatureContainer>
```

### 3. Implementation Checklist

#### Pre-Implementation
- [ ] Review existing patterns in: [list similar files]
- [ ] Confirm database migrations approach
- [ ] Validate API design with team
- [ ] Check accessibility requirements

#### Core Implementation
- [ ] Database schema and migrations
- [ ] API endpoints with validation
- [ ] Frontend components with tests
- [ ] Integration with existing auth/permissions
- [ ] Error handling and logging

#### Validation
- [ ] Unit tests (minimum 80% coverage)
- [ ] Integration tests for API
- [ ] E2E tests for critical paths
- [ ] Performance benchmarks met
- [ ] Security review completed

### 4. Risk Analysis

#### Technical Risks
- **Breaking Changes**: [List any backward compatibility issues]
- **Performance Impact**: [Database queries, API load]
- **Security Concerns**: [Data exposure, permission gaps]

#### Mitigation Strategies
- Feature flags for gradual rollout
- Database indexes for performance
- Rate limiting for API endpoints
- Audit logging for sensitive operations

### 5. Dependencies and Integration

#### External Dependencies
```json
{
  "new-package": "^1.0.0",
  "existing-upgrade": "^2.0.0 -> ^3.0.0"
}
```

#### Internal Dependencies
- Services: [List services that need updates]
- Shared components: [List reusable components]
- Configuration: [Environment variables needed]

### 6. Testing Strategy

#### Unit Tests
```typescript
describe('Feature', () => {
  test('core functionality', () => { ... });
  test('edge cases', () => { ... });
  test('error handling', () => { ... });
});
```

#### Integration Tests
- API endpoint testing with supertest
- Database transaction testing
- Authentication/authorization flows

#### Manual Testing Checklist
- [ ] Happy path user flow
- [ ] Error state handling
- [ ] Mobile responsiveness
- [ ] Accessibility (keyboard nav, screen readers)
- [ ] Performance under load

### 7. Rollout Plan

#### Phase 1: Internal Testing
- Deploy behind feature flag
- Limited access to internal users
- Monitor error rates and performance

#### Phase 2: Beta Release
- Enable for % of users
- Gather feedback and metrics
- Fix critical issues

#### Phase 3: General Availability
- Full rollout
- Documentation updates
- Support team training

### 8. Success Metrics

#### Quantitative
- Feature adoption rate: [target %]
- Performance metrics: [response time targets]
- Error rate: [< threshold]

#### Qualitative
- User satisfaction score
- Support ticket reduction
- Developer experience feedback

## Phase 4: PRP Preparation

### Research Links
Collect during analysis:
- API documentation: [urls]
- Library docs: [urls]
- Design patterns: [urls]
- Security best practices: [urls]

### Code References
- Similar implementations: `path/to/file.ts:line`
- Pattern examples: `path/to/example.ts:line`
- Test examples: `path/to/test.spec.ts:line`

### Outstanding Questions
- [ ] Technical decisions needed
- [ ] Architecture review required
- [ ] Performance optimization approach

## Output

### Primary Spec
Save to: `docs/specs/{feature-name}-spec.md`

### Supporting Artifacts
- `docs/specs/{feature-name}-api.yaml` - OpenAPI spec
- `docs/specs/{feature-name}-db.sql` - Database changes
- `docs/specs/{feature-name}-tests.md` - Test plan

### Validation
Run after generation:
```bash
# Validate spec completeness
grep -c "TODO\|TBD\|FIXME" docs/specs/{feature-name}-spec.md
# Check for broken references
grep -o "path/to/.*\.ts:[0-9]*" docs/specs/{feature-name}-spec.md | while read ref; do
  file=$(echo $ref | cut -d: -f1)
  [ -f "$file" ] || echo "Missing: $file"
done
```

## Usage Notes

This command now:
1. Automatically analyzes your codebase for patterns
2. Calculates complexity scores
3. Generates actionable, specific specifications
4. Prepares for PRP generation
5. Includes validation and rollout planning
6. Provides testable success criteria

The spec is no longer just documentation - it's a blueprint for implementation.
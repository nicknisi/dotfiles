---
name: gpt5-consultant
description: Use this skill when stuck in circular debugging, when solutions aren't working despite multiple attempts, or when the user expresses frustration with lack of progress. Bring in GPT-5 as a third-party consultant to provide fresh perspective on complex technical problems, architectural decisions, or multi-system debugging issues. Ideal when you've tried multiple approaches without success, when the problem involves obscure edge cases or novel challenges, or when a second expert opinion would help break through an impasse. Gather all context from the conversation so far and present it comprehensively to GPT-5.
---

# GPT-5 Consultant Skill

Leverage GPT-5's advanced analytical capabilities for complex technical research and problem-solving.

## Prerequisites

This skill requires the gpt5-mcp-server to be installed and running locally.

Verify the following tools are available:
- `mcp__gpt5-server__gpt5_generate` (single-shot analysis)
- `mcp__gpt5-server__gpt5_messages` (multi-turn conversations)

If not available, check your MCP configuration and ensure the server is running.

## When to Use GPT-5

**Recognize the signs you're stuck:**
- Multiple attempts at the same problem without progress
- Going in circles with different approaches that all fail
- User expressing frustration ("this isn't working", "we're stuck", "nothing's helping")
- Solutions that should work but don't for unclear reasons
- Debugging that reveals more questions than answers

**Use GPT-5 for:**
- Breaking through impasses where standard approaches have failed
- Complex architectural decisions requiring expert judgment
- Debugging issues involving multiple interacting systems or obscure edge cases
- Novel technical challenges without established documentation
- Getting a fresh perspective when you're too close to the problem

**Do NOT use GPT-5 for:**
- Questions easily answered by existing documentation or API references
- Common patterns with established solutions
- First attempt at debugging (try standard research first)

When you notice circular debugging or lack of progress, pause and consult GPT-5. Present all context from the conversation so far.

## Workflow

### 1. Context Gathering

When stuck in a circular debugging situation, gather everything from the conversation:

**What to include:**
- Original problem description and what you're trying to achieve
- Every approach attempted so far and why each failed
- All error messages encountered (include full stack traces)
- Code changes made during debugging attempts
- User's expressions of frustration or confusion (they indicate important dead ends)
- Any patterns you've noticed (intermittent failures, specific conditions)
- Current system state and constraints

**How to organize it:**
```markdown
**Original Goal:**
[What we're trying to accomplish]

**Timeline of Attempts:**
1. First approach: [what we tried] → Result: [why it didn't work]
2. Second approach: [what we tried] → Result: [why it didn't work]
3. [etc.]

**Current Status:**
[Where we are now, what's still broken]

**Technical Details:**
[Code snippets, errors, config - the concrete facts]

**Why We're Stuck:**
[What's confusing, where the circular logic is happening]
```

**Context management:**
- Include the full debugging journey, not just the current state
- Highlight where you've gone in circles (tried similar things multiple times)
- Note what seemed promising but failed
- Prioritize: patterns of failure > error messages > code > architecture

### 2. Query Formulation

Craft precise, context-rich queries:

```markdown
**Problem Context:**
[Brief description of the system and what you're trying to achieve]

**Current Situation:**
[What's happening vs what should happen]

**What You've Tried:**
[Previous attempts and their results]

**Technical Details:**
[Code snippets, error messages, relevant config]

**Specific Questions:**
1. [Concrete question about the problem]
2. [Alternative approaches to consider]
3. [Edge cases or implications to watch for]
```

**Query optimization:**
- Include actual error messages, not descriptions of errors
- Provide concrete code examples, not abstract patterns
- Specify desired depth: architectural overview vs implementation details
- Request multiple perspectives for architectural decisions

### 3. Tool Selection

**Single-shot analysis** (`gpt5_generate`):
```javascript
{
  input: "Your complete context and question here",
  reasoning_effort: "high",  // high=architecture/novel, medium=debugging, low=straightforward
  instructions: "Optional system instructions"
}
```

**Multi-turn conversation** (`gpt5_messages`):
```javascript
{
  messages: [
    {role: "user", content: "Initial context and question"},
    {role: "assistant", content: "GPT-5's previous response"},
    {role: "user", content: "Follow-up question"}
  ],
  reasoning_effort: "medium"
}
```

Use messages for:
- Follow-up questions on previous responses
- Iterative refinement of solutions
- Drilling into implementation details after architectural overview

### 4. Quality Validation

After receiving GPT-5's response, verify:

**Completeness:**
- Does it address all aspects of the original question?
- Are edge cases covered?
- Are assumptions stated clearly?

**Feasibility:**
- Can recommendations be implemented with current tech stack?
- Are time/resource constraints considered?
- Do suggestions align with stated requirements?

**Confidence assessment:**
- High: Specific code examples, references to docs, clear reasoning
- Medium: Multiple approaches suggested, some uncertainty noted
- Low: Speculative language, missing details, contradictions

**When to iterate:**
- Response seems incomplete or contradictory
- Edge cases aren't addressed
- Implementation details are vague
- Recommendations conflict with requirements

Ask follow-up questions using `gpt5_messages` to build on previous context.

### 5. Result Synthesis

Present findings with:

**Summary:**
- Key insights in 2-3 sentences
- Confidence level (high/medium/low)

**Recommendations:**
Ranked by priority and impact:
1. Immediate action (what to do first)
2. Secondary improvements
3. Long-term considerations

**Next Steps:**
- Specific actions to take
- Time estimates where possible
- What to validate before implementing

**Warnings:**
- Potential pitfalls identified by GPT-5
- Assumptions that need verification
- Areas requiring additional research

## Common Patterns

**Architectural decisions:**
```bash
Query: "Should we use event sourcing or CRUD for financial transactions?"
Reasoning effort: high
Follow-up: Ask about specific implementation challenges for chosen approach
```

**Debugging distributed systems:**
```bash
Query: Include full error logs, system topology, timing diagrams
Reasoning effort: medium
Follow-up: Request specific debugging steps based on diagnosis
```

**Novel technical challenges:**
```bash
Query: Describe the problem, what makes it novel, what research you've done
Reasoning effort: high
Follow-up: Deep dive on the most promising approach
```

## Error Handling

If GPT-5 is unavailable or returns errors:
- Fall back to comprehensive web search
- Consult official documentation
- Check relevant Stack Overflow discussions
- Consider if the problem actually needs GPT-5 or if simpler research suffices

Document that GPT-5 was unavailable and note when to retry.

## Examples

**Example 1: Circular debugging (the key use case)**
```
Input: "We've been debugging this Next.js API route for 2 hours and getting nowhere.

Original goal: Fix 500 error on POST /api/users endpoint

Attempts:
1. Added try-catch around Prisma query → Still throwing unhandled promise rejection
2. Changed async/await to .then().catch() → Same error
3. Added error middleware → Error not being caught by middleware
4. Wrapped entire handler in try-catch → Error happens before handler executes
5. User says: 'This makes no sense, we're missing something obvious'

Current status: UnhandledPromiseRejectionWarning persists

Technical details:
- Error: UnhandledPromiseRejectionWarning: PrismaClientValidationError
- Stack trace points to line that IS wrapped in try-catch
- Using Next.js 14 App Router, TypeScript 5.3, Prisma 5.8
- Code: 
  ```typescript
  export async function POST(req: Request) {
    try {
      const body = await req.json();
      const user = await prisma.user.create({ data: body });
      return Response.json(user);
    } catch (error) {
      console.error('Caught error:', error); // This never logs
      return Response.json({ error: 'Failed' }, { status: 500 });
    }
  }
  ```
- The error happens, but catch block never executes
- Other API routes with identical pattern work fine

Why we're stuck: Try-catch should catch this. Error middleware should catch this.
Nothing is catching it. What are we fundamentally misunderstanding about Next.js error handling?"

Reasoning effort: high
```

**Example 2: TypeScript type inference breaking**
```
Input: "TypeScript infers the wrong type and I can't figure out why.

Context: Building a generic API client with typed responses.
Code works but types are broken:

```typescript
async function apiCall<T>(endpoint: string): Promise<T> {
  const res = await fetch(endpoint);
  return res.json(); // TypeScript infers 'any' here, not 'T'
}

const user = await apiCall<User>('/api/user');
// user is typed as 'any', not 'User'
```

Tried:
1. Explicit return type annotation → Still infers 'any'
2. Type assertion (as T) → Works but defeats the purpose
3. Generic constraints → No change
4. Different tsconfig settings → No improvement

Question: Why isn't TypeScript propagating the generic type through the promise chain?
What's the proper pattern for typed API clients?"

Reasoning effort: medium
```

**Example 3: React hook dependency array confusion**
```
Input: "useEffect running infinitely despite correct dependencies.

Code:
```typescript
const [filters, setFilters] = useState({ status: 'active', sort: 'name' });

useEffect(() => {
  fetchUsers(filters);
}, [filters]); // This causes infinite re-renders
```

Tried:
1. Memoizing filters with useMemo → Still infinite
2. JSON.stringify in dependency array → Works but feels wrong
3. Separate state for each filter → Messy, too many useState calls
4. Using useCallback on fetchUsers → No change

Every solution feels hacky. What's the right pattern for object dependencies?"

Reasoning effort: medium
```

**Example 4: Follow-up iteration**
```
Messages: [
  {role: "user", content: "[Initial question about NextAuth session type errors]"},
  {role: "assistant", content: "[GPT-5's recommendation to use module augmentation]"},
  {role: "user", content: "You suggested module augmentation for NextAuth types. 
   I added the declaration file but TypeScript still doesn't recognize the custom 
   session properties. Do I need to configure something in next-auth.d.ts or is 
   there a specific import pattern I'm missing?"}
]

Reasoning effort: medium
```
```
Input: "Choosing between GraphQL and REST for new API.
Context: Mobile app + web dashboard, 50+ endpoints, real-time updates needed.
Constraints: Team has REST experience, 3-month timeline.
Question: Which approach and why? What are the implementation risks?"

Reasoning effort: high
```

**Example 3: Follow-up iteration**
```
Messages: [
  {role: "user", content: "[Initial question about microservices architecture]"},
  {role: "assistant", content: "[GPT-5's architectural recommendation]"},
  {role: "user", content: "You suggested event sourcing for service communication. 
   How would we handle eventual consistency in the user profile service?"}
]

Reasoning effort: medium
```

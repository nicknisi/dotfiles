Debug a failing Jest test: $ARGUMENTS

Systematic debugging approach:

1. Run the specific test with verbose output
   `npx jest path/to/test.test.js --verbose`

2. Read the test file to understand what it's testing
   - Check test descriptions and expectations
   - Understand the test setup and teardown

3. Examine the error message and stack trace carefully
   - Note line numbers and assertion failures
   - Check for timeout or async issues

4. Search for the implementation of the failing function
   - Review the code under test
   - Check imports and dependencies

5. Check recent git commits that might have introduced the issue
   `git log -p -- path/to/file`

6. Add debug print statements if needed
   - Use console.log() strategically (remember to remove later)
   - Or use debugger; statements with Node inspector

7. Consider these common issues in Jest tests:
   - Async test completion problems (missing await or done())
   - Mock/spy setup issues
   - State leaking between tests
   - Timezone or environment differences
   - Snapshot test failures

8. Write a minimal reproduction case if the issue is complex
   - Isolate the failing behavior

9. Fix the issue and verify all related tests still pass
   `jest --testPathPattern=path/to/related`

10. Clean up any debug code and run linting
    `npm run lint -- --fix`

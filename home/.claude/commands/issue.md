Please analyze and fix the GitHub issue: $ARGUMENTS.

Follow these steps:

# PLAN

1. Use `gh issue view` to get the issue details
2. Understand the problem described in the issue
3. Search the codebase for relevant files
4. Understand the prior art for this issue
    - Search the scratchpads for previous thoughts related to this issue
    - Search PRs to see if you can find history on this issue
    - Search the codebase for relevant files
5. Think  harder about how to break the issue down into a series of small, manageable tasks
6. Document your plan in a new scratchpad
    - Include the issue name in the filename
    - Include a link to the issue in the scratchpad
6. Ensure code passes linting and type checking

# CREATE 

- Create a new branch for the issue
- Solve the issue in small, manageable steps, according to your plan
- Commit your changes after each step

# TEST

- Run the full test suite to ensure you haven't broken anything
- If the tests are failing, fix them
- Ensure that all the tests are passing before moving them on to the next step.

Remember to use the GitHub CLI (`gh`) for all GitHub-related tasks.

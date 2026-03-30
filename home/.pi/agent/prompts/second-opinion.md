---
description: "Get a second opinion from a specific model (usage: /second-opinion opus <task>)"
---
Use the `model_workflow` tool with:
- `workflow: "single"`
- `agent: "$1"`
- `task: "Give a second opinion on the following request. Focus on flaws, blind spots, missed edge cases, and a better alternative if you see one.\n\n${@:2}"`

Return the delegated model's answer directly.

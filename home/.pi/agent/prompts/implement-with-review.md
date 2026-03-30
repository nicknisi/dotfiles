---
description: GPT implements, Opus reviews, GPT applies the feedback
---
Use the `model_workflow` tool with:
- `workflow: "implement_with_review"`
- `task: "$@"`

Have GPT implement first, Opus review second, and GPT apply the review feedback last.
Return the final implementation summary directly.

---
description: 'Compare two models on the same task (usage: /compare-models <model1> <model2> <task>). Example: /compare-models moonshotai/kimi-k3 z-ai/glm-5.2 best design for X'
---

Run the `workflow` tool with this script (pass `$1` as `m1`, `$2` as `m2`, `${@:3}` as `task` in `args`):

```js
export const meta = { name: 'compare_models', description: 'Compare two models on the same task' };
const { m1, m2, task } = args;
const [a, b] = await parallel([
  () => agent(`Answer the following concisely:\n\n${task}`, { model: m1 }),
  () => agent(`Answer the following concisely:\n\n${task}`, { model: m2 }),
]);
return `## Model 1 (${m1})\n${a}\n\n## Model 2 (${m2})\n${b}`;
```

Return both answers verbatim, labeled with their model IDs, so I can compare.

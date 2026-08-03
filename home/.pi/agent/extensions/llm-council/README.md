# llm-council

Convene an LLM Council — multiple models answer a question independently, then a
chairman synthesizes their answers into a unified response. Progress streams
inline with animated spinners, member status, and elapsed time; collapse/expand
to see full member responses.


## How it works

1. **Members** — each council member (a different LLM) receives the same question
   and answers independently, in parallel.
2. **Chairman** — a chairman model receives all member answers (anonymously) and
   synthesizes the best unified response.

## Tool

Registered as `llm_council`.

| Parameter | Type | Description |
|-----------|------|-------------|
| `question` | `string` | The question to pose to the council |

### When to use

- Questions that benefit from multiple perspectives or cross-checking
- When accuracy matters — divergent answers flag uncertainty
- Not for simple factual questions or routine tasks

## Default council

Defaults to models from `~/.pi/agent/settings.json` `enabledModels`:

| Role | Model | Label |
|------|-------|-------|
| Member | GLM 5.2 (fireworks) | Member A |
| Member | Kimi K3 (fireworks) | Member B |
| Member | Claude Fable 5 (anthropic) | Member C |
| Chairman | Claude Opus 5 (anthropic) | Chairman |

Members run as lightweight subprocesses with a built-in read-only tool set
(`read`, `grep`, `find`, `ls`), no extensions, no skills. The chairman has no
tools — it only synthesizes.

## Configuration

Two layers, deep-merged at call time:

1. **Global** — `~/.pi/agent/configs/llm-council.json` (copy
   [`llm-council.example.json`](llm-council.example.json)).
2. **Project-local** — `<cwd>/.pi/configs/llm-council.json` (copy
   [`llm-council.project.example.json`](llm-council.project.example.json)).

The project-local file deep-merges over the global one, so it only needs the
keys that differ — typically just `member.council` and `chairman.model` to get a
different lineup for work vs personal projects. Drop one file in each project
root whose council should differ.

### Member options (`member`)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `council` | `object[]` | *(3 members above)* | Each requires `model` and `label`. Optional: `displayName`, `systemPrompt` |
| `defaultSystemPrompt` | `string` | *(built-in)* | System prompt for members without their own |
| `display.labelColor` | `string` | `"accent"` | Member label color (theme token or hex) |
| `display.modelColor` | `string` | `"dim"` | Model name color |
| `tools` | `string[] \| null` | `["read","grep","find","ls"]` | Tools for members. `null` = pi defaults, `[]` = none |
| `thinking` | `string \| null` | `"medium"` | Thinking level. `null` = pi default |
| `extensions` | `string[] \| null` | `[]` | Extensions for members (by name; resolved to `~/.pi/agent/extensions/<name>/...`). `null` = pi defaults |
| `skills` | `string[] \| null` | `[]` | Skills for members. `null` = pi defaults |
| `contextFiles` | `boolean` | `false` | Whether members see project context files |

### Chairman options (`chairman`)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `model` | `string` | `"anthropic/claude-opus-5"` | Chairman model |
| `displayName` | `string` | `"Claude Opus 5"` | Human-readable name for UI |
| `systemPrompt` | `string` | *(built-in)* | Chairman system prompt |
| `exposePersonas` | `boolean` | `true` | Include member system prompts in chairman input |
| `display.icon` | `string` | `""` | Icon prefix |
| `display.labelColor` / `display.modelColor` | `string` | `"accent"` / `"dim"` | Colors |
| `tools` | `string[] \| null` | `[]` | Chairman tools (none by default) |
| `thinking` | `string \| null` | `"medium"` | Thinking level |
| `extensions` / `skills` | `string[] \| null` | `[]` | Extensions / skills |
| `contextFiles` | `boolean` | `false` | Whether chairman sees project context files |

### Shared display options (`shared`)

All cosmetic — spinner frames/interval/color, success/error prefixes, branch
prefix, status labels/colors, tool header colors, expand-hint color, question
preview length. See `llm-council.example.json` for the full set. These are read
from the **global** config only (project-local overrides don't apply to `shared`).

### Color values

Color fields accept pi theme tokens (`"text"`, `"accent"`, `"success"`,
`"error"`, `"muted"`, `"dim"`, `"separator"`, `"toolTitle"`, …) and hex values
(`"#ff6600"`).

### Notes on `extensions` / `skills`

Members default to no extensions and no skills, so they run as lightweight
subprocesses with just the built-in read-only tools. An `extensions` entry is
resolved to `~/.pi/agent/extensions/<name>/src/index.ts`,
so it only matches directory-style extensions with that layout — not this
setup's single-file `.ts` extensions or npm packages. Keep `extensions: []`.

Skills entries resolve to `~/.pi/agent/skills/<name>/SKILL.md`; this setup has
no skills there, so keep `skills: []`.

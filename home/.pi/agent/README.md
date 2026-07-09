# Nick's Pi Agent Setup

This directory is the user-level Pi configuration. On this machine `~/.pi` is symlinked into the dotfiles repo:

```txt
~/.pi -> ~/Developer/dotfiles/home/.pi
```

## Core settings

Main config:

```txt
~/.pi/agent/settings.json
```

Current highlights:

- Default provider: `openai-codex`
- Default model: `gpt-5.5`
- Theme: `catppuccin-mocha`
- Skills loaded from:
  - `~/.claude/skills`
  - `~/Developer/claude-plugins/plugins/*/skills`
- Packages:
  - `npm:pi-subagents`
  - `git:github.com/ghoseb/pi-askuserquestion`
  - `npm:pi-prompt-template-model`
  - `../../Developer/claude-plugins`

## Installed local extensions

Local extensions live in:

```txt
~/.pi/agent/extensions/
```

Notable extensions:

| Extension | Purpose |
| --- | --- |
| `mcp/` | Pi-native MCP bridge inspired by OMP MCP support. |
| `agent-urls.ts` | OMP-style `agent://` and `history://` readers for `pi-subagents` runs. |
| `handoff.ts` | Generate handoff prompts for new focused sessions. |
| `review.ts` | Code-review workflow inspired by Codex review. |
| `dynamic-skills.ts` | Claude-style dynamic `!\`command\`` expansion inside skills. |
| `model-workflows/` | Multi-model workflow helpers. |
| `statusline.ts` | Custom statusline. |
| `auto-theme.ts` | Theme automation. |

After editing extensions, reload Pi:

```txt
/reload
```

## MCP bridge

Config:

```txt
~/.pi/agent/mcp.json
```

The MCP bridge intentionally does **not** auto-import global editor configs like `~/.cursor/mcp.json`. Imports are explicit via:

```json
{
  "importConfigs": ["~/.claude.json"]
}
```

Current behavior:

- Loads Pi's own MCP config from `~/.pi/agent/mcp.json`.
- Explicitly imports Claude's MCP config from `~/.claude.json`.
- Pi-local servers override imported servers with the same name.
- Discovery mode is `auto`, so large MCP catalogs can stay gated until activated.

Current expected servers:

| Server | Source | Notes |
| --- | --- | --- |
| `sessions` | `~/.pi/agent/mcp.json` | Local sessions MCP server. |
| `omnifocus-operator` | `~/.claude.json` | OmniFocus MCP tools. |
| `devin` | `~/.claude.json` | Devin MCP tools. |
| `raindrop` | `~/.claude.json` | Currently unauthorized unless auth is fixed or server is disabled. |

Useful commands:

```txt
/mcp list
/mcp list sessions
/mcp list --verbose
/mcp reload
/mcp test sessions
/mcp disable raindrop
/mcp enable raindrop
/mcp resources [server]
/mcp prompts [server]
```

Agent-facing helper tools:

```txt
mcp_search_tools
mcp_list_resources
mcp_read_resource
mcp_list_prompts
mcp_get_prompt
```

Sessions MCP tools expected after load:

```txt
mcp__sessions_search_sessions
mcp__sessions_get_session_messages
mcp__sessions_get_activity_digest
mcp__sessions_get_session_metrics
```

## Subagents

Subagents come from the Pi package:

```json
"packages": ["npm:pi-subagents"]
```

This is **not** OMP's subagent implementation. It is Pi-native, but we are porting some OMP-style UX around it.

Useful slash commands from `pi-subagents` include:

```txt
/run
/chain
/parallel
/run-chain
/subagents-doctor
```

Builtin agents usually available:

```txt
scout
planner
worker
reviewer
context-builder
researcher
delegate
oracle
```

Custom user agents currently include:

```txt
gpt
opus
synthesizer
reviewer
```

## OMP-inspired subagent URLs

Extension:

```txt
~/.pi/agent/extensions/agent-urls.ts
```

This adds an OMP-style URL layer over `pi-subagents` artifacts and session files.

Human commands:

```txt
/agent list
/agent read agent://<runId>
/agent read history://<runId>
/agent read history://<runId>/<childIndex>
```

Agent-facing tools:

```txt
list_agent_runs
read_agent_url
```

Examples:

```txt
agent://3ad48d49
history://3ad48d49/0
agent://3ad48d49/0/output
agent://3ad48d49/0/log
agent://3ad48d49/0/session
```

What the schemes mean:

| Scheme | Meaning |
| --- | --- |
| `agent://<runId>` | Summary of a subagent run and its children. |
| `history://<runId>` | Rendered child transcript(s). |
| `history://<runId>/<childIndex>` | Rendered transcript for one child. |
| `agent://<runId>/<child>/output` | Child output/log/final assistant response when available. |

## OMP ideas already ported or partially ported

| OMP idea | Pi-native equivalent here |
| --- | --- |
| MCP discovery/config | `extensions/mcp/` bridge + `~/.pi/agent/mcp.json` |
| Explicit imported MCP configs | `importConfigs` in `mcp.json` |
| Gated large tool catalogs | `discoveryMode: "auto"` + `mcp_search_tools` |
| `agent://` / `history://` | `extensions/agent-urls.ts` |
| Subagents | `pi-subagents` package |
| Handoff workflow | `handoff.ts` and handoff skill |
| Review workflow | `review.ts`, `reviewer`, `/parallel-review`, `/review-loop` |

## OMP ideas worth stealing next

Good next candidates:

1. `pr://` and `issue://` reader backed by `gh`.
2. General `uri_read` layer for `agent://`, `history://`, `pr://`, `issue://`, `skill://`, `mcp://`.
3. AST tools backed by `ast-grep`.
4. LSP tools for diagnostics, references, definitions, and rename.
5. Memory tools: `retain`, `recall`, `reflect`, probably backed by local files or Sessions MCP.
6. Path-scoped config profiles for WorkOS vs personal projects.

## Maintenance notes

Typecheck the MCP bridge:

```bash
cd ~/.pi/agent/extensions/mcp
npm run typecheck
```

Smoke-test extension loading with `/reload`, then:

```txt
/mcp list
/agent list
```

When committing dotfiles, avoid committing generated state unless intentional:

```txt
home/.pi/agent/npm/
home/.pi/agent/trust.json
```

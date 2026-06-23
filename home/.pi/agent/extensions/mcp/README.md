# Pi MCP Bridge

A Pi-native MCP bridge inspired by OMP's MCP design.

## What it steals

- `mcp.json` configuration files.
- Tool names like `mcp__<server>_<tool>`.
- stdio, streamable HTTP, and SSE transports.
- `/mcp` management command.
- Resource and prompt helper tools.
- On-demand activation for large MCP tool catalogs.

## Config files

Loaded in priority order, with higher-priority entries shadowing lower-priority entries by server name:

1. Repo/project standalone configs: `mcp.json`, `.mcp.json`, `.claude/mcp.json`, `.cursor/mcp.json`, `.vscode/mcp.json`, `.gemini/*`, `.windsurf/*`, `opencode.json`
2. User Pi config: `~/.pi/agent/mcp.json`
3. Project Pi config: `.pi/mcp.json`

Global editor configs like `~/.cursor/mcp.json` or `~/.claude.json` are intentionally not auto-imported. That is too surprising for a Pi extension. Opt in with `importConfigs` instead:

```json
{
  "importConfigs": ["~/.claude.json"],
  "mcpServers": {}
}
```

Imported configs load just below the importing file's priority, so servers in `~/.pi/agent/mcp.json` override servers imported from Claude or another tool.

## Example

```json
{
  "$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
  "discoveryMode": "auto",
  "disabledServers": [],
  "importConfigs": ["~/.claude.json"],
  "mcpServers": {
    "fs": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "${HOME}/Developer"]
    },
    "linear": {
      "type": "http",
      "url": "https://mcp.linear.app/sse",
      "headers": {
        "Authorization": "Bearer ${LINEAR_TOKEN}"
      }
    }
  }
}
```

`${VAR}` and `${VAR:-default}` are expanded in command, args, env, cwd, url, and headers.

## Commands

- `/mcp list`
- `/mcp reload`
- `/mcp test [server]`
- `/mcp resources [server]`
- `/mcp prompts [server]`
- `/mcp add <name> { ...server config json... }`
- `/mcp remove <server>`
- `/mcp disable <server>`
- `/mcp enable <server>`

OAuth and Smithery commands are intentionally stubbed for now; prefer header/env auth first.

## Bridge tools

Always-available helper tools:

- `mcp_search_tools`
- `mcp_list_resources`
- `mcp_read_resource`
- `mcp_list_prompts`
- `mcp_get_prompt`

Server tools are registered as `mcp__<server>_<tool>`.

## Discovery modes

Set `discoveryMode` in `~/.pi/agent/mcp.json`:

- `auto`: hide individual MCP tools when the catalog exceeds 40 tools; use `mcp_search_tools` to activate matches.
- `all`: keep all MCP tools active.
- `mcp-only`: hide individual MCP tools until searched/activated.
- `off`: keep individual MCP tools inactive.

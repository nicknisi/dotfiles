# Dotfiles

Nick Nisi's dotfiles repo. Manages configs for zsh, neovim, tmux, ghostty, git, and Claude Code.

## Structure

- `home/` — Files symlinked to `~/` (dotfiles like `.zshenv`, `.claude/`)
- `config/` — App configs symlinked into `~/.config/` (nvim, tmux, zsh, git, etc.)
- `bin/` — Scripts added to `$PATH` (claude-statusline, git helpers, etc.)
- `tools/` — Tooling and helpers

## Setup

```bash
mise bootstrap --yes --skip-dirty                 # Converge the machine
mise bootstrap dotfiles apply                     # Link all packages
mise bootstrap dotfiles apply ~/.config/nvim      # Link one package
mise bootstrap dotfiles unapply                   # Remove links
```

## Key conventions

- `config/` dirs map 1:1 to `~/.config/<name>/`
- `home/` entries are symlinked directly to `~/`
- Claude Code settings live in `home/.claude/settings.json` → `~/.claude/settings.json`
- Shell entry point: `home/.zshenv` → `~/.zshenv`, loads `config/zsh/.zshrc`

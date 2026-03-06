# Dotfiles

Nick Nisi's dotfiles repo. Manages configs for zsh, neovim, tmux, ghostty, git, and Claude Code.

## Structure

- `home/` — Files symlinked to `~/` (dotfiles like `.zshenv`, `.claude/`)
- `config/` — App configs symlinked into `~/.config/` (nvim, tmux, zsh, git, etc.)
- `bin/` — Scripts added to `$PATH` (dot, claude-status-hook, etc.)
- `resources/` — Fonts, themes, static assets
- `tools/` — Tooling and helpers

## Setup

```bash
bin/dot link          # Symlink all packages
bin/dot link nvim     # Symlink single package
bin/dot unlink        # Remove symlinks
bin/dot backup        # Backup existing before linking
```

## Key conventions

- `config/` dirs map 1:1 to `~/.config/<name>/`
- `home/` entries are symlinked directly to `~/`
- Claude Code settings live in `home/.claude/settings.json` → `~/.claude/settings.json`
- Shell entry point: `home/.zshenv` → `~/.zshenv`, loads `config/zsh/.zshrc`

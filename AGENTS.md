# AGENTS.md

Guidance for OpenCode agents in this dotfiles repo. Trust `install.sh` and the
actual config files over `README.md` prose — several README sections were stale
and have been fixed, but always verify against the source.

## Repo shape
- Personal dotfiles (forked from nicknisi/dotfiles). No build/test/lint/CI,
  no package manifest. Verification is manual: run `install.sh`, open zsh/nvim/tmux.
- Default branch `main`. Conventional commits (`feat(scope):`, `fix(scope):`,
  `chore(scope):`, `refactor(scope):`); merged via PRs.
- Target environment: WSL2 (Ubuntu) + WezTerm + tmux + Neovim.

## Symlink install model (core mechanism)
`install.sh link` symlinks config into `$HOME`:
- `**/*.symlink` -> `~/.<basename>` (`.symlink` stripped). E.g. `zsh/zshrc.symlink`
  -> `~/.zshrc`, `zsh/p10k.zsh.symlink` -> `~/.p10k.zsh`.
- Each top-level entry in `config/` -> `~/.config/<entry>`. E.g. `config/nvim`
  -> `~/.config/nvim`; `config/git/config` is the source of `~/.gitconfig`.

Editing these files edits the live linked config. To add a new tool config, drop
it under `config/<tool>/` and re-run `./install.sh link`.

## install.sh subcommands
`{backup|link|git|homebrew|ohmyzsh|shell|all}`.
- `all` runs only `link`, `homebrew`, `git`, `ohmyzsh`, `shell`. It does **not**
  run `backup` — run that manually if needed.
- The brew subcommand is `homebrew` (not `brew`). It runs `brew bundle` against
  `Brewfile`, then installs fzf keybindings.
- `git` writes `~/.gitconfig-local` (machine-specific, not in repo).

## zsh wiring
- `$DOTFILES` (set in `zsh/zshenv.symlink` via readlink resolution) = repo root.
  Many configs depend on it.
- `zshrc.symlink` sources every `$DOTFILES/**/*.zsh` — a new `*.zsh` file
  auto-loads. `zsh/functions/` is on `fpath` (autoloadable: `g`, `md`,
  `prepend_path`).
- Shell is oh-my-zsh + powerlevel10k (installed to `$DOTFILES/zsh/.oh-my-zsh`,
  gitignored).
- Machine-local overrides (sourced if present, not in repo): `~/.localrc`,
  `~/.zshrc.local`, `~/.zshenv.local`, `~/.gitconfig-local`.

## Neovim (AstroNvim v6)
- Entry `config/nvim/init.lua` bootstraps lazy.nvim -> `lua/lazy_setup.lua` ->
  imports `community` (`lua/community.lua`, astrocommunity packs) +
  `lua/plugins/*.lua` (user plugin specs).
- Plugins auto-install on first `nvim` launch. `lazy-lock.json` is gitignored
  (not a committed lockfile). Headless sync: `nvim --headless "+Lazy! sync" +qa`
  or `:Lazy` inside Neovim.
- Lua formatting = StyLua per `config/nvim/.stylua.toml` (4-space, 120 col,
  `call_parentheses = None`). Do NOT use the root `.lua-format` (2-space,
  different tool) for nvim Lua.
- Leader `<Space>`, localleader `,`.
- Neovim 0.11+ has built-in OSC52 clipboard support — `"+y` reaches the Windows
  clipboard via tmux `set-clipboard external` -> Wezterm OSC52, with zero config.

## AI: avante.nvim <-> opencode-go
`config/nvim/lua/plugins/ai.lua` wires avante.nvim to a custom `opencode-go`
provider (endpoint `https://opencode.ai/zen/go/v1`, model `deepseek-v4-pro`).
The key env var `OPENCODE_GO_API_KEY` is auto-exported by `zshrc.symlink`
(from `~/.local/share/opencode/auth.json` via `jq`) — requires an opencode CLI
login and `jq`. Add/change models in `ai.lua`'s `list_models`.

## tmux
- Prefix is `M-s` (Alt+s). `prefix + I` installs TPM plugins.
- TrueColor override: `terminal-overrides ",xterm-256color:Tc,wezterm:Tc"` —
  covers both TERM values Wezterm may set.
- TPM init `run '$HOMEBREW_PREFIX/opt/tpm/share/tpm/tpm'` requires
  `$HOMEBREW_PREFIX` (set by `zprofile.symlink` on macOS/Linuxbrew).
- tmux-resurrect restores `~gemini copilot opencode`. Plugins live in
  `config/tmux/plugins/` (gitignored).
- Pane navigation: `M-h/j/k/l` (no prefix) via tmux.nvim, seamless with neovim.

## git config
- `config/git/config` -> `~/.gitconfig`. `pull.rebase = true`,
  `push.default = current`, pager is `delta`, `core.editor` is `vim`
  (not `nvim`). Credential helper is per-OS via `~/.gitconfig-local`
  (written by `install.sh git` — no hardcoded helper in the committed config).

## Linux testing
`Dockerfile` builds an Ubuntu image injecting SSH keys via
`--build-arg PRIVATE_KEY/PUBLIC_KEY` to test the linux install path:
`docker build -t dotfiles --build-arg PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" \
  --build-arg PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)" .` then `docker run -it --rm dotfiles`.

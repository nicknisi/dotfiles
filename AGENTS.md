# AGENTS.md

Guidance for OpenCode agents in this dotfiles repo. Trust `install.sh` and the
actual config files over `README.md` prose — several README sections were stale
and have been fixed, but always verify against the source.

## Repo shape
- Personal dotfiles (forked from nicknisi/dotfiles). No build/test/lint/CI,
  no package manifest. Verification is manual: run `install.sh`, open zsh/nvim/tmux.
- Default branch `main` (protected — never push directly). Workflow is GitHub
  Flow: create a feature branch
  (`{feat|fix|docs|refactor|chore|perf|test|build|ci|revert|style}/<scope>`), push
  it, open a PR with `gh pr create`. Merges on GitHub squash into one commit
  titled `<PR title> (#N)`.
- Conventional Commits is required for **both PR titles and commit messages**
  — squash makes the PR title the permanent main-history entry. Format:
  `type(scope): <lowercase imperative subject, ≤72 chars>`.
  - type: `feat fix docs style refactor perf test build ci chore revert`.
    Breaking change: `type(scope)!:` or `BREAKING CHANGE:` footer.
  - scope: tool/module name (`zsh nvim tmux git alacritty wezterm brew install
    agents yazi ai codegraph`); multiple scopes comma-separated, e.g. `feat(zsh,config):`.
  - body: `feat/fix/refactor/perf` recommended — write "why" not "what" (the
    diff shows what), use `-` bullets, ≤72 chars/line, blank line after subject.
    `chore/style/revert` and simple single-file changes may omit.
    `BREAKING CHANGE:`/`Co-authored-by:` go in the footer.
  - squash merge copies the PR description into the commit body — a good PR
    description is a readable main history.
- Target environment: WSL2 (Ubuntu) + Alacritty (primary) / WezTerm (backup) + tmux + Neovim.

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
  auto-loads. `zsh/functions/` is on `fpath` (autoloadable: `occm`).
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

## OpenCode (opencode CLI config)
`config/opencode/` -> `~/.config/opencode/` via `install.sh link` (same
`config/<tool>` convention as atuin/yazi/alacritty). Three managed files:
- `opencode.json` — providers (`google` antigravity models), MCP servers
  (`context7` remote, `codegraph` local), `lsp: true` (diagnostic feedback),
  `permission` (safety gates: `rm`/force-push ask, rest allow), formatters
  (`clang-format`), plugins (`@franlol/opencode-md-table-formatter`). **No
  secrets here** — the former `bailian-coding-plan-test` provider with a
  hardcoded `apiKey` was removed; provider credentials live in
  `~/.local/share/opencode/auth.json` (never in repo).
- `AGENTS.md` — **global rules**, symlinked to
  `~/.config/opencode/AGENTS.md`, applied to every opencode session. Holds the
  web-fetching fallback strategy (context7 / Jina Reader / gh) and MCP usage
  priority rules (context7 for lib docs, codegraph for code structure). A
  project's own `AGENTS.md` layers on top and takes precedence.
- `commands/commit.md` — the `/commit` custom command (Conventional Commits
  message generator, reads staged diff + recent history + AGENTS.md).

Built-in `websearch` (Exa, free, no API key) is enabled globally via
`OPENCODE_ENABLE_EXA=1` in `zsh/zshenv.symlink` — required when not on the
opencode provider. LSP is on (`lsp: true`); lua-ls and clangd auto-install,
Python needs a manual `npm install -g pyright`. Disable a single server
per-project with `lsp.<name>.disabled: true`.

Runtime files opencode regenerates inside the symlinked dir are gitignored at
repo root: `node_modules/`, `package.json`, `package-lock.json`, `bun.lock`,
`antigravity-accounts.json*`, `antigravity-signature-cache.json`,
`antigravity-logs/`. The `oh-my-opencode` plugin was uninstalled (its config
file is not managed); `package.json` is regenerated from `opencode.json`'s
`plugin` array on next launch.

`occm` (`zsh/functions/occm`) is a shell function that runs
`opencode run --command commit "$@"` — i.e. it invokes the `/commit` command
defined in `config/opencode/commands/commit.md` headlessly. To add a new
custom command, drop `config/opencode/commands/<name>.md` (frontmatter +
template, per https://opencode.ai/docs/commands).

## CodeGraph (global code-knowledge MCP)
CodeGraph is a pre-indexed, 100% local knowledge graph of symbols/calls/deps
for AI coding agents (opencode, Claude Code, Cursor, etc.). Exposes one MCP
tool — `codegraph_explore` — that returns surgical context + call paths in a
single call instead of a grep/Read crawl. 20+ languages, auto-syncs on file
changes. Repo: https://github.com/colbymchenry/codegraph
- **CLI install**: `./install.sh codegraph` (idempotent). Not on Homebrew; the
  official installer bundles its own Node runtime and places `codegraph` on a
  user bin already on PATH (`~/.local/bin` via `zsh/zshenv.symlink`). Also run
  by `./install.sh all`. No Node dependency on the brew-managed `node`.
- **opencode MCP wiring**: `config/opencode/opencode.json` has a `codegraph`
  local MCP server (`["codegraph", "serve", "--mcp"]`, `enabled: true`).
  Configured manually — **do not** run `codegraph install` (it would rewrite
  agent configs and AGENTS.md out of band).
- **Per-project indexing is manual and NOT in this repo**: run `codegraph init`
  in each *code* project to build its `.codegraph/` graph. This dotfiles repo
  only does the *global* wiring (CLI + MCP config). Projects without a
  `.codegraph/` index degrade gracefully — CodeGraph tells the agent to use
  built-in tools.
- `.codegraph/` is gitignored at repo root as a safety net.
- Scope is **opencode only** here — this repo does not manage `~/.claude.json`
  or other agents' configs, so CodeGraph's Claude Code/Cursor wiring is out of
  scope for this dotfiles.

## tmux
- Prefix is `M-s` (Alt+s). `prefix + I` installs TPM plugins.
- TrueColor override: `terminal-overrides ",xterm-256color:Tc,wezterm:Tc,alacritty:Tc"` —
  covers the TERM values each terminal may set.
- TPM init `run '$HOMEBREW_PREFIX/opt/tpm/share/tpm/tpm'` requires
  `$HOMEBREW_PREFIX` (set by `zprofile.symlink` on macOS/Linuxbrew).
- tmux-resurrect restores `~gemini copilot opencode`. Plugins live in
  `config/tmux/plugins/` (gitignored).
- Pane navigation: `M-h/j/k/l` (no prefix) via tmux.nvim, seamless with neovim.

## Alacritty (primary terminal)
- Config at `config/alacritty/alacritty.toml` -> `~/.config/alacritty/` via `install.sh link`
  (WSLg fallback path). Windows build reads `%APPDATA%\alacritty\alacritty.toml`; soft-link
  that to the repo file via `\\wsl.localhost\<distro>\home\<user>\dotfiles\config\alacritty\alacritty.toml`
  so the repo stays the single source of truth.
- Default shell launches `wsl.exe ~ -d Ubuntu-22.04` directly (no launch_menu like WezTerm).
- `TERM=xterm-256color` is overridden in `[env]` because WSL lacks the alacritty terminfo
  by default; tmux's `xterm-256color:Tc` override already handles TrueColor. Switch to
  `alacritty:Tc` once `infocmp alacritty` succeeds in WSL.
- OSC52 clipboard works natively — `"+y` in nvim reaches the Windows clipboard through
  tmux `set-clipboard external`. Zero config, same path as WezTerm.
- No tab support by design — use tmux. URL hints: `Ctrl+Click` opens in Windows default
  browser via `cmd.exe /c start`.
- WezTerm config (`config/wezterm/wezterm.lua`) retained as backup terminal.

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

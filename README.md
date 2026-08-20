# Dotfiles

These are my actual dotfiles, not a starter kit. They assume Apple Silicon macOS, a checkout at `~/Developer/dotfiles`, and several of my other repositories under `~/Developer`. I keep them public so you can borrow the useful parts without pretending the whole setup is portable.

> [!NOTE]
> If you came here from my [vim + tmux](https://www.youtube.com/watch?v=5r6yzFEXajQ) talk, the repository at the time of that recording is [still available](https://github.com/nicknisi/dotfiles/tree/aa72bed5c4ecec540a31192581294818b69b93e2). The current setup is substantially different.

<img width="5142" height="3026" alt="Nick Nisi's terminal and editor setup" src="https://github.com/user-attachments/assets/00db0017-6792-4355-838c-50368b55fd9d" />

## What this sets up

| Area | Current choice |
| --- | --- |
| Machine setup | Mise bootstrap and tasks |
| Terminal | Ghostty, with WezTerm and Kitty configs still tracked |
| Shell and prompt | Homebrew zsh and Starship |
| Multiplexer | tmux |
| Editor | Neovim with lazy.nvim |
| Window management | AeroSpace, SketchyBar, Borders, and Karabiner-Elements |
| CLI agents | Pi and Claude Code |
| Agent orchestration | Fleet |
| Fonts and color | Monaspace, Symbols Nerd Font, Tokyo Night |

## Install

Run this on a Mac:

```bash
curl -fsSL https://raw.githubusercontent.com/nicknisi/dotfiles/main/install.sh | bash
```

The installer checks for Git, clones this repository, installs Mise, and runs one full bootstrap. On a Mac without the Xcode Command Line Tools, the first run opens Apple's installer and stops. Run the command again after the tools finish installing.

The bootstrap expects:

- Apple Silicon Homebrew paths under `/opt/homebrew`
- a working GitHub SSH key for the additional repositories declared in `[bootstrap.repos]`

After the install, open a new login shell and configure the machine-local Git identity:

```bash
mise run setup-git
```

The Git task asks for a name, email, and GitHub username, then writes `~/.gitconfig-local`. That file is included by the tracked Git config but never committed.

### Preview the install

```bash
curl -fsSL https://raw.githubusercontent.com/nicknisi/dotfiles/main/install.sh | bash -s -- --dry-run
```

Set `NO_COLOR=1` for plain output.

### Run it by hand

```bash
xcode-select --install # only when Git is missing

git clone https://github.com/nicknisi/dotfiles.git ~/Developer/dotfiles
curl -fsSL https://mise.run | sh
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

MISE_GLOBAL_CONFIG_FILE=~/Developer/dotfiles/config/mise/config.toml \
  mise bootstrap --yes
```

The explicit `MISE_GLOBAL_CONFIG_FILE` is only needed before bootstrap creates `~/.config/mise`.

## How bootstrap works

`config/mise/config.toml` is the machine manifest. A full `mise bootstrap` does the following work:

1. Runs the macOS pre-packages hook. That installs Homebrew, the macOS applications, and the fonts.
2. Installs the system packages from `[bootstrap.packages]`.
3. Clones the repositories from `[bootstrap.repos]`.
4. Applies the `[dotfiles]` symlinks.
5. Writes the macOS defaults and changes the login shell.
6. Installs the runtimes and command-line tools from `[tools]`.
7. Runs the `bootstrap` task to compile terminfo entries and register the repository's Git clean filter.

The installer points Mise at the cloned config, so the same manifest handles the first run and every later run.

### Mise tasks

```bash
mise tasks
```

| Task | Purpose |
| --- | --- |
| `mise run bootstrap` | Compile terminfo and register the `pi-settings` Git clean filter |
| `mise run install-homebrew` | Install Homebrew with the official installer if needed |
| `mise run setup-mac` | Install the macOS apps, fonts, SketchyBar, and Borders |
| `mise run setup-git` | Write the machine-local Git identity |
| `mise run update` | Update Neovim plugins, Homebrew, zsh plugins, Mise tools, uv tools, Pi extensions, and this repo |

<details>
<summary>Software managed by Mise</summary>

### Runtimes

- Node.js 24 and Python 3.14.7
- pnpm, Bun, Deno, Lua, and tree-sitter

### Command-line tools

- 1Password CLI, Claude Code, Pi, Wrangler, Greptile, and the WorkOS CLI
- bat, delta, eza, fd, fzf, GitHub CLI, glow, gum, jq, lazygit, ripgrep, shellcheck, Starship, StyLua, tmux, zoxide, and superfile
- Neovim
- `diffdad`, `fleet`, `tm`, and `sessions` from my GitHub repositories

### Homebrew packages and apps

- newer Bash, Git, zsh, grep, and Vim builds
- btop, cloc, entr, fswatch, GnuPG, highlight, tree, wdiff, wget, noti, and trash
- AeroSpace, Ghostty, WezTerm, Karabiner-Elements, SketchyBar, Borders, Monaspace, and Symbols Nerd Font

### Additional repositories

Bootstrap clones these over SSH:

- `~/Developer/pi-extensions`
- `~/Developer/ideation`
- `~/Developer/claude-plugins`

</details>

## Repository layout

| Path | What it contains | Destination |
| --- | --- | --- |
| `config/` | App configuration | `~/.config/*` |
| `home/` | Home-directory configuration | `~/.claude`, `~/.pi`, and `~/.zshenv` |
| `bin/` | Personal commands placed on `PATH` | Used directly from this checkout |
| `resources/` | terminfo source files and static resources | Consumed by bootstrap and app configs |
| `tools/` | Larger one-off tools and build helpers | Run from the repository |
| `install.sh` | Bare-machine bootstrap | Run directly or through `curl` |
| `Dockerfile` and `docker-compose.yml` | Limited Ubuntu sandbox | Local container only |

Mise links directories rather than copying individual files. The two declarations are intentionally broad:

```toml
[dotfiles]
"~/.config/*" = "~/Developer/dotfiles/config/*"
"~/.??*" = "~/Developer/dotfiles/home/.??*"
```

The fixed source path is why the repository must live at `~/Developer/dotfiles` unless you edit the manifest.

### Manage dotfile links

```bash
mise bootstrap dotfiles status
mise bootstrap dotfiles apply --yes
mise bootstrap dotfiles apply --yes ~/.config/nvim
mise bootstrap dotfiles unapply --yes
mise bootstrap dotfiles unapply --yes ~/.config/nvim
```

Unapply a target before deleting or renaming its source. Mise refuses to overwrite a real file with a symlink unless you pass `--force`.

To inspect old dangling links:

```bash
find ~/.config -type l ! -exec test -e {} \; -print
find ~ -maxdepth 1 -type l ! -exec test -e {} \; -print
```

Those commands only print candidates. Check each target before removing it.

## Shell and prompt

`home/.zshenv` establishes the XDG paths, finds the repository through the `~/.zshenv` symlink, and exports `EDITOR=nvim` and `GIT_EDITOR=nvim`. `config/zsh/.zshrc` handles the interactive shell.

The shell config:

- activates Mise for per-directory tool versions
- initializes completion, fzf, and zoxide
- adds the repository's `bin/`, `~/bin`, `~/.local/bin`, Bun, Cargo, pnpm, GNU grep, and `/usr/local/sbin` paths
- sets `CODE_DIR` to `~/code` when it exists, otherwise `~/Developer`
- installs the local zsh plugins with the `zfetch` function
- loads `~/.zshenv.local`, `~/.localrc`, and `~/.zshrc.local` when present

The configured plugins are zsh-async, zsh-syntax-highlighting, zsh-autosuggestions, zsh-npm-scripts-autocomplete, and fzf-tab. `mise run update` pulls their Git checkouts.

Starship renders a two-line prompt. The left side shows the full directory and a Node version when the directory contains `package.json` or `node_modules`. The right side shows Git state, the branch, and suspended jobs. The prompt symbol is cyan after success and red after failure.

## Terminal and macOS desktop

Ghostty is the terminal this tmux config targets. Its config uses Tokyo Night light and dark themes, Monaspace, a translucent blurred background, CSI-u modified keys, and `cmd+s` as a prefix for native splits and tabs.

The bootstrap installs WezTerm too, and a Kitty config remains in the tree.

AeroSpace starts at login and launches SketchyBar. The basic movement scheme is:

| Keys | Action |
| --- | --- |
| `alt+h/j/k/l` | Focus a window |
| `alt+shift+h/j/k/l` | Move a window |
| `alt+1..9` or `alt+letter` | Switch workspace |
| `alt+shift+1..9` or `alt+shift+letter` | Move a window to a workspace |
| `alt+shift+;` | Enter the AeroSpace service mode |

The AeroSpace rules route terminals, browsers, chat apps, mail, and other applications to named workspaces. SketchyBar shows those workspaces with app icons, the focused window title, the current layout, Fleet state, GitHub review requests, agent spend, Claude usage, and now-playing information. Borders runs as a Homebrew service.

## tmux

The prefix is `control-a`. I remap Caps Lock to Control, so this is less awkward than the default `control-b`.

| Key after the prefix | Action |
| --- | --- |
| `h`, `j`, `k`, `l` | Move between panes |
| `H`, `J`, `K`, `L` | Resize a pane by ten cells |
| `|` | Split to the right |
| `-` | Split below |
| `g` | Open lazygit in a popup |
| `s` | Open the `tm` session picker |
| `y` | Open Fleet in a popup |
| `n` | Jump to the next waiting agent pane |
| `f` | Toggle the Fleet sidebar |
| `T` | Toggle the status bar |

The status bar sits at the top. It shows the session on the left, then Fleet state and Git status on the right. The theme follows the macOS light or dark appearance and uses Nerd Font separators.

`tm` is installed as a compiled Mise tool. `bin/tm` is the fallback implementation and uses fzf to switch, create, refresh, and delete sessions.

Set `TMUX_MINIMAL=1` in a local shell file to hide the status bar while a session has one window:

```bash
export TMUX_MINIMAL=1
```

The tmux config also forwards truecolor, italics, undercurl, modified Enter keys, OSC 8 links, and terminal graphics through Ghostty. Those settings are there for Neovim and terminal agents, not decoration.

## Neovim

`config/nvim/init.lua` calls the local `nisi` module. That module bootstraps lazy.nvim, loads the plugin specs under `config/nvim/lua/nisi/plugins/`, and enables the Copilot, Python, and fzf extras.

The active setup uses a transparent background and chooses the Tokyo Night colorscheme after checking the macOS appearance. The first launch needs network access because it clones lazy.nvim and the plugin set.

Useful commands:

```bash
nvim          # Open the editor
vimu          # Run Lazy sync without opening the UI
```

Open `:Lazy` inside Neovim to inspect or update individual plugins.

## Git and worktrees

The tracked Git config lives at `config/git/config`. It sets `main` as the default branch, uses delta for paging, rebases pulls, enables rerere, auto-stashes rebases, and includes the untracked `~/.gitconfig-local` identity file.

The worktree tooling is available through Git's external-command convention:

```bash
git wt create my-feature
git wt create --pr 123
git wt status
git wt go
git wt prune
```

`git wt create` resolves local branches, remote branches, and GitHub pull requests before creating a new branch. New branches default to the prefix from `git config github.user`. `git wt status` shows dirty, merged, closed, and prunable worktrees.

## Pi, Claude Code, and Fleet

Both agent configurations are tracked, but their runtime data is not.

### Pi

`home/.pi/agent/settings.json` is the Pi configuration. It points at packages from `~/Developer/pi-extensions`, the Claude plugin repository, Ideation, Fleet, and several npm or Git packages. Most extension source code lives outside this repository. A fresh clone will only have the extension repositories declared in Mise; some local package paths still require their own checkouts.

Because `~/.pi` is a directory symlink into this repository, `.gitignore` excludes auth, sessions, memory databases, relay state, subagent runs, package installs, and other runtime files. A Git clean filter strips `lastChangelogVersion` from `settings.json` before Git compares or stages it.

### Claude Code

`home/.claude/settings.json` and `home/.claude/CLAUDE.md` are the only tracked Claude files. The settings configure the status line, SessionEnd cleanup, permissions, plugin marketplaces, and enabled plugins. Sessions, caches, downloaded plugins, and credentials remain untracked.

Three small scripts connect the agent tools to the terminal environment:

- `claude-statusline` renders the Claude status and pushes usage updates to SketchyBar
- `claude-tmux-cleanup` resets pane state when a Claude session ends
- `claude-notify` sends attention notifications through tmux

MCP servers are user-scoped in `~/.claude.json` and are not part of bootstrap. `bin/setup-mcp-servers` is a one-shot mutating script for the GPT-5, Playwright, and Context7 servers. It requires `OPENAI_API_KEY` and `CONTEXT7_API_KEY`, and it runs immediately when invoked.

### Fleet

[Fleet](https://github.com/nicknisi/fleet) is installed by Mise and lives in its own repository. tmux uses it for agent status, the next-waiting-agent jump, the popup, the sidebar, and window titles. SketchyBar consumes the same state through `sketchybar-fleet-watch`.

## Commands in `bin/`

`bin/` is on `PATH`. The table calls out the larger standalone commands; many of the remaining files support tmux, SketchyBar, Git aliases, or agent status.

| Command | What it does |
| --- | --- |
| `battery` | Print the current macOS battery percentage |
| `brew-why` | Show installed Homebrew formulae and their installed dependents |
| `digest` | Build a bounded text digest of a Git repository for model input |
| `npm-trust-setup` | Bootstrap npm packages and GitHub Actions trusted publishing |
| `wifi-password` | Read a Wi-Fi password from the macOS keychain |
| `thisisfine` | Print the "This is fine" scene in terminal color |

Read a script before running it. Some are one-off commands and do not implement `--help` or a dry run.

## Updating

Run the whole update sequence with:

```bash
mise run update
```

The task runs these updates in order:

1. lazy.nvim plugins
2. Homebrew metadata and packages
3. zsh plugin repositories
4. Mise itself and every tool from `[tools]`
5. uv tools and Pi extensions
6. this repository, but only when it is on `main`

For one component, call its native command instead. Examples include `mise upgrade <tool>`, `brew upgrade`, `uv tool upgrade --all`, and `pi update --extensions`.

## Linux sandbox

The Docker files are a rough Ubuntu shell for checking portable pieces. They do not run `install.sh`, clone the repository, or reproduce the macOS setup. Compose mounts the current checkout at `/home/user/code/dotfiles`.

```bash
docker compose build
docker compose run --rm dev_environment
```

The Dockerfile accepts SSH keys as build arguments and writes them into an image layer. Do not pass real keys to it. This sandbox predates the Mise bootstrap and should not be treated as an installation path.

## Local changes and forks

Machine-only shell changes belong in one of these ignored files:

- `~/.zshenv.local`
- `~/.localrc`
- `~/.zshrc.local`

Before using this repository as your own, search for `nicknisi`, `/Users/nicknisi`, and `~/Developer`. The Mise manifest, Claude marketplaces, agent package paths, Git aliases, and application rules all contain personal assumptions.

For hardware and software that do not belong in dotfiles, see [nicknisi.com/uses](https://nicknisi.com/uses).

## License and questions

The repository is MIT licensed. For questions, use [GitHub Discussions](https://github.com/nicknisi/dotfiles/discussions/new).

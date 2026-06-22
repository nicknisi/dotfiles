# Dotfiles
This project is forked from [nicknisi](https://github.com/nicknisi/dotfiles). I add my custom configuration.
## Initial setup
First, clone it from github to local machine.
```bash
git clone https://github.com/qq123538/dotfiles.git
```
Secondly, install all.
```bash
./install.sh all
```
Finally, run tmux, and install tmux plugins with `M-s I` (prefix + Shift+I).

# (original README)Dotfiles

Welcome to my world! Here you'll find a collection of configuration files for various tools and programs that I use on a daily basis. These dotfiles have been carefully curated and customized to streamline **my** workflow and improve **my** productivity. Your results may vary, but feel free to give it a try! Whether you're a fellow developer looking to optimize your setup or just curious about how I organize my digital life, I hope you find something useful in these dotfiles. So take a look around and feel free to borrow, modify, or fork to your heart's content. Happy coding!

> **Note**
> Did you arrive here through my YouTube talk, [vim + tmux](https://www.youtube.com/watch?v=5r6yzFEXajQ)? My dotfiles have changed tremendously since then, but feel free to peruse the state of this repo [at the time the video was recorded](https://github.com/nicknisi/dotfiles/tree/aa72bed5c4ecec540a31192581294818b69b93e2).

![capture-20221204193335](https://user-images.githubusercontent.com/293805/205530265-1d0b1a7f-ae2f-4c22-942c-2a1efa0f83a6.png)

## Initial setup

The first thing you need to do is to clone this repo into a location of your choosing. For example, if you have a `~/Developer` directory where you clone all of your git repos, that's a good choice for this one, too. This repo is setup to not rely on the location of the dotfiles, so you can place it anywhere.

> **Note**
> If you're on macOS, you'll also need to install the XCode CLI tools before continuing.

```bash
xcode-select --install
```

```bash
git clone https://github.com/qq123538/dotfiles.git
```

> **Note**
> This dotfiles configuration is set up in such a way that it _shouldn't_ matter where the repo exists on your system.

The script, `install.sh` is the one-stop for all things setup, backup, and installation.

```bash
> ./install.sh help

Usage: install.sh {backup|link|git|homebrew|ohmyzsh|shell|all}
```

### `backup`

```bash
./install.sh backup
```

Create a backup of the current dotfiles (if any) into `~/.dotfiles-backup/`. This will scan for the existence of every file that is to be symlinked and will move them over to the backup directory. It will also do the same for vim setups, moving some files in the [XDG base directory](http://standards.freedesktop.org/basedir-spec/basedir-spec-latest.html), (`~/.config`).

- `~/.config/nvim/` - The home of [neovim](https://neovim.io/) configuration
- `~/.vim/` - The home of vim configuration
- `~/.vimrc` - The main init file for vim

### `link`

```bash
./install.sh link
```

The `link` command will create [symbolic links](https://en.wikipedia.org/wiki/Symbolic_link) from the dotfiles directory into the `$HOME` directory, allowing for all of the configuration to _act_ as if it were there without being there, making it easier to maintain the dotfiles in isolation.

### `homebrew`

```bash
./install.sh homebrew
```

The `homebrew` command sets up [homebrew](https://brew.sh/) by downloading and running the homebrew installers script. Homebrew is a macOS package manager, but it also work on linux via Linuxbrew. If the script detects that you're installing the dotfiles on linux, it will use that instead. For consistency between operating systems, linuxbrew is set up but you may want to consider an alternate package manager for your particular system.

Once homebrew is installed, it executes the `brew bundle` command which will install the packages listed in the [Brewfile](./Brewfile).

### `shell`

```bash
./install.sh shell
```

The `shell` command sets up the recommended shell configuration for the dotfiles setup. Specifically, it sets the shell to [zsh](https://www.zsh.org/) using the `chsh` command.

### `all`

```bash
./install.sh all
```

This command runs `link`, `homebrew`, `git`, `ohmyzsh`, and `shell`. It does **not** run `backup` — you must run that one manually.

## ZSH Configuration

The ZSH setup uses [oh-my-zsh](https://ohmyz.sh/) with the [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme. Configuration is split across four files, each symlinked into `$HOME`:

- `zsh/zshenv.symlink` → `~/.zshenv` — sourced on every shell invocation. Sets `$DOTFILES` (repo root, via readlink resolution), `$CACHEDIR`, `$PATH`, `EDITOR`, and puts `zsh/functions/` on `fpath`.
- `zsh/zprofile.symlink` → `~/.zprofile` — sourced on login shells. Evaluates Homebrew shellenv (macOS arm/intel and Linuxbrew paths).
- `zsh/zshrc.symlink` → `~/.zshrc` — the main interactive config. Loads oh-my-zsh, p10k, then recursively sources every `$DOTFILES/**/*.zsh` file.
- `zsh/p10k.zsh.symlink` → `~/.p10k.zsh` — Powerlevel10k prompt configuration (lean style, generated by `p10k configure`).

### ZSH plugins

oh-my-zsh plugins are declared in `zshrc.symlink`:

- `git` — git aliases and completions
- `fzf` — fzf key bindings (`Ctrl-T` files, `Alt-C` directories, `Ctrl-R` history via Atuin)
- `zsh-autosuggestions` — fish-style inline suggestions (installed by `install.sh ohmyzsh`)

Additional plugins can be added to `~/.zshrc.local` or `~/.localrc` to keep them out of git.

### Machine-local overrides

These files are sourced if present but never committed:

- `~/.zshenv.local` — environment overrides (sourced by `zshenv.symlink`)
- `~/.zshrc.local` — interactive shell overrides (sourced by `zshrc.symlink`)
- `~/.localrc` — machine-specific config (sourced by `zshrc.symlink`)
- `~/.gitconfig-local` — git user name/email and per-OS credential helper (written by `install.sh git`)

### Autoloadable functions

`zsh/functions/` is on `fpath`, providing these autoloadable functions:

- `occm` — generate a conventional commit message via `opencode run --command commit` (pass `-m <provider/model>` to select a model; extra args become instructions)

## Neovim setup

> **Note**
> This is no longer a vim setup. The configuration has been moved to be Neovim-specific and (mostly) written in [Lua](https://www.lua.org/). `vim` is also set up as an alias to `nvim` to help with muscle memory.

The simplest way to install Neovim is to install it from homebrew.

```bash
brew install neovim
```

However, it was likely installed already if you ran the `./install.sh homebrew` command provided in the dotfiles.

All of the configuration for Neovim starts at `config/nvim/init.lua`, which is symlinked into the `~/.config/nvim` directory.

> **Warning**
> The first time you run `nvim` with this configuration, it will likely have a lot of errors. This is because it is dependent on a number of plugins being installed.

### Installing plugins

On the first run, all required plugins should automaticaly by installed by
[lazy.nvim](https://github.com/folke/lazy.nvim), a plugin manager for neovim.

All plugins are listed in [plugins.lua](./config/nvim/lua/plugins.lua). When a plugin is added, it will automatically be installed by lazy.nvim. To interface with lazy.nvim, simply run `:Lazy` from within vim.

> **Note**
> Plugins can be synced headlessly with `nvim --headless "+Lazy! sync" +qa`, or interactively via `:Lazy` inside Neovim.

## Terminal emulator

[Alacritty](https://alacritty.org/) is the primary terminal; [WezTerm](https://wezfurlong.org/wezterm/) is retained as a backup. Both run on the Windows side and launch WSL via `wsl.exe`.

### Alacritty (primary)

Config lives at `config/alacritty/alacritty.toml` (TOML). It mirrors the WezTerm setup: GitHub Dark colors (inlined), JetBrainsMono Nerd Font at 14pt, 120×28 initial window, 6px padding, `Ctrl+Click` URL hints.

`install.sh link` symlinks `config/alacritty` to `~/.config/alacritty/` (used by the WSLg Linux build). The Windows build reads `%APPDATA%\alacritty\alacritty.toml` instead, so soft-link that to the repo file to keep a single source of truth:

```powershell
winget install Alacritty.Alacritty
mkdir "$env:APPDATA\alacritty" -Force
New-Item -ItemType SymbolicLink `
  -Path "$env:APPDATA\alacritty\alacritty.toml" `
  -Target "\\wsl.localhost\Ubuntu-22.04\home\<user>\dotfiles\config\alacritty\alacritty.toml"
```

Notes:
- Default shell is `wsl.exe ~ -d Ubuntu-22.04` (no launch_menu — Alacritty has no GUI launcher).
- `TERM` is overridden to `xterm-256color` because WSL lacks the alacritty terminfo; TrueColor is handled by tmux's `xterm-256color:Tc` override. Switch back to `alacritty:Tc` once `infocmp alacritty` resolves in WSL.
- OSC52 clipboard works natively — `"+y` in nvim reaches the Windows clipboard through tmux `set-clipboard external`, with zero config.
- No tab support by design — use tmux.

### WezTerm (backup)

Config at `config/wezterm/wezterm.lua`. Kept as a fallback terminal; default program is PowerShell with a WSL entry in the launch menu.

## tmux configuration

I prefer to run everything inside of [tmux](https://github.com/tmux/tmux). I typically use a large pane on the top for neovim and then multiple panes along the bottom or right side for various commands I may need to run. There are no pre-configured layouts in this repository, as I tend to create them on-the-fly and as needed.

This repo ships with a `tm` command which provides a list of active session, or provides prompts to create a new one.

```bash
> tm
Available sessions
------------------

1) New Session
Please choose your session: 1
Enter new session name: open-source
```

This configuration provides a bit of style to the tmux bar, along with some additional data such as the currently playing song (from Apple Music or Spotify), the system name, the session name, and the current time.

> **Note**
> It also changes the prefix from `⌃-b` to `M-s` (Alt+s).

### tmux key commands

Pane navigation and resizing use `M-h/j/k/l` and `M-H/J/K/L` (Alt + key, **no prefix**), wired via [tmux.nvim](https://github.com/aserowy/tmux.nvim) for seamless neovim↔tmux pane switching.

Prefix (`M-s`) + key:

| Command     | Description                    |
| ----------- | ------------------------------ |
| `h`         | Split pane to the left         |
| `j`         | Split pane to the bottom       |
| `k`         | Split pane to the top          |
| `l`         | Split pane to the right        |
| `c`         | Create a new window            |
| `r`         | Reload tmux config             |
| `b`         | Break pane into a new window   |
| `>` / `<`   | Swap pane down / up            |
| `←` / `→`   | Swap window left / right       |
| `'`         | Last window                    |
| `1`-`9`     | Select pane by index           |

Without prefix:

| Command     | Description                    |
| ----------- | ------------------------------ |
| `M-1`-`M-9` | Select window 1-9             |
| `M-w`       | Kill window                    |
| `M-q`       | Kill pane                      |
| `M-h/j/k/l` | Navigate pane left/down/up/right |
| `M-H/J/K/L` | Resize pane                    |

## Atuin (shell history)

[Atuin](https://github.com/atuinsh/atuin) replaces shell history with a searchable, syncable SQLite database. This setup runs **local-only** (no cloud account); search uses fzf-style fuzzy matching to match the existing fzf workflow.

### Installation

Atuin is listed in the [Brewfile](./Brewfile) and installed by `./install.sh homebrew`. The config is symlinked to `~/.config/atuin/config.toml` by `./install.sh link`, and the zsh integration (`zsh/atuin.zsh`) is auto-sourced by `zshrc.symlink`.

### Keybindings

| Key | Action |
| --- | --- |
| `Ctrl-R` | Open Atuin fuzzy search UI (replaces fzf history search) |
| `Up` | Cycle history filtered to the current directory |
| `Ctrl-R` (inside UI) | Cycle filter modes: global → host → session → directory → workspace |
| `Tab` | Copy selected command to the command line for editing |
| `Enter` | Execute the selected command immediately (`enter_accept = true`) |
| `Esc` | Restore the original command line |
| `Ctrl-A` then `D` | Delete the selected history entry (prefix mode) |
| `Ctrl-T` / `Alt-C` | Still fzf file / directory search (unaffected by Atuin) |

Prefix a command with a space to keep it out of history (ignorespace).

### Common CLI

```bash
atuin search <query>      # search history from the command line
atuin history list        # list recorded history
atuin stats               # show shell usage statistics
atuin doctor              # diagnose shell integration
atuin import auto         # import existing shell history (run once)
atuin history prune       # remove entries matching history_filter / cwd_filter
```

### Enabling cloud sync later (optional)

This setup is local-only. To enable cross-machine encrypted sync later:

1. Add to `~/.config/atuin/config.toml`:
   ```toml
   auto_sync = true
   [sync]
   records = true
   ```
2. `atuin register -u <username> -e <email>`
3. Save the encryption key printed by `atuin key` to a safe location.
4. `atuin sync`

See the [Atuin docs](https://docs.atuin.sh/) for full reference.

## Yazi (file manager)

[Yazi](https://github.com/sxyazi/yazi) is a fast terminal file manager with async I/O and image preview. It complements `fzf` — use **fzf for known targets** (`Ctrl-T` / `Alt-C`) and **yazi for browsing** and image previews.

### Installation

Yazi and `chafa` (image-preview fallback for WSL2/tmux) are listed in the [Brewfile](./Brewfile) and installed by `./install.sh homebrew`. The config is symlinked to `~/.config/yazi/` by `./install.sh link`, and the shell integration (`zsh/yazi.zsh`) is auto-sourced by `zshrc.symlink`.

### Shell commands

| Command | Action |
| --- | --- |
| `y` | Launch yazi in the current directory |
| `yc` | Launch yazi and **cd to the directory it was in on quit** (replaces the former nnn `cdn`) |

### Keybindings (yazi defaults + one override)

| Key | Action |
| --- | --- |
| `h` / `l` | Go to parent / enter child directory |
| `j` / `k` | Move down / up |
| `Enter` / `o` | Open selected file (text → `$EDITOR` = nvim, images → `xdg-open`) |
| `z` | Jump to a file/directory via fzf |
| `Z` | Jump to a directory via zoxide |
| `s` / `S` | Search by name (fd) / by content (ripgrep) |
| `Space` | Toggle selection |
| `cc` / `cd` / `cf` | Copy path / dirname / filename |
| `,g` | **Spawn lazygit in CWD** (custom override in `keymap.toml`) |
| `q` | Quit (writes CWD for `yc`) |

### Configuration

Only values that diverge from yazi's shipped defaults are committed:

- `config/yazi/yazi.toml` — `show_hidden = true`, `linemode = "size"`, `sort_by = "mtime"` (newest first).
- `config/yazi/keymap.toml` — `prepend_keymap` adds `,g` → `lazygit`; all defaults preserved.

No `theme.toml` is shipped (yazi's built-in dark theme matches the terminal).

### Practical usage

1. **`yc`** — open yazi, browse with `hjkl`, `q` to exit back into the cwd you left. The single most useful thing: yazi as a "where did I put that file" tool that leaves you positioned correctly when you quit.
2. **Image previews** — yazi's killer feature. On WSL2 + Alacritty (or wezterm) + tmux, the `chafa` fallback renders images as ANSI block art. Scan a folder of screenshots without leaving the terminal.
3. **Code previews** — press `K` / `J` to scroll the preview pane; yazi renders files with syntax highlighting and the directory tree on the right.
4. **Open in nvim from yazi** — `Enter` / `o` opens the highlighted file in nvim (text files only; images open via `xdg-open`).
5. **`,g` from inside yazi** — spawns lazygit in the current pane's dir, without leaving yazi.
6. **Use alongside fzf** — `Ctrl-T` (fzf file) and `Alt-C` (fzf dir) stay as the "I know the name" path; yazi is the "I need to look around" path.

**Rule of thumb:** fzf for *known targets*, yazi for *browsing* and *images*.

## OpenCode (AI coding agent)

[OpenCode](https://opencode.ai) is an open-source AI coding agent CLI/TUI. This repo manages its global config so providers, MCP servers, and the `/commit` command are version-controlled and portable.

### Installation

OpenCode is installed via `./install.sh homebrew` (see [Brewfile](./Brewfile)). The config is symlinked to `~/.config/opencode/` by `./install.sh link` — the same `config/<tool>` convention as atuin/yazi/alacritty.

### Managed files

| File | Purpose |
| --- | --- |
| `config/opencode/opencode.json` | Providers (`google` antigravity models), MCP servers (`context7`), formatters (`clang-format`), plugins (`@franlol/opencode-md-table-formatter`) |
| `config/opencode/commands/commit.md` | The `/commit` custom command — a Conventional Commits message generator that reads the staged diff, recent history, and `AGENTS.md` |

**No secrets live in the repo.** Provider credentials are stored in `~/.local/share/opencode/auth.json` (never committed) and loaded by opencode at startup. The `OPENCODE_GO_API_KEY` env var (consumed by avante.nvim) is auto-exported from `auth.json` by `zshrc.symlink` via `jq`.

### Runtime files (gitignored)

OpenCode regenerates several files inside the symlinked `~/.config/opencode/` dir at runtime; these are gitignored at repo root and must not be committed:

- `node_modules/`, `package.json`, `package-lock.json`, `bun.lock` — plugin install state (regenerated from `opencode.json`'s `plugin` array)
- `antigravity-accounts.json*`, `antigravity-signature-cache.json`, `antigravity-logs/` — antigravity provider session state

### Shell commands

| Command | Action |
| --- | --- |
| `occm` | Generate a conventional commit message via `opencode run --command commit` (pass `-m <provider/model>` to select a model; extra args become instructions) |
| `opencode` | Launch the TUI |
| `opencode pr <N>` | Fetch & checkout GitHub PR `#N`, then launch opencode |
| `opencode models` | List available models from configured providers |

### Adding a custom command

Drop a markdown file in `config/opencode/commands/<name>.md` with frontmatter (`description`, optional `agent`/`model`) and a prompt template. It becomes `/name` in the TUI and `opencode run --command name` on the CLI. See [the commands docs](https://opencode.ai/docs/commands) and the existing `commit.md` for a reference template.

## Docker Setup

A Dockerfile exists in the repository as a testing ground for linux support. To set up the image, make sure you have Docker installed and then run the following command.

```bash
docker build -t dotfiles --force-rm --build-arg PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" --build-arg PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)" .
```

This should create a `dotfiles` image which will set up the base environment with the dotfiles repo cloned. To run, execute the following command.

```bash
docker run -it --rm dotfiles
```

This will open a bash shell in the container which can then be used to manually test the dotfiles installation process with linux.

## Preferred software

- [Alacritty](https://alacritty.org/) - GPU-accelerated terminal emulator (primary); cross-platform, TOML config, native OSC52 clipboard for WSL2
- [WezTerm](https://wezfurlong.org/wezterm/) - GPU-accelerated terminal emulator (backup); good tmux and WSL2 support
- [tmux](https://github.com/tmux/tmux) - Terminal multiplexer
- [Neovim](https://neovim.io/) - Hyper-extensible Vim-based text editor
- [Yazi](https://github.com/sxyazi/yazi) - Terminal file manager with image preview
- [OpenCode](https://opencode.ai) - Open-source AI coding agent CLI/TUI

## Questions

If you have questions, notice issues, or would like to see improvements, please open a new [discussion](https://github.com/qq123538/dotfiles/discussions/new) and I'm happy to help you out!

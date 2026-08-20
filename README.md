# Dotfiles

Welcome to my world! Here you'll find a collection of configuration files for various tools and programs that I use on a daily basis. These dotfiles have been carefully curated and customized to streamline **my** workflow and improve **my** productivity. Your results may vary, but feel free to give them a try! Whether you're a fellow developer looking to optimize your setup or just curious about how I organize my digital life, I hope you find something useful in these dotfiles. So take a look around and feel free to borrow, modify, or fork to your heart's content. Happy coding!

> [!Note]
>
> Did you arrive here through my YouTube talk, [vim + tmux](https://www.youtube.com/watch?v=5r6yzFEXajQ)? My dotfiles have changed tremendously since then, but feel free to peruse the state of this repo [at the time the video was recorded](https://github.com/nicknisi/dotfiles/tree/aa72bed5c4ecec540a31192581294818b69b93e2).

<img width="5142" height="3026" alt="capture-20250802232629" src="https://github.com/user-attachments/assets/00db0017-6792-4355-838c-50368b55fd9d" />

## Initial Setup

One command on a bare machine:

```bash
curl -fsSL https://raw.githubusercontent.com/nicknisi/dotfiles/main/install.sh | bash
```

It installs the Xcode CLI tools if git is missing, clones the repo, installs mise,
links every dotfile, installs Homebrew and the macOS apps, installs the tools from
`[tools]`, sets the login shell, and writes the macOS defaults. Every step is
idempotent, so re-running it is safe.

To see what it would do without writing anything:

```bash
curl -fsSL https://raw.githubusercontent.com/nicknisi/dotfiles/main/install.sh | bash -s -- --dry-run
```

Set `NO_COLOR=1` for plain output; it also drops the colors on its own when stdout
isn't a terminal.

Prefer to do it by hand:

```bash
xcode-select --install                                   # macOS, if git is missing
git clone git@github.com:nicknisi/dotfiles.git ~/Developer/dotfiles
curl https://mise.run | sh
MISE_GLOBAL_CONFIG_FILE=~/Developer/dotfiles/config/mise/config.toml \
  mise bootstrap dotfiles apply     # creates ~/.config/mise -> the repo
mise bootstrap && mise install
```

> [!important]
>
> Clone to `~/Developer/dotfiles`. The `[dotfiles]` entries in
> `config/mise/config.toml` use absolute sources, because relative ones resolve
> against `~/.config/mise`, which is itself a symlink into this repo. Cloning
> elsewhere means editing those two lines.

## The `dot` Command

This repository includes a `dot` command for the machine setup that isn't
symlinks or packages. `dot link` and `dot unlink` are wrappers over
`mise bootstrap dotfiles apply|unapply`, so the layout is described once, in
`[dotfiles]` in `config/mise/config.toml`.

### Configuration

The tool respects these environment variables:
- `DOTFILES`: Path to your dotfiles directory
- `PATH`: For discovering external commands

Only `config/*` and `home/.??*` are linked, per the `[dotfiles]` globs in
`config/mise/config.toml`. Everything else in the repo (`bin`, `resources`,
`tools`) is left alone.

### Basic Usage

```bash
dot help                    # Show help message and available commands
dot link [package]          # Link all or a specific package (via mise)
dot unlink [package]        # Unlink all or a specific package (via mise)
dot link clean              # Remove broken symlinks
dot filters                 # Register the repo's git clean filters
```

> [!important]
>
> This command won't be in the path until ZSH is properly configured.
> Until that's the case, you can run the command from the dotfiles root.
> ```bash
> bin/dot <command> <subcommand>
>```

### Link/Unlink Options

```bash
dot link <package>         # Link a specific package
dot link all               # Link all packages
dot link clean -n          # Preview which broken symlinks would go
```

There's no backup command. mise refuses to replace a real file with a symlink,
naming the paths that collide, so `mise bootstrap dotfiles apply --force` is the
explicit opt-in rather than a tarball you have to remember to make.

### Built-in Commands

#### Git Configuration (`dot git`)

```bash
dot git setup    # Configure git user settings interactively
```

Sets up personalized Git configuration, including name, email, and GitHub username. The configuration is saved to `~/.gitconfig-local`.

#### macOS Settings and Login Shell (mise)

Both live in `config/mise/config.toml` and are applied by `mise bootstrap`:

```bash
mise bootstrap macos defaults status   # show drift
mise bootstrap macos defaults apply    # Finder, keyboard, trackpad, font smoothing
mise bootstrap user apply              # add zsh to /etc/shells, then chsh
```

`[bootstrap.macos.finder]`, `[bootstrap.macos.keyboard]`, and
`[bootstrap.macos.trackpad]` cover the common preferences by name;
`[bootstrap.macos.defaults]` holds the raw `(domain, key)` pairs for the rest. The
`post-defaults` hook handles the two that aren't `defaults` writes at all — the
Terminal.app encoding array and `chflags nohidden ~/Library` — plus the `killall`
that makes Finder and the Dock notice.

#### Shell Configuration (`dot shell`)

```bash
dot shell terminfo   # Install terminal information files
```

Only needed if you want italic support in Neovim and correct behavior over SSH.

#### Homebrew Management (mise tasks)

```bash
mise run install-homebrew   # Install the Homebrew package manager
mise run setup-mac          # Tap and install the macOS-only packages
```

Most packages come from `[bootstrap.packages]` in `config/mise/config.toml`, applied with
`mise bootstrap packages apply`. `setup-mac` covers the few whose taps publish no Homebrew
API metadata, so mise cannot install them: borders, sketchybar, and aerospace.

#### Updating (mise tasks)

```bash
mise run update
```

One task, in order: neovim plugins, Homebrew, zsh plugins, mise and everything in
`[tools]`, uv tools, pi extensions, then a fast-forward of this repo. To update
one thing, run the underlying command — `mise upgrade <tool>`, `brew upgrade`,
`uv tool upgrade --all`.

#### Legacy Cleanup (`dot legacy`)

```bash
dot legacy clean    # Clean up broken legacy symlinks
```

This legacy command specifically cleans up the old symlinks that might exist from previous iterations of this repository.

### Extending with Custom Commands

The `dot` command is extensible. You can add custom commands by:

1. Creating executable scripts named `dot-<command>` in your `$PATH`
2. Adding a "Description:" comment for help text
3. The command will then be available as `dot <command>`

## ZSH Configuration

The prompt for ZSH is configured in `config/zsh/zshrc` and performs the following operations:

- Sets `EDITOR` to `nvim`
- Loads any `~/.terminfo` setup
- Sets `CODE_DIR` to `~/Developer`. This can be changed to the location you use for your git checkouts, and enables fast `cd`-ing into it via the `c` command
- Recursively searches the `$DOTFILES/zsh` directory for any `.zsh` files and sources them
- Sources a `~/.localrc`, if available, for configuration that is machine-specific and/or should not ever be checked into git
- Adds `~/bin` and `$DOTFILES/bin` to the `PATH`

### ZSH Plugins

There are a number of plugins in use for ZSH, and they are installed and maintained separately via the `zfetch` command. `zfetch` is a custom plugin manager available [here](./zsh/functions/zfetch). The plugins that are used are listed in the `.zshrc` and include:

- [zsh-async](https://github.com/mafredri/zsh-async)
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
- [zsh-npm-scripts-autocomplete](https://github.com/grigorii-zander/zsh-npm-scripts-autocomplete)
- [fzf-tab](https://github.com/Aloxaf/fzf-tab)

Additional plugins can be added to the `~/.zshrc`, or to `~/.localrc` if you want them to stay out of git.

```bash
# Add a line like this and the plugin will automatically be downloaded and sourced
zfetch nicknisi/work-scripts
```

### Prompt

The ZSH prompt is designed to be minimal and fast, focusing on essential information without git repository details. The prompt displays the current working directory, Node.js version (when in a Node.js project), and suspended job indicators on the first line. The second line shows a simple colored space character that indicates the success of the last command (cyan for success, red for failure).

#### Jobs Prompt

The prompt will also display a `✱` character indicating that there is a suspended job in the background. This is helpful for keeping track of putting Vim in the background by pressing CTRL-Z.

#### Node Prompt

If a `package.json` file or a `node_modules` directory exists in the current working directory, display the node symbol along with the current version of Node. This is useful information when switching between projects that depend on different versions of Node.

## Neovim Setup

> [!Note]
>
> This is no longer a Vim setup. The configuration has been moved to be Neovim-specific and (mostly) written in [Lua](https://www.lua.org/). `vim` is also set up as an alias to `nvim` to help with muscle memory.

The simplest way to install Neovim is to install it from Homebrew.

```bash
brew install neovim
```

However, it comes from mise's `[tools]`, so `mise install` will have set it up already.

All of the configuration for Neovim starts at `config/nvim/init.lua`, which is symlinked into the `~/.config/nvim` directory.

> [!Warning]
>
> The first time you run `nvim` with this configuration, it will likely have a lot of errors. This is because it is dependent on a number of plugins being installed.

### Installing Plugins

On the first run, all required plugins should be automatically installed by [lazy.nvim](https://github.com/folke/lazy.nvim), a plugin manager for Neovim.

Plugins are organized in multiple files under `config/nvim/lua/nisi/plugins/` for better maintainability. When a plugin is added, it will automatically be installed by lazy.nvim. To interface with lazy.nvim, simply run `:Lazy` from within Vim.

> [!Note]
>
> Plugins can be synced in a headless way from the command line using the `vimu` alias.

## tmux Configuration

I prefer to run everything inside [tmux](https://github.com/tmux/tmux). I typically use a large pane on the top for Neovim and then multiple panes along the bottom or right side for various commands I may need to run. There are no pre-configured layouts in this repository, as I tend to create them on the fly and as needed.

This repo ships with a `tm` command which provides a list of active sessions, or prompts to create a new one.

```bash
> tm
Available sessions
------------------

1) New Session
Please choose your session: 1
Enter new session name: open-source
```

This configuration features a custom theme system that automatically adapts to macOS dark/light mode settings. The status bar includes rich git repository information, currently playing music (from Apple Music or Spotify), session name, and system time. The theme uses powerline-style separators and modern styling with support for Nerd Font icons.

> [!Note]
>
> It also changes the prefix from `⌃-b` to `⌃-a` (⌃ is the _control_ key). This is because I tend to remap the Caps Lock button to Control, and then the prefix makes more sense.

### tmux Key Commands

Pressing the Prefix followed by the following will have the corresponding actions in tmux:

| Command     | Description                    |
| ----------- | ------------------------------ |
| `h`         | Select the pane to the left    |
| `j`         | Select the pane to the bottom  |
| `k`         | Select the pane to the top     |
| `l`         | Select the pane to the right   |
| `⇧-H`       | Enlarge the pane to the left   |
| `⇧-J`       | Enlarge the pane to the bottom |
| `⇧-K`       | Enlarge the pane to the top    |
| `⇧-L`       | Enlarge the pane to the right  |
| `-` (dash)  | Create a vertical split        |
| `\|` (pipe) | Create a horizontal split      |

### Git Status Integration

The tmux status bar includes comprehensive git repository information with the following indicators. The status bar also displays currently playing music from Apple Music or Spotify, and Claude working status when applicable:

| Symbol | Description                     |
| ------ | ------------------------------- |
| 󰐖      | Untracked files exist           |
| 󰜎      | Files added/staged for commit   |
| 󰏫      | Modified files                  |
| 󰑕      | Files renamed                   |
| 󰮉      | Files deleted                   |
| 󰘓      | Stashed changes exist           |
| 󰧁      | Unmerged conflicts              |
| 󰁞      | Branch ahead of remote          |
| 󰁅      | Branch behind remote            |
| 󰧈      | Branch diverged from remote     |
| 󰸞      | Working directory clean         |

> [!Note]
>
> Git status indicators require a Nerd Font to display properly. The status updates automatically as you work with git repositories.

### Minimal tmux UI

Setting a `$TMUX_MINIMAL` environment variable will do some extra work to hide the tmux status bar when there is only a single tmux window open. This is not the default in this repo because it can be confusing, but it is my preferred way to work. To set this, you can use the `~/.localrc` file to set it in the following way:

```shell
export TMUX_MINIMAL=1
```

## Agent Orchestration (fleet)

Multi-agent tmux orchestration (status badges, jump-to-waiting-agent, the dashboard TUI, prompt injection) is handled by [fleet](https://github.com/nicknisi/fleet), which lives in its own repo and is **not** part of these dotfiles:

```bash
brew install nicknisi/formulae/fleet
```

The tmux config here calls `fleet status`, `fleet next`, and `fleet reconcile`, and fleet also registers itself as a Claude Code plugin via a local marketplace (`~/.local/share/fleet-marketplace`). The only agent-related scripts still shipped in `bin/` are:

- `claude-statusline` — Claude Code in-pane status line (wired via `statusLine` in `home/.claude/settings.json`)
- `claude-tmux-cleanup` — resets pane borders after agent sessions (SessionEnd hook)
- `claude-notify` — tmux notification helper, still used by the Pi statusline extension

An earlier generation of orchestration scripts (`claude-dashboard`, `claude-next`, `agent-status`, etc.) was superseded by fleet and removed; see git history if you need them.

> [!Note]
> MCP server config (raindrop, omnifocus, devin, etc.) lives in `~/.claude.json` user scope and is not tracked here — reconfigure those by hand on a new machine.

## Docker Setup

A Dockerfile exists in the repository as a testing ground for Linux support. To set up the image, make sure you have Docker installed and then run the following command:

```bash
docker build -t dotfiles --force-rm --build-arg PRIVATE_KEY="$(cat ~/.ssh/id_rsa)" --build-arg PUBLIC_KEY="$(cat ~/.ssh/id_rsa.pub)" .
```

This should create a `dotfiles` image which will set up the base environment with the dotfiles repo cloned. To run, execute the following command:

```bash
docker run -it --rm dotfiles
```

This will open a bash shell in the container which can then be used to manually test the dotfiles installation process with Linux.

## Preferred Software

I almost exclusively work on macOS, so this list will be specific to that operating system, but several of these recommendations are also available cross-platform. For a full and up-to-date list of the software and gear that I use today, check out my [/uses](https://nicknisi.com/uses) page.

- [WezTerm](https://wezfurlong.org/wezterm/index.html) - A GPU-based terminal emulator
- [Aerospace](https://github.com/nikitabobko/AeroSpace) - An i3-like tiling window manager for macOS
- [Raycast](https://raycast.com) - A powerful launcher and productivity tool

## Questions

If you have questions, notice issues, or would like to see improvements, please open a new [discussion](https://github.com/nicknisi/dotfiles/discussions/new) and I'm happy to help you out!

# vim:ft=ruby
#
# Linux-only Brewfile. macOS-specific entries (cask taps, noti, trash,
# imageoptim, wezterm/1password casks, font casks, koekeishiya tap)
# have been removed — target environment is WSL2 Ubuntu per AGENTS.md.
# To re-add mac entries, fork the upstream nicknisi/dotfiles or restore
# them from git history.

# Linux clipboard helper (was inside the removed elsif OS.linux? block)
brew "xclip" # access to clipboard (similar to pbcopy/pbpaste)

# tap "homebrew/bundle" removed — brew bundle is a built-in command since
# Homebrew 4.0; the tap was deprecated and is now empty.
# tap "homebrew/core" removed — homebrew/core is auto-tapped since ~2021

# packages
brew "fd" # find alternative
brew "fzf" # Fuzzy file searcher, used in scripts and in vim
brew "git" # Git version control (latest version)
brew "grep" # grep (latest)
brew "lazygit" # a better git UI
brew "fastfetch" # pretty system info (neofetch successor; neofetch archived 2024-04)
brew "neovim" # A better vim
brew "python" # python (latest)
brew "ripgrep" # very fast file searcher
brew "tmux" # terminal multiplexer
brew "tpm" # the plugins manager of tmux
brew "tree" # pretty-print directory contents
brew "wget" # internet file retriever
brew "zsh" # zsh (latest)
brew "tldr" # simplified man pages
brew "unzip"
brew "cmake"
brew "tree-sitter"
brew "node"
brew "repo"
brew "htop"
brew "gemini-cli"
# copilot-cli removed — the formula no longer exists in homebrew-core (the
# "copilot" formula there is Amazon ECS Copilot, not GitHub's). GitHub's
# Copilot CLI is now a cask: install manually with
# `brew install --cask copilot-cli` if needed. Existing Caskroom installs
# are preserved (brew bundle does not uninstall entries missing from the Brewfile).
brew "git-delta"
brew "atuin" # magical shell history (replaces fzf Ctrl-R history search)
brew "yazi" # terminal file manager (image preview, async I/O); launch with `y` / `yc`
brew "chafa" # terminal image renderer; yazi image-preview fallback on WSL2/tmux

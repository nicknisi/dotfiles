## These are a work in progress

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# show hidden files by default
defaults write com.apple.Finder AppleShowAllFiles -bool false

# only use UTF-8 ub Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# expand save dialog by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

# show the ~/Library folder in Finder
chflags nohidden ~/Library

# wicked fast key repeat rate
defaults write NSGlobalDomain KeyRepeat -int 0

# disable resume system wide
# defaults write NSGlobalDomainNSQuitAlwaysKeepWindows -bool false

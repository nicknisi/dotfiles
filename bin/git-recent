#!/usr/bin/env bash

# git-recent - checkout recent branches with a fuzzy finder (FZF) list
# credit to https://gist.github.com/srsholmes/5607e26c187922878943c50edfb245ef

branches=$(git branch --sort=-committerdate --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(contents:subject) %(color:green)(%(committerdate:relative)) [%(authorname)]')
branch=$(echo "$branches" | fzf --ansi)
branch=$(echo "$branch" | awk '{print $1}' | tr -d '*')
git checkout "$branch"

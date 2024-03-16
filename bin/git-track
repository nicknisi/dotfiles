#!/usr/bin/env bash

# push up the branch and set upstream for the current branch

branch=$(git rev-parse --abbrev-ref HEAD)
remote="${1:-origin}"
git push -u "$remote" "$branch"

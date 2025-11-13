#!/usr/bin/env bash
# Smart tmux window naming with worktree detection

COMMAND="$1"
CURRENT_PATH="$2"

# Claude sets its process title to version number, map it back
if [[ "$COMMAND" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  COMMAND="claude"
fi

# Get icon from nerdwin
ICON=$(nerdwin "$COMMAND")

# Get smart directory name
get_smart_name() {
  local path="$1"
  local dir_name=$(basename "$path")

  # Check if we're in a git worktree (where .git is a file, not a directory)
  if [ -f "$path/.git" ]; then
    local parent_dir=$(dirname "$path")

    # Check if parent has .bare directory (worktree pattern)
    if [ -d "$parent_dir/.bare" ]; then
      # Get branch name
      local branch=$(cd "$path" && git rev-parse --abbrev-ref HEAD 2>/dev/null)
      local project=$(basename "$parent_dir")

      if [ -n "$branch" ]; then
        echo "$project ($branch)"
        return
      fi
    fi
  fi

  # Default: just show directory name
  echo "$dir_name"
}

NAME=$(get_smart_name "$CURRENT_PATH")

# Output icon and name
echo "$ICON $NAME"

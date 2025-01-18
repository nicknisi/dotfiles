#!/usr/bin/env bash

# Filename: ~/github/dotfiles-latest/sketchybar/felixkratz/plugins/github.sh

update() {
  source "$CONFIG_DIR/colors.sh"
  source "$CONFIG_DIR/icons.sh"

  NOTIFICATIONS="$(gh api notifications)"
  COUNT="$(echo "$NOTIFICATIONS" | jq 'length')"
  args=()
  if [ "$NOTIFICATIONS" = "[]" ]; then
    args+=(--set $NAME icon=$BELL label="0")
  else
    args+=(--set $NAME icon=$BELL_DOT label="$COUNT")
  fi

  PREV_COUNT=$(sketchybar --query github.bell | jq -r .label.value)
  # For sound to play around with:
  # afplay /System/Library/Sounds/Morse.aiff

  args+=(--remove '/github.notification\.*/')

  COUNTER=0
  COLOR=$WHITE
  args+=(--set github.bell icon.color=$COLOR)

  while read -r repo url type title; do
    COUNTER=$((COUNTER + 1))
    IMPORTANT="$(echo "$title" | egrep -i "(deprecat|break|broke)")"
    COLOR=$BLUE
    PADDING=0

    if [ "${repo}" = "" ] && [ "${title}" = "" ]; then
      repo="Note"
      title="No new notifications"
    fi
    case "${type}" in
    "'Issue'")
      COLOR=$GREEN
      ICON=$GIT_ISSUE
      URL="$(gh api "$(echo "${url}" | sed -e "s/^'//" -e "s/'$//")" | jq .html_url)"
      ;;
    "'Discussion'")
      COLOR=$WHITE
      ICON=$GIT_DISCUSSION
      URL="https://www.github.com/notifications"
      ;;
    "'PullRequest'")
      COLOR=$BLUE
      ICON=$GIT_PULL_REQUEST
      URL="$(gh api "$(echo "${url}" | sed -e "s/^'//" -e "s/'$//")" | jq .html_url)"
      ;;
    "'Commit'")
      COLOR=$WHITE
      ICON=$GIT_COMMIT
      URL="$(gh api "$(echo "${url}" | sed -e "s/^'//" -e "s/'$//")" | jq .html_url)"
      ;;
    esac

    if [ "$IMPORTANT" != "" ]; then
      COLOR=$RED
      ICON=􀁞
      args+=(--set github.bell icon.color=$COLOR)
    fi

    notification=(
      label="$(echo "$title" | sed -e "s/^'//" -e "s/'$//")"
      icon="$ICON $(echo "$repo" | sed -e "s/^'//" -e "s/'$//"):"
      icon.padding_left="$PADDING"
      label.padding_right="$PADDING"
      icon.color=$COLOR
      position=popup.github.bell
      icon.background.color=$COLOR
      drawing=on
      click_script="open \"$URL\"; sketchybar --set github.bell popup.drawing=off; sleep 5; sketchybar --trigger github.update"
    )

    args+=(--clone github.notification.$COUNTER github.template
      --set github.notification.$COUNTER "${notification[@]}")
  done <<<"$(echo "$NOTIFICATIONS" | jq -r '.[] | [.repository.name, .subject.latest_comment_url, .subject.type, .subject.title] | @sh')"

  sketchybar -m "${args[@]}" >/dev/null

  if [ "$COUNT" -gt "$PREV_COUNT" ] 2>/dev/null || [ "$SENDER" = "forced" ]; then
    sketchybar --animate tanh 15 --set github.bell label.y_offset=5 label.y_offset=0
  fi
}

popup() {
  sketchybar --set "$NAME" popup.drawing="$1"
}

case "$SENDER" in
"routine" | "forced" | "github.update")
  update
  ;;
"system_woke")
  sleep 10 && update # Wait for network to connect
  ;;
"mouse.entered")
  popup on
  ;;
"mouse.exited" | "mouse.exited.global")
  popup off
  ;;
"mouse.clicked")
  popup toggle
  ;;
esac

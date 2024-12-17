#!/bin/bash

svim=(
  script="$PLUGIN_DIR/svim.sh"
  icon=$INSERT_MODE
  icon.font.size=20
  updates=on
  drawing=off
)

sketchybar --add event svim_update \
           --add item svim right   \
           --set svim "${svim[@]}" \
           --subscribe svim svim_update

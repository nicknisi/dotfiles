#!/usr/bin/env bash

location="$1"
config_home="$1/config"
data_home="$1/data"
cache_home="$1/cache"

# make sure each of the directories exist
for dir in "$config_home" "$data_home" "$cache_home"; do
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir"
  fi
done

# copy the nvim config into the config home
cp -R config/nvim "$config_home"

XDG_CONFIG_HOME="$config_home" \
  XDG_DATA_HOME="$data_home" \
  XDG_CACHE_HOME="$cache_home" \
  nvim

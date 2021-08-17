#!/usr/bin/env bash

# List out the pid for the process that is currently listening on the provided port

line="$(lsof -i -P -n | grep LISTEN | grep ":$1")"
pid=$(echo "$line" | awk '{print $2}')
pid_name=$(echo "$line" | awk '{print $1}')

# If there's nothing running, exit
[[ -z "$pid" ]] && exit 0

# output the process name to stderr so it won't be piped along
echo >&2 -e "$pid_name"

# print the process id. It can be piped, for example to pbcopy
echo -e "$pid"

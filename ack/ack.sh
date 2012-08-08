#!/bin/sh
# add support for project/directory level .ackrc files

ackrc=""
if [ -f ./.ackrc ]; then
    ackrc=$(tr '\n' ' ' < ./.ackrc)
fi

ack $ackrc $*

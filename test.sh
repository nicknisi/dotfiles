#!/bin/sh

echo "checking existing command"

if test ! $(which brew); then
    echo "Installing homebrew"
else
    echo "brew exists... skipping"
fi

echo "checking a nonexistent command"

if test ! $(which nonexistent); then
    echo "Installing nonexistent"
else
    echo "nonexistent... skipping"
fi

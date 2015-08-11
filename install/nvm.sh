#!/bin/sh

# reload nvm into this environment
source $(brew --prefix nvm)/nvm.sh

nvm install stable
nvm alias default stable

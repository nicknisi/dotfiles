#!/bin/sh

printf "Setting up Git...\n\n"

printf "What is your name? "
read name
printf "What is your email? "
read email
printf "What is your Github usernme? "
read github

git config --global user.name $name
git config --global user.meail $email
git config --global github.user $github

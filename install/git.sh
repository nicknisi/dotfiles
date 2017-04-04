#!/bin/sh

printf "Setting up Git...\n\n"

defaultName=$( git config --global user.name )
defaultEmail=$( git config --global user.email )
defaultGithub=$( git config --global github.user )

read -p "Name [$defaultName] " name
read -p "Email [$defaultEmail] " email
read -p "Github username [$defaultGithub] " github

name=${name:-$defaultName}
email=${email:-$defaultEmail}
github=${github:-$defaultGithub}

git config --global user.name "$name"
git config --global user.email "$email"
git config --global github.user "$github"

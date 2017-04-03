#!/bin/sh

printf "Setting up Git...\n\n"

defaultName="Nick Nisi"
defaultEmail="nick@nisi.org"
defaultGithub="nicknisi"

read -p "Name [$defaultName] " name
read -p "Email [$defaultEmail] " email
read -p "Github username [$defaultGithub] " github

name=${name:-$defaultName}
email=${email:-$defaultEmail}
github=${github:-$defaultGithub}

git config --global user.name $name
git config --global user.meail $email
git config --global github.user $github

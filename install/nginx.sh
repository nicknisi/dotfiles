#!/bin/bash

######################################################
# nginx setup
######################################################

$DOTFILES=$HOME/.dotfiles

echo "Installing nginx"

# first, make sure apache is off
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist

# run nginx when osx starts
sudo cp /usr/local/opt/nginx/homebrew.mxcl.nginx.plist /Library/LaunchDaemons
launchctl load -w ~/Library/LaunchAgents/homebrew.mxcl.nginx.plist

mkdir -p /usr/local/etc/nginx/sites-enabled
cp -R nginx/sites-available /usr/local/etc/nginx/sites-available
mv /usr/local/etc/nginx/nginx.conf /usr/local/etc/nginx/nginx.conf.orig
ln -s $DOTFILES/nginx/nginx.conf /usr/local/etc/nginx/nginx.conf

sites=$( ls -1 -d $DOTFILES/nginx/sites-available)
for site in $sites ; do
    echo "linking $site"
    ln -s $DOTFILES/nginx/sites-available/$site /usr/local/etc/nginx/sites-enabled/$site
done


######################################################
# dnsmasq setup
######################################################

echo "installing dnsmasq"

# move dnsmasq config into place
ln -s $DOTFILES/nginx/dnsmasq.conf /usr/local/etc/

# setup dnsmasq
sudo cp -fv /usr/local/opt/dnsmasq/homebrew.mxcl.dnsmasq.plist /Library/LaunchDaemons
sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.dnsmasq

#!/bin/sh
#first of all
sudo apt-get install wget curl git
#we install sdks and programming languages
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo dpkg --purge packages-microsoft-prod && sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install apt-transport-https
sudo apt-get update
sudo apt-get install dotnet-sdk-3.1
sudo apt-get install aspnetcore-runtime-3.1
#First we install zsh and git, 
sudo apt-get install zsh
sudo apt-get install git-core
#After that we need to download OhmyZsh wget
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
#and set OhmyZsh as a default shell
chsh -s $(which zsh)
# We need to copy this repo to /dotfiles and doing symlinks 
cp zsh/.zshrc $HOME/.zshrc
# to the configuration
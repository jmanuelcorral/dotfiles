#!/bin/sh
#first of all
sudo apt-get install wget curl git unzip git-core zsh
#Install exa, a modern ls replacement Written in Rust
curl https://sh.rustup.rs -sSf | sh
# Till the date of publication of this article, the latest available download version is the 0.8.0
wget -c https://github.com/ogham/exa/releases/download/v0.8.0/exa-linux-x86_64-0.8.0.zip
unzip exa-linux-x86_64-0.8.0.zip
sudo mv exa-linux-x86_64 /usr/local/bin/exa
#we install sdks and programming languages

#starting with netcore
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo dpkg --purge packages-microsoft-prod && sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install apt-transport-https
sudo apt-get update
sudo apt-get install dotnet-sdk-3.1
sudo apt-get install aspnetcore-runtime-3.1

#nvm (node version manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.35.3/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

#After that we need to download OhmyZsh wget
wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh
#and set OhmyZsh as a default shell
chsh -s $(which zsh)
# We need to copy this repo to /dotfiles and doing symlinks 
cp zsh/.zshrc $HOME/.zshrc
# to the configuration

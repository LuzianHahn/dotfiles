# Hal's Dotfiles

[Source](https://www.atlassian.com/git/tutorials/dotfiles)

## How to configure a fresh system

```bash
alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

echo ".cfg" >> .gitignore

git clone --bare git@bitbucket.org:Luzian_Hahn/dotfiles.git $HOME/.cfg

config checkout

config config --local status.showUntrackedFiles no

config submodule update --init --recursive

```



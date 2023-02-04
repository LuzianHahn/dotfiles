# Hal's Dotfiles

[Source](https://www.atlassian.com/git/tutorials/dotfiles)

## How to configure a fresh system

Alias to configure the dotfiles repo globally. Should be included in your bashrc or your bash_aliases.
`alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'`

`echo ".cfg" >> .gitignore`

`git clone --bare <git-repo-url> $HOME/.cfg`

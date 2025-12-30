#!/bin/bash

set -e
# If not running interactively, don't do anything
# Otherwise calling `cfg` does not work
case $- in
    *i*) ;;
    *) echo "call this installer via \"bash -i ${BASH_SOURCE[0]} ...\""; exit 1;;
esac

# abort if index has staged changes or working tree is dirty
if ! cfg diff --quiet --exit-code --cached; then
  echo "Aborting: \"dotfiles\" has staged changes. Commit or stash first."
  exit 2
fi


cfg submodule foreach --recursive '
  git fetch --depth 1 origin || git fetch --unshallow || true;
  if git show-ref --verify --quiet refs/remotes/origin/main; then
    git checkout --detach origin/main;
  elif git show-ref --verify --quiet refs/remotes/origin/master; then
    git checkout --detach origin/master;
  else
    echo "No main/master found in $sm_path — skipping";
  fi
'

# Re-Install submodules if necessary
# coc.nvim
echo "Attempting to re-compile coc.nvim"
(cd ~/.vim/pack/neoclide/opt/coc.nvim && npm ci)
# Install Coc-Plugins for different LSPs
vim -c "CocInstall -sync coc-json coc-yaml coc-jedi coc-rust-analyzer|q"

# fzf.vim (+ fzf)
bash $HOME/.vim/pack/junegunn/opt/fzf/install --bin


cfg add $(cfg submodule foreach -q --recursive 'echo $sm_path')
cfg commit -m "Sync submodules - $(date)"

echo "Sucessfully synced commits, but too scared to push"
echo "Please verify the current state and push manually!"

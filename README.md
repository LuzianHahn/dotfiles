# Hal's Dotfiles

[Source](https://www.atlassian.com/git/tutorials/dotfiles)

## How to configure a fresh system

```bash
# Ensure that at least `curl` and `git` are installed
# `vim` is recommended
curl https://raw.githubusercontent.com/LuzianHahn/dotfiles/debian/.local/installer/dotfile_installer.sh | bash 
# e.g. on alpine systems, `bash` is not included. Use `sh` in this case.
# curl https://raw.githubusercontent.com/LuzianHahn/dotfiles/debian/.local/installer/dotfile_installer.sh | sh
```

## Known issues
* I encounter the following error after opening a `*.py`-buffer:
  `Error: jedi-vim failed to initialize Python: jedi-vim requires Vim with support for Python 3.`
  > Your current version of vim does not come with python support. 
  > (You can check this with `:version` and looking for `+python3`. 
  > If only `python3-` is present, your vim version lacks support)
  > On debian you can install instead `vim-nox` via `apt`, which should provided `+python3`support.

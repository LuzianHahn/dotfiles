# Hal's Dotfiles

[Source](https://www.atlassian.com/git/tutorials/dotfiles)

## How to configure a fresh system

```bash
# Ensure that at least `curl` and `git` are installed
# `vim` is recommended
curl https://raw.githubusercontent.com/LuzianHahn/dotfiles/debian/.local/installer/dotfile_installer.sh | bash 
# on work machines for alternative git authorship use
curl https://raw.githubusercontent.com/LuzianHahn/dotfiles/debian/.local/installer/dotfile_installer.sh | AUTHOR=work bash
# e.g. on alpine systems, `bash` is not included. Use `sh` in this case.
# curl https://raw.githubusercontent.com/LuzianHahn/dotfiles/debian/.local/installer/dotfile_installer.sh | sh
```

## Known issues
* If you encounter the following error after opening a `*.py`-buffer:
  `Error: jedi-vim failed to initialize Python: jedi-vim requires Vim with support for Python 3.`
  > Your current version of vim does not come with python support. 
  > (You can check this with `:version` and looking for `+python3`. 
  > If only `python3-` is present, your vim version lacks support)
  > - On debian you can install instead `vim-nox` via `apt`, which should provided `+python3`support.
  > - On MacOS you need to install `vim` via `brew install vim`. It might be necessary to override `$PATH` here since `vim` is already present per default, but `brew` locates its installed version different from the base version of `vim`
* I want to read `:help`-entries in `vim`, but the system claims `E149: Sorry, no help for <entryX>`.
  Apparently one needs to generate the helptags once on the respective system. 
  See also https://stackoverflow.com/a/22355979.
  So just call `vim -c "helptags <Path-to-doc-folder-in-extension>`.
  > easiest solution would be 
* After syncronizing a device with this repository, I receive errors, when opening vim like:
  ```bash
  Fehler beim Ausführen von "/home/XXX/.vimrc":
  Zeile   63:
  E31: Kein Mapping gefunden
  Zeile   64:
  E31: Kein Mapping gefunden
  Betätigen Sie die EINGABETASTE oder geben Sie einen Befehl ein
  ```
  This means that the respective plugins in vim have not been installed properly yet. 
  One can do so by calling:
  `cfg submodule update --init --recursive`

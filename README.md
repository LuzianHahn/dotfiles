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
# Quick-Setup for LSP-Servers and programming language setups
# -i is necessary, as this scripts sources the ~/.bashrc file, which only works in interactive shells.
bash -i $HOME/.local/installer/extra_installer.sh
```

## Setup of LSP-Servers
> For a comprehensive script, see also `installer/extra_installer.sh`

Right now the vim setup here works with different Servers, which implement the LSP (Language Server Protocol).
In order to receive features in vim like `OpenDocumentation` or `GoToDefinition`,
 one needs to install the respective servers.
I listed how to do this for the languages I typically use:

### Rust
This is ordinary achieved via `rust-analyzer`. One can find a detailed documentation [here](https://rust-analyzer.github.io/manual.html).
In theory it should be enough to call `rustup component add rust-src`

### Python
I am currently using `jedi-language-server` for this, which is a python package, which comes with an own entrypoint.
As I don't want to install this package for every python project I have, I am using my global `uv`-virtualenv for this.
It is intended for user specific python packages.
Therefore it is necessary to have `uv` set up before installing `jedi-language-server`.
See [here](https://docs.astral.sh/uv/getting-started/installation/) for this.
Afterwards one needs to create the global `uv`-virtualenv. The easiest way is to call `. $HOME/.bashrc`.
Now one needs to install `jedi-language-server` via `uv pip install jedi-language-server`.
Finally to circumvent the problem of the global `uv`-virtualenv's binaries colliding, 
 one needs to create a link to the respective `jedi-language-server`-binary via:
 `ln -sf $HOME/.local/lib/uv_base/bin/jedi-language-server $HOME/.local/bin/`.


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
  `cfg submodule update --init --recursive --depth 1`
* If your installed vim version is `<9` you cannot use `coc-nvim`.
  Sometimes it can be a hustle to obtain such a version e.g. on debian < 12 or ubuntu LTS < 24. 
  A potential solution here lies in two options:
  - Using an appimage version of `vim` from [here](https://github.com/vim/vim-appimage/releases).
    Just download the appimage into `$HOME/.local/lib/vim-appimage/` (after creating this directory) and link it via:
    `ln -s $HOME/.local/lib/vim-appimage/gvim.appimage $HOME/.local/bin/vim`

    Unfortunately this version suffers from a small start-up delay, which might be annoying.
    Worse than this, on systems, where you don't have and cannot provide a fusermount utility 
    (e.g. when this error occurs: `Error: No suitable fusermount binary found on the $PATH`),
    this solution is not an option.
  - Compile vim from scratch:
    ```bash
    cd $HOME/.local/lib/
    git clone https://github.com/vim/vim.git --depth 1

    cd vim/src/

    # In case there is no `python3-config` (e.g. on a slurm cluster), consider activating a python3 module there.
    # Otherwise install a python3 version via your package manager.
    ./configure --with-features=huge \
        --enable-multibyte \
        --enable-python3interp=yes \
        --with-python3-config-dir=$(python3-config --configdir) \
        --enable-perlinterp=yes \
        --enable-gui=gtk2 \
        --enable-cscope \
        --prefix=$HOME/.local/

    make && make install
    ```
* After an initial setup including `coc.nvim`, opening the first `.py`-file results into something like:
  ```
[coc.nvim] jedi: Error: Command failed: python3 -m venv --clear $HOME/.config/coc/extensions/node_modules/coc-jedi/.venv && $HOME/.config/coc/extensions/node_modules/coc-jedi/.venv/bin/pip install -U pip jedi-language-server==0.41.1
  ```
  This mostly happens, when `venv` is not available in your global `python3`-setup. (e.g. on hardware maintained by somebody else). It is difficult to make `coc.nvim` use here the default `uv_base`-venv.
  An alternative solution is this:
  ```
  rm -rf $HOME/.config/coc/extensions/node_modules/coc-jedi/.venv
  (
    uv venv --no-project $HOME/.config/coc/extensions/node_modules/coc-jedi/.venv
    deactivate
    source $HOME/.config/coc/extensions/node_modules/coc-jedi/.venv/bin/activate
    uv pip install pip jedi-language-server==0.41.1
  )
  ```


## Unsolved TODOs
#### AutoCompletion not working
- I don't get ALE in combination with jedi-language-server properly to work. Most of the times it seems to work, but then seem situations don't work at all:
  - e.g. `from pkg import `-statements are not autocompleted. It is not even possible to autocomplete `from pkg`. 
  - when running e.g. `import pkg.`-completions, this works only if I don't enter a first letter here (e.g. `import pathlib.P` for `Path`)
  - `click`-completions are not working at all
  - > Seems like this is a general issue of completing modules. It is possible to use GoTo into these modules, when the venv is activated.

> trying to use coc-nvim as completion library. seems to work much better than ALE.
> #### Leftover Issues with coc-nvim
<!-- > - setting up coc-nvim which required last time `npm ci` to create some specific file. Maybe this is not needed if I don't shallow clone the repo. -->
> - my venv has to be active to recognized respective third-party modules
<!-- > - `deactivate` seems to remove cargo, nvm and also uv from my `PATH`. -->
<!-- > - opening `gd` in new tab?  using "gr" and a default setting to open the respective choice in a new tab should do the trick -->
<!-- > - requires node in `bin`, which can be added via `nvm use 22`. However activating a venv is a problem here. Also setting up everything via `nvm` seems quite messy -->
<!-- > - deactivating my uv_base_venv also deactivates my default node version. It needs to be active -->
> - need to learn more about all the different commands

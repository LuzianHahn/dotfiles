# This script can be used to add optional utilities to your setup,
#  like LSP implementations or programming language utilities.

# If not running interactively, don't do anything
# Otherwise calling `. ~/.bashrc` does not work
case $- in
    *i*) ;;
    *) echo "call this installer via \"bash -i ${BASH_SOURCE[0]} ...\""; exit;;
esac

# **Python**
# Install uv if not present. See also https://docs.astral.sh/uv/getting-started/installation/
if ! command -v uv &> /dev/null;then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    . ~/.bashrc 
fi
# Install Jedi's python LSP implementation and make it always accessible.
# The author mentions at https://pypi.org/project/jedi-language-server/ an installation via `pip install -U`, 
#  but since we rather use `uv` to handle user specific installations, this link-based hack is necessary.
echo "Installing jedi-language-server..."
uv pip install jedi-language-server
ln -sf $HOME/.local/lib/uv_base/bin/jedi-language-server $HOME/.local/bin

# **Rust**
# Install rustup, cargo etc. if not present. See also https://www.rust-lang.org/tools/install
if ! command -v rustup &> /dev/null;then
    echo "Installing rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# Install rust-analyzer as Rust LSP implementation. See also https://rust-analyzer.github.io/manual.html#rustup
if ! rust-analyzer --version &> /dev/null;then  # default rust-analyzer installation comes sometimes broken. 
    echo "Installing rust-analyzer..."
    rustup component add rust-analyzer
fi

install_coc_nvim_dependencies () {
    # Install NodeJS as dependency for Coc.nvim
    # see also https://nodejs.org/en/download/
    if ! command -V nvm &> /dev/null;then
        echo "No "nvm" found. Attempting to install..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
        . "$HOME/.bashrc"
        nvm install 22
        ln -sf $(which node) $HOME/.local/bin
        ln -sf $(which npm) $HOME/.local/bin
        ln -sf $(which npx) $HOME/.local/bin
    fi

    # if compiled coc.nvim is missing, use npm to compile it
    if [ ! -f ~/.vim/pack/neoclide/opt/coc.nvim/build/index.js ];then
        echo "Attempting to compile coc.nvim"
        ( cd ~/.vim/pack/neoclide/opt/coc.nvim && npm ci )
    fi

    # Install Coc-Plugins for different LSPs
    vim -c "CocInstall -sync coc-json coc-yaml coc-jedi coc-rust-analyzer|q"
}

if vim --version &> /dev/null;then
    if [ $(vim --version | grep '^VIM' | awk '{print $5}' | cut -d. -f1) -ge 9 ];then
        install_coc_nvim_dependencies
    else
        echo "Installed version of vim needs to be => 9 to support coc.nvim."
    fi
else
    echo "\"vim\" was not found"
fi


# Install fzf.vim helper binaries
# Can also be used indepdently from vim
echo "Installing fzf.vim helper binaries..."
if [ ! -f $HOME/.vim/pack/junegunn/opt/fzf/install ];then
    echo "Did not find fzf-installer script. Did you properly clonse junegunn/fzf?"
    echo 'Consider calling "cfg submodule update --init --recursive --depth 1"'
    exit 1
else
    bash $HOME/.vim/pack/junegunn/opt/fzf/install --bin
fi
# For some reason, it is not possible to properly get PATH pointing to ~/.cargo/bin via sourcing rc-files.
# Hence we directly use now the binary-paths
cargo_bin=$HOME/.cargo/bin/cargo
rustup_bin=$HOME/.cargo/bin/rustup
if command -v $cargo_bin &> /dev/null;then
    if ! command -v cc &> /dev/null;then
        echo "cc is missing and is needed to compile packages via cargo locally."
        echo "Either install cc (e.g. build-essential on Debian) or install fd-find and rgrep directly..."
        exit 2
    fi
    # As we are pulling the latest versions of fd-find and ripgrep, rustc might need to be up-to-date
    $rustup_bin update
    $cargo_bin install fd-find
    $cargo_bin install ripgrep
else
    echo "cargo is missing. Check your rustup setup!"
    exit 3
fi


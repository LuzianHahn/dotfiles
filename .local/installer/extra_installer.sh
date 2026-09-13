# This script can be used to add optional utilities to your setup,
#  like LSP implementations or programming language utilities.

# If not running interactively, don't do anything
# Otherwise calling `. ~/.bashrc` does not work
# Set CI_NONINTERACTIVE=1 to allow running in non-interactive environments
#  (e.g. CI or integration tests); sourcing ~/.bashrc is then skipped.
case $- in
    *i*) ;;
    *) [ -n "${CI_NONINTERACTIVE:-}" ] || { echo "call this installer via \"bash -i ${BASH_SOURCE[0]} ...\""; exit; } ;;
esac

# Optional categories can be skipped via SKIP=csv (e.g. SKIP=uv,rust,node,coc,fzf).
# This lets CI / integration tests install only what they need without
# running the heavy Rust toolchain or compiling from source.
SKIP="${SKIP:-}"
skip () {
    case ",$SKIP," in
        *",$1,"*) return 0 ;;
        *) return 1 ;;
    esac
}

# **Python**
# Install uv if not present. See also https://docs.astral.sh/uv/getting-started/installation/
if ! skip "uv"; then
    if ! command -v uv &> /dev/null;then
        echo "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        # Sourcing ~/.bashrc is only meaningful for the interactive install.
        [ -n "${CI_NONINTERACTIVE:-}" ] || . ~/.bashrc
    fi
    # In non-interactive mode the installer's PATH update (via ~/.bashrc) is
    #  not visible, so fall back to uv's documented install location.
    if ! command -v uv &> /dev/null && [ -x "$HOME/.local/bin/uv" ]; then
        uv() { "$HOME/.local/bin/uv" "$@"; }
    fi
    if ! command -v uv &> /dev/null;then
        echo "WARN: uv is not available after installation; skipping jedi-language-server." >&2
    else
        # Install Jedi's python LSP implementation and make it always accessible.
        # The author mentions at https://pypi.org/project/jedi-language-server/ an installation via `pip install -U`,
        #  but since we rather use `uv` to handle user specific installations, this link-based hack is necessary.
        # The dedicated uv_base venv is created on first run so that `uv pip`
        #  has a target environment and the link below has a real target.
        echo "Installing jedi-language-server..."
        [ -d "$HOME/.local/lib/uv_base" ] || uv venv "$HOME/.local/lib/uv_base"
        VIRTUAL_ENV="$HOME/.local/lib/uv_base" uv pip install jedi-language-server
        mkdir -p "$HOME/.local/bin"
        ln -sf "$HOME/.local/lib/uv_base/bin/jedi-language-server" "$HOME/.local/bin"
    fi
fi

# **Rust**
# Install rustup, cargo etc. if not present. See also https://www.rust-lang.org/tools/install
if ! skip "rust"; then
    if ! command -v rustup &> /dev/null;then
        echo "Installing rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    fi
    # Install rust-analyzer as Rust LSP implementation. See also https://rust-analyzer.github.io/manual.html#rustup
    if ! rust-analyzer --version &> /dev/null;then  # default rust-analyzer installation comes sometimes broken.
        echo "Installing rust-analyzer..."
        rustup component add rust-analyzer
    fi
fi

install_coc_nvim_dependencies () {
    # Install NodeJS as dependency for Coc.nvim and copilot.vim
    # see also https://nodejs.org/en/download/
    if ! skip "node"; then
        if ! command -V nvm &> /dev/null;then
            echo "No "nvm" found. Attempting to install..."
            curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
            [ -n "${CI_NONINTERACTIVE:-}" ] || . "$HOME/.bashrc"
            # nvm is a shell function; in non-interactive shells the installer's
            #  rc-file updates are not visible, so load it explicitly.
            if ! command -V nvm &> /dev/null && [ -s "$HOME/.nvm/nvm.sh" ]; then
                . "$HOME/.nvm/nvm.sh"
            fi
            nvm install 24
            ln -sf $(which node) $HOME/.local/bin
            ln -sf $(which npm) $HOME/.local/bin
            ln -sf $(which npx) $HOME/.local/bin
        fi
    fi

    # if compiled coc.nvim is missing, use npm to compile it
    if [ ! -f ~/.vim/pack/neoclide/opt/coc.nvim/build/index.js ];then
        echo "Attempting to compile coc.nvim"
        ( cd ~/.vim/pack/neoclide/opt/coc.nvim && npm ci )
    fi

    # Install Coc-Plugins for different LSPs
    vim -c "CocInstall -sync coc-json coc-yaml coc-jedi coc-rust-analyzer|q"
}

if ! skip "coc"; then
    if vim --version &> /dev/null;then
        if [ $(vim --version | grep '^VIM' | awk '{print $5}' | cut -d. -f1) -ge 9 ];then
            install_coc_nvim_dependencies
        else
            echo "Installed version of vim needs to be => 9 to support coc.nvim."
        fi
    else
        echo "\"vim\" was not found"
    fi
fi


# Install fzf.vim helper binaries
# Can also be used indepdently from vim
if ! skip "fzf"; then
    echo "Installing fzf.vim helper binaries..."
    if [ ! -f $HOME/.vim/pack/junegunn/opt/fzf/install ];then
        echo "Did not find fzf-installer script. Did you properly clonse junegunn/fzf?"
        echo 'Consider calling "cfg submodule update --init --recursive --depth 1"'
        exit 1
    else
        bash $HOME/.vim/pack/junegunn/opt/fzf/install --bin
    fi
fi

# For some reason, it is not possible to properly get PATH pointing to ~/.cargo/bin via sourcing rc-files.
# Hence we directly use now the binary-paths
if ! skip "rust"; then
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
fi

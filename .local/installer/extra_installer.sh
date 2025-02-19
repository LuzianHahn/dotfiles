# This script can be used to add optional utilities to your setup,
#  like LSP implementations or programming language utilities.

# If not running interactively, don't do anything
# Otherwise calling `. ~/.bashrc` does not work
case $- in
    *i*) ;;
    *) echo "call this installer via \"bash -i extra_$(basename ${BASH_SOURCE[0]}) ...\""; exit;;
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
    . ~/.bashrc
fi
# Install rust-analyzer as Rust LSP implementation. See also https://rust-analyzer.github.io/manual.html#rustup
if ! rust-analyzer --version &> /dev/null;then  # default rust-analyzer installation comes sometimes broken. 
    echo "Installing rust-analyzer..."
    rustup component add rust-analyzer
fi


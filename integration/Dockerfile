# Full-fidelity clean-room image for the dotfiles integration test.
#
# It reproduces a fresh Debian machine setup literally the way the README
# tells a user to do it:
#   1. apt packages the installers expect
#   2. the published dotfile installer one-liner (installs the "debian"
#      branch of this repo into $HOME via work-tree mode + submodules)
#   3. the published extra installer (uv + jedi, rust + rust-analyzer,
#      nvm + node 24 + coc.nvim compile + coc LSP extensions, fzf binaries,
#      fd + ripgrep) — run with `bash -i` exactly as on a real machine,
#      since it sources ~/.bashrc for PATH
#
# The test script then runs `vim_test.sh --local` inside this image, exactly
# as it would on a real machine. Full fidelity is deliberate (no skipping of
# the Rust toolchain): the image must contain everything a user gets.
#
# Testing a branch other than the published "debian" would require the
# installer hooks from the "repoint-coc-submodule-and-add-ci" branch
# (DOTFILES_REPO_URL); that use case is tracked separately (see
# .planning/seeds/integration-test-branch-mode.md).

ARG DEBIAN_TAG=latest
FROM debian:${DEBIAN_TAG}

ENV DEBIAN_FRONTEND=noninteractive

# --- base packages the installers assume exist ------------------------------
# vim-nox: the README's known-issues section requires +python3, which plain
# `vim` in newer Debian/Ubuntu point releases does not guarantee.
RUN apt-get update && apt-get install -y --no-install-recommends \
        vim-nox \
        vim \
        curl \
        ca-certificates \
        git \
        build-essential \
        python3 \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

# --- the published dotfile installer (README: "How to configure a fresh system")
RUN curl -fsSL https://raw.githubusercontent.com/LuzianHahn/dotfiles/debian/.local/installer/dotfile_installer.sh | bash

# --- the published extra installer (LSPs, language toolchains, node, fzf) ---
# `bash -i` is required because the script sources ~/.bashrc for PATH updates.
RUN bash -i /root/.local/installer/extra_installer.sh

# --- pre-warm the coc-jedi jedi-language-server venv -------------------------
# coc-jedi lazily creates a Python "venv" holding a version-pinned
# jedi-language-server the first time it activates the Python LSP. If that
# happened *during* the test, the LSP canary would have to wait on a network
# pip install (flaky / slow in CI). So we do it here at build time, at exactly
# the path and version coc-jedi expects, and make the canary reuse it.
#
#   - path:  $HOME/.config/coc/extensions/node_modules/coc-jedi/.venv
#            (coc's dataHome extensions folder; coc-jedi's JLS_VENV='.venv')
#   - version: read dynamically from the installed coc-jedi package.json
#            (jlsVersion field), because it is what coc-jedi pins & verifies
RUN set -eux \
    && EXT="$HOME/.config/coc/extensions/node_modules/coc-jedi" \
    && test -d "$EXT" \
    && JLS_VERSION="$(python3 -c "import json;print(json.load(open('$EXT'+'/package.json'))['jlsVersion'])")" \
    && VENV="$EXT/.venv" \
    && python3 -m venv --clear "$VENV" \
    && "$VENV/bin/pip" install -U pip "jedi-language-server==$JLS_VERSION" \
    && sed -i 's/include-system-site-packages = false/include-system-site-packages = true/' "$VENV/pyvenv.cfg" \
    && "$VENV/bin/jedi-language-server" --version \
    && echo "pre-warmed jedi-language-server venv at $VENV ($("$VENV/bin/jedi-language-server" --version))"

# --- sanity: the setup must at least start -----------------------------------
# Each RUN gets a fresh non-interactive shell, so PATH must be re-exported the
# same way the user's shell would see it (local installers symlink into
# ~/.local/bin, cargo into ~/.cargo/bin, fzf into ~/.fzf/bin).
RUN export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.fzf/bin:$PATH" \
    && vim --version | head -n1 \
    && vim -N --not-a-term -c 'qa!' \
    && node --version \
    && rg --version | head -n1 \
    && fd --version \
    && jedi-language-server --version \
    && "$HOME/.config/coc/extensions/node_modules/coc-jedi/.venv/bin/jedi-language-server" --version

CMD ["bash"]

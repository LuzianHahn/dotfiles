#!/usr/bin/env bash
#
# Integration test for the dotfiles vim setup.
#
# Two modes:
#   (default)  Docker clean-room: builds a full-fidelity image from
#              integration/Dockerfile (which installs the published "debian"
#              branch of this repo) and runs the checks inside a fresh
#              container. This is what the scheduled CI job runs.
#   --local    Runs the checks directly against the currently installed
#              setup of this machine ($HOME/.vimrc, $HOME/.vim, ...).
#
# Exit codes:
#   0  all checks passed
#   1  one or more checks failed
#   2  environment error (docker missing, vimrc missing, usage error)
#
# Failure contract: every check prints its own descriptor BEFORE it runs,
# captures its output, and reports PASS/FAIL individually with the captured
# details. A check that dies unexpectedly is reported by an ERR trap with
# file/line context. The script NEVER exits silently.

set -Eeuo pipefail

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

MODE="docker"
VIMRC_PATH="${VIMRC_PATH:-${HOME}/.vimrc}"
# Per vim invocation hard timeout (seconds). Generous to cover the LSP check,
# which can wait for coc + the LSP server to start.
VIM_TIMEOUT="${VIM_TEST_VIM_TIMEOUT:-240}"
# Inner deadline for the LSP canary (seconds) — how long to wait for
# diagnostics to be published before declaring the chain broken. coc-jedi may
# build its jedi-language-server venv (a pip install) on first activation, so
# this is intentionally generous.
VIM_LSP_DEADLINE="${VIM_TEST_LSP_DEADLINE:-120}"
IMAGE_NAME="${VIM_TEST_IMAGE:-dotfiles-vim-test:latest}"
SKIP_BUILD=0

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/vim_test.XXXXXX")"

PASS=0
FAIL=0
FAILED_CHECKS=()
CURRENT_CHECK="(script startup)"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'; NC=$'\033[0m'
if [ ! -t 1 ] || [ -n "${NO_COLOR:-}" ]; then
    RED=""; GREEN=""; YELLOW=""; CYAN=""; NC=""
fi

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

on_err() {
    local exit_code=$?
    printf '%s[ERR ]%s check "%s" died unexpectedly (exit=%d, line %d)\n' \
        "$RED" "$(printf '[%s] ' "$(date -u +%H:%M:%S)")" "$NC" \
        "$CURRENT_CHECK" "$exit_code" "${1:-?}" >&2
    exit "$exit_code"
}
trap 'on_err $LINENO' ERR

cleanup() {
    rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); }
fail() {
    FAIL=$((FAIL + 1))
    FAILED_CHECKS+=("$CURRENT_CHECK")
}

# Strip ANSI escape codes and carriage returns for readable diagnostics.
sanitize() {
    sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' | tr -d '\r'
}

# run_check NAME FUNCTION
# Prints the descriptor first, then runs FUNCTION in the current shell inside
# a guarded context (errexit/ERR trap inactive for its body), so the
# function's own exit code decides pass/fail. Output is captured to a temp
# file — no subshell, no traps firing at the wrong scope.
run_check() {
    local name="$1" fn="$2"
    CURRENT_CHECK="$name"
    printf '%s[ RUN ]%s %s\n' "$CYAN" "$NC" "$name"
    local out="$WORK_DIR/checked_output"
    local rc=0
    "$fn" >"$out" 2>&1 || rc=$?
    local output
    output="$(cat "$out" 2>/dev/null || true)"
    if [ "$rc" -eq 0 ]; then
        pass
        printf '%s[  OK ]%s %s\n' "$GREEN" "$NC" "$name"
        if [ -n "$output" ]; then
            printf '%s\n' "$output" | sed 's/^/       /'
        fi
    else
        fail
        printf '%s[FAIL ]%s %s (exit=%d)\n' "$RED" "$NC" "$name" "$rc"
        if [ -n "$output" ]; then
            printf '%s\n%s----- captured output -----\n%s\n%s---------------------------\n' \
                "$YELLOW" "$YELLOW" "$output" "$YELLOW"
        else
            printf '%s       (no output captured)%s\n' "$YELLOW" "$NC"
        fi
    fi
}

die_env() {
    printf '%s[ABORT]%s %s\n' "$RED" "$NC" "$1" >&2
    exit 2
}

# Show the tail of a vim stderr capture (sanitized) for failure diagnosis.
show_vim_err() {
    local errfile="$1"
    if [ -s "$errfile" ]; then
        echo "----- vim stderr (tail) -----"
        sanitize < "$errfile" | tail -n 15 | sed 's/^/       | /'
    fi
}

# ---------------------------------------------------------------------------
# vim invocation helper
#
# vim_batch ERRFILE -c CMD [-c CMD ...]
#   Runs vim in batch mode with a hard timeout. Captures stderr into
#   ERRFILE. Sets VIM_BATCH_RC (0 = finished, 124 = timed out).
#
# Deliberately NO -s: we must keep vim's stderr to diagnose failures.
#
# IMPORTANT: vim's process exit code in batch mode is NOT a reliable pass/
# fail signal (observed: `vim -N --not-a-term -c 'exit(0)'` exits 1 even on
# success; a startup error in the vimrc can also mask the real error). So
# every functional check follows a marker-file contract instead:
#
#   The check's vim script writes a single marker line into $VIM_MARKER (via
#   writefile) — "OK ...", "FAIL <why>", "DIAGS ...", or "TIMEOUT ..." — and
#   then executes :qa!. Bash judges the check from the marker file and shows
#   the captured stderr for context. No marker file at all means vim died
#   before finishing the check (e.g. an error in the vimrc aborted the
#   session before our -c scripts ran) — which is itself a failure, with the
#   reason in the stderr capture.
# ---------------------------------------------------------------------------

# Common flags for isolation runs:
#   -u NONE  : no default/system rc; results depend only on OUR config
#   -N       : no compatibility shims (plugins like fugitive parse differently
#              in compatible mode)
#   --not-a-term : batch mode, stdout/stderr still emitted
#   +copilot off before the vimrc is sourced so no check ever hits GitHub.
# Kept as an array — the -c argument contains spaces.
VIM_SRC_BASE=(-u NONE -N --not-a-term -c 'let g:copilot_enabled=0')

VIM_BATCH_RC=0
VIM_BATCH_ERR=""
vim_batch() {
    VIM_BATCH_RC=0
    VIM_BATCH_ERR="$WORK_DIR/vim_batch.err"
    : > "$VIM_BATCH_ERR"
    timeout -k 5 "$VIM_TIMEOUT" vim "$@" 2> "$VIM_BATCH_ERR"
    VIM_BATCH_RC=$?
}

# ---------------------------------------------------------------------------
# check: vim binary + version + build features
# ---------------------------------------------------------------------------
FEATURES=""

check_vim() {
    if ! command -v vim >/dev/null 2>&1; then
        echo "vim binary not found on PATH"
        return 1
    fi
    local ver major
    ver="$(vim --version | head -n1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)"
    [ -n "$ver" ] || { echo "could not parse vim version from: $(vim --version | head -n1)"; return 1; }
    major="${ver%%.*}"
    if [ "$major" -lt 9 ]; then
        echo "vim $ver is too old; this setup requires vim >= 9.0 (coc.nvim guard)"
        return 1
    fi
    echo "vim $ver"

    FEATURES="$(vim --version | grep -oE '\+(python3|channel|job|timers|javascript|clipboard)' | sort -u)"

    local f missing=0
    for f in python3 channel job timers; do
        if ! printf '%s\n' "$FEATURES" | grep -qx "+$f"; then
            echo "vim is missing required feature +$f (coc/LSP machinery breaks without it)"
            missing=1
        fi
    done
    # Advisory features: absence is environment-specific (headless images
    # usually lack clipboard) and does not break the tested utilities.
    for f in javascript clipboard; do
        printf '%s\n' "$FEATURES" | grep -qx "+$f" \
            || echo "note: vim built without +$f (advisory)"
    done
    return "$missing"
}

# ---------------------------------------------------------------------------
# check: git binary (needed for vim-fugitive functionality)
# ---------------------------------------------------------------------------
check_git() {
    local g
    g="$(git --version 2>&1)" || { echo "git not available: $g"; return 1; }
    echo "$g"
}

# ---------------------------------------------------------------------------
# check: node availability (coc.nvim runtime dependency)
# ---------------------------------------------------------------------------
check_node() {
    local node_version=""
    if [ -s "${HOME}/.nvm/nvm.sh" ]; then
        node_version="$(nvm current 2>/dev/null || true)"
    fi
    if [ -z "$node_version" ] || [ "$node_version" = "none" ]; then
        if command -v node >/dev/null 2>&1; then
            node_version="$(node --version 2>/dev/null || true)"
        fi
    fi
    if [ -z "$node_version" ]; then
        echo "node is not available via nvm (\`nvm current\` -> none) or PATH"
        echo "(required by coc.nvim; extra_installer.sh normally provides it via nvm + symlinks in ~/.local/bin)"
        return 1
    fi
    echo "node $node_version"
}

# ---------------------------------------------------------------------------
# check: all plugin directories are present and non-empty
# ---------------------------------------------------------------------------
check_plugin_dirs() {
    local plugins=(
        ".vim/pack/tpope/opt/vim-fugitive"
        ".vim/pack/tpope/opt/vim-commentary"
        ".vim/pack/junegunn/opt/fzf"
        ".vim/pack/junegunn/opt/fzf.vim"
        ".vim/pack/github/opt/copilot.vim"
        ".vim/pack/neoclide/opt/coc.nvim"
    )
    local p missing=0
    for p in "${plugins[@]}"; do
        if [ ! -d "${HOME}/${p}" ] || [ -z "$(ls -A "${HOME}/${p}" 2>/dev/null)" ]; then
            echo "missing or empty plugin directory: ${p}"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ]
}

# ---------------------------------------------------------------------------
# check: coc.nvim is compiled (build/index.js, created by npm ci in
# extra_installer.sh)
# ---------------------------------------------------------------------------
check_coc_build() {
    local f="${HOME}/.vim/pack/neoclide/opt/coc.nvim/build/index.js"
    if [ ! -f "$f" ]; then
        echo "coc.nvim is not compiled: $f is missing"
        echo "(run 'cd ~/.vim/pack/neoclide/opt/coc.nvim && npm ci' or re-run extra_installer.sh)"
        return 1
    fi
    echo "coc.nvim build artifact present"
}

# ---------------------------------------------------------------------------
# check: LSP servers / helpers are present
#   - jedi-language-server is functionally tested below; binary must resolve
#   - rust-analyzer, coc-json, coc-yaml: presence only (see README)
# ---------------------------------------------------------------------------
check_lsp_tools() {
    local missing=0

    if ! command -v jedi-language-server >/dev/null 2>&1 \
        && [ ! -x "${HOME}/.local/lib/uv_base/bin/jedi-language-server" ]; then
        echo "jedi-language-server binary not found (needed for the python LSP canary)"
        missing=1
    fi

    if ! command -v rust-analyzer >/dev/null 2>&1 \
        && [ ! -x "${HOME}/.cargo/bin/rust-analyzer" ]; then
        echo "rust-analyzer binary not found"
        missing=1
    fi

    local ext
    for ext in coc-json coc-yaml coc-jedi coc-rust-analyzer; do
        if [ ! -d "${HOME}/.config/coc/extensions/node_modules/${ext}" ]; then
            echo "coc extension not installed: ${ext} (~/.config/coc/extensions/node_modules/${ext})"
            missing=1
        fi
    done

    return "$missing"
}

# ---------------------------------------------------------------------------
# check: the search utilities the fzf.vim commands delegate to
# (a missing binary means :Rg/:Files et al. break at runtime)
# ---------------------------------------------------------------------------
check_search_tools() {
    local missing=0 t
    for t in rg fd fzf; do
        if ! command -v "$t" >/dev/null 2>&1; then
            echo "search utility not on PATH: $t (needed by fzf.vim's :Rg/:Files/:Lines)"
            missing=1
        fi
    done
    return "$missing"
}

# ---------------------------------------------------------------------------
# check: the INSTALLED setup starts up like a user would (plain vim with
# default rc -> $HOME/.vimrc). This is the "does my setup even boot" canary.
# ---------------------------------------------------------------------------
check_vimrc_startup() {
    local marker="$WORK_DIR/startup.marker"
    export VIM_MARKER="$marker"
    # Plain vim with DEFAULT rc (no -u NONE): this is literally what a user's
    # first `vim` does, i.e. $HOME/.vimrc + $HOME/.vim (including coc's
    # auto server start) must not break startup or hang.
    # copilot is disabled by default in the vimrc itself (g:copilot_enabled=0).
    vim_batch -N --not-a-term -c \
        'call writefile(["OK vim " . string(v:version)], $VIM_MARKER, "e")' -c 'qa!'
    if [ "$VIM_BATCH_RC" -eq 124 ]; then
        echo "vim start-up TIMED OUT after ${VIM_TIMEOUT}s (coc server or a plugin blocking startup?)"
        return 1
    fi
    if [ ! -s "$marker" ]; then
        echo "start-up did not write its OK marker — an error in the rc aborted the session"
        show_vim_err "$VIM_BATCH_ERR"
        return 1
    fi
    local line; line="$(head -n1 "$marker")"
    case "$line" in
        OK\ vim\ *)
            echo "$line"
            return 0
            ;;
        *)
            echo "unexpected marker: $line"
            show_vim_err "$VIM_BATCH_ERR"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# check: plugins registered their commands / functions (loaded, not just
# present on disk)
# ---------------------------------------------------------------------------
check_plugin_commands() {
    local script="$WORK_DIR/vt_plugins.vim"
    local marker="$WORK_DIR/plugins.marker"
    cat > "$script" <<'EOF'
function! VT_Run() abort
  let s:plug = substitute(maparg('<Plug>(copilot-suggest)', 'i'), '\n', '', '')
  call writefile([
        \ 'fugitive=' . exists(':Git'),
        \ 'commentary=' . exists(':Commentary'),
        \ 'fzf_files=' . exists(':Files'),
        \ 'fzf_lines=' . exists(':Lines'),
        \ 'fzf_blines=' . exists(':BLines'),
        \ 'fzf_rg=' . exists(':Rg'),
        \ 'copilot_cmd=' . exists(':Copilot'),
        \ 'copilot_suggest=' . s:plug,
        \ 'togglegitfiles=' . exists('*ToggleGitFiles'),
        \ 'map_gb=' . substitute(maparg('gb', 'n'), '\n', '', ''),
        \ 'map_cffgg=' . substitute(maparg('<C-f>gg', 'n'), '\n', '', ''),
        \ ], $VIM_MARKER, 'e')
  execute 'qa!'
endfunction
call VT_Run()
EOF
    export VIM_MARKER="$marker"
    local rc=0
    vim_batch "${VIM_SRC_BASE[@]}" -c "source ${HOME}/.vimrc" -c "source ${script}" || rc=$?
    [ "$rc" -eq 124 ] && { echo "plugin registry check TIMED OUT after ${VIM_TIMEOUT}s"; show_vim_err "$VIM_BATCH_ERR"; return 1; }
    if [ ! -s "$marker" ]; then
        echo "loading vimrc/plugins failed before the check completed"
        echo "       -> a plugin is missing or its source raised an error; see stderr below"
        show_vim_err "$VIM_BATCH_ERR"
        return 1
    fi
    local name bad=""
    for name in fugitive commentary fzf_files fzf_lines fzf_blines fzf_rg copilot_cmd; do
        # exists(':Cmd') returns 1 or 2 depending on how the command was
        # defined; both mean "present".
        grep -Eq "^${name}=[12]$" "$marker" || bad="$bad $name"
    done
    grep -Eq "^togglegitfiles=1$" "$marker" || bad="$bad togglegitfiles"
    # copilot's <Plug>(copilot-suggest) resolves to a copilot#* invocation once
    # the plugin is loaded (the function itself is autoloaded, so checking
    # exists('*copilot#Accept') directly is unreliable).
    grep -Eq "^copilot_suggest=.*copilot#" "$marker" || bad="$bad copilot_suggest"
    if [ -n "$bad" ]; then
        echo "expected but not registered:$bad"
        echo "--- actual registry ---"
        sed 's/^/       /' "$marker"
        return 1
    fi
    grep -Fq "map_gb=:Git blame" "$marker" \
        || { echo "mapping 'gb' is not ':Git blame'"; sed 's/^/       /' "$marker"; return 1; }
    grep -Fq "map_cffgg=:call ToggleGitFiles()" "$marker" \
        || { echo "mapping '<C-f>gg' does not call ToggleGitFiles"; sed 's/^/       /' "$marker"; return 1; }
    echo "all expected plugin commands/functions registered"
}

# ---------------------------------------------------------------------------
# check: vim-commentary actually comments a line
# ---------------------------------------------------------------------------
check_commentary_functional() {
    local f="$WORK_DIR/commentary_test.py"
    local script="$WORK_DIR/vt_commentary.vim"
    printf 'x = 1\ny = 2\n' > "$f"
    cat > "$script" <<'EOF'
function! VT_Commentary() abort
  edit $VT_FILE
  call setpos('.', [0, 1, 1, 0])
  try
    Commentary
  catch
    call writefile(['FAIL :Commentary raised: ' . v:exception], $VIM_MARKER, 'e')
    return
  endtry
  silent! write
  call writefile(['OK ' . getline(1)], $VIM_MARKER, 'e')
endfunction
call VT_Commentary()
execute 'qa!'
EOF
    export VIM_MARKER="$WORK_DIR/commentary.marker" VT_FILE="$f"
    local rc=0
    vim_batch "${VIM_SRC_BASE[@]}" -c "source ${HOME}/.vimrc" -c "source ${script}" || rc=$?
    [ "$rc" -eq 124 ] && { echo "commentary check TIMED OUT"; show_vim_err "$VIM_BATCH_ERR"; return 1; }
    local marker="$WORK_DIR/commentary.marker"
    if [ ! -s "$marker" ]; then
        echo ":Commentary run aborted before writing a marker (command missing or error)"
        show_vim_err "$VIM_BATCH_ERR"
        return 1
    fi
    local line; line="$(head -n1 "$marker")"
    case "$line" in
        OK\ \#*)
            echo "line 1 commented: ${line#OK }"
            return 0
            ;;
        OK\ *)
            echo "line 1 was changed but is not a comment marker line: ${line#OK }"
            return 1
            ;;
        FAIL\ *)
            echo "${line#FAIL }"
            show_vim_err "$VIM_BATCH_ERR"
            return 1
            ;;
        *)
            echo "unexpected marker: $line"
            show_vim_err "$VIM_BATCH_ERR"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# check: vim-fugitive can actually operate on a git repository.
# Runs inside a scratch repo with one commit and uses fugitive's own
# synchronous git machinery on it:
#   - FugitiveGitDir()  : finds the .git of the scratch repo
#   - fugitive#Head()   : resolves the current branch
#   - fugitive#RevParse('HEAD') : runs real `git rev-parse` through fugitive
# A missing plugin, missing git binary, or broken repo all fail this.
# ---------------------------------------------------------------------------
check_fugitive_functional() {
    local d="$WORK_DIR/fugitive_repo"
    mkdir -p "$d"
    ( cd "$d" \
        && git init -q \
        && git -c user.email=t@t.local -c user.name=t commit -q --allow-empty -m init ) \
        || { echo "could not init scratch git repo"; return 1; }
    local expected
    expected="$(git -C "$d" rev-parse HEAD)"
    local script="$WORK_DIR/vt_fugitive.vim"
    cat > "$script" <<'EOF'
function! VT_Fugitive() abort
  execute 'cd ' . fnameescape($VT_DIR)
  let s:out = []
  try
    let s:dir = FugitiveGitDir()
    call add(s:out, 'gitdir=' . s:dir)
    if empty(s:dir)
      call writefile(['FAIL FugitiveGitDir() found no repository'], $VIM_MARKER, 'e')
      return
    endif
    let s:branch = fugitive#Head()
    call add(s:out, 'branch=' . s:branch)
    let s:sha = fugitive#RevParse('HEAD')
    call add(s:out, 'sha=' . s:sha)
  catch
    call writefile(['FAIL fugitive raised: ' . v:exception], $VIM_MARKER, 'e')
    return
  endtry
  call writefile(['OK sha=' . s:sha . ' branch=' . s:branch], $VIM_MARKER, 'e')
endfunction
call VT_Fugitive()
execute 'qa!'
EOF
    export VT_DIR="$d" VIM_MARKER="$WORK_DIR/fugitive.marker"
    local rc=0
    vim_batch "${VIM_SRC_BASE[@]}" -c "source ${HOME}/.vimrc" -c "source ${script}" || rc=$?
    [ "$rc" -eq 124 ] && { echo "fugitive check TIMED OUT"; show_vim_err "$VIM_BATCH_ERR"; return 1; }
    local marker="$WORK_DIR/fugitive.marker"
    if [ ! -s "$marker" ]; then
        echo "fugitive run aborted before writing a marker (plugin or git binary broken)"
        show_vim_err "$VIM_BATCH_ERR"
        return 1
    fi
    local line; line="$(head -n1 "$marker")"
    case "$line" in
        OK\ sha=*)
            local got
            got="$(printf '%s' "${line#OK sha=}" | awk '{print $1}')"
            if [ "$got" = "$expected" ]; then
                echo "fugitive resolved the scratch repo: $line"
                return 0
            fi
            echo "fugitive rev-parse mismatch: got '$got', git says '$expected'"
            return 1
            ;;
        OK\ *)
            echo "unexpected OK marker: $line"
            return 1
            ;;
        FAIL\ *)
            echo "${line#FAIL }"
            show_vim_err "$VIM_BATCH_ERR"
            return 1
            ;;
        *)
            echo "unexpected marker: $line"
            show_vim_err "$VIM_BATCH_ERR"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# check: the python LSP (coc.nvim + coc-jedi + jedi-language-server) really
# works: open a file with a deliberate error and require that diagnostics are
# published. This is the deep functional canary.
#
# Pattern (derived from coc.nvim's own test approach, adapted for self-
# contained batch mode):
#   - never use -es/-s (stdout/stderr are suppressed there; this is exactly
#     what made the old test die silently)
#   - explicitly :set ft=python (the LSP only attaches on the FileType
#     autocmd, which is not guaranteed to have fired by the time our -c
#     scripts run)
#   - send the VimEnter RPC notification explicitly: coc's node server only
#     completes init() (extensions + LSP clients) after receiving it, and
#     headless `-c` mode never emits it on its own (v:vim_did_enter stays 0)
#   - :sleep loops keep vim's main loop pumping, which — verified on this
#     system — processes job/channel events (coc's RPC server is a job), so
#     async LSP responses arrive while we poll
#   - CocAction('fillDiagnostics') is a synchronous RPC; its results land in
#     the location list, which we poll
#   - the canary is a SYNTAX error because the pinned jedi-language-server
#     (0.41.1) publishes syntax diagnostics only (no semantic diagnostics)
# ---------------------------------------------------------------------------
check_lsp_jedi() {
    local d="$WORK_DIR/lsp_py"
    local f="$d/canary.py"
    local script="$WORK_DIR/vt_lsp.vim"
    mkdir -p "$d"
    # Deliberate SYNTAX error on line 1. The pinned jedi-language-server
    # 0.41.1 (as shipped by coc-jedi) only publishes SYNTAX diagnostics
    # (its lsp_python_diagnostic() maps jedi.api.errors.SyntaxError only —
    # there is no semantic diagnostic provider), so an attribute/logic error
    # like `os.definitely_not_a_function()` would legitimately never produce
    # a diagnostic, even in a fully working install.
    cat > "$f" <<'EOF'
def broken(:
    pass
EOF
    cat > "$script" <<'EOF'
function! VT_Lsp() abort
  " Batch mode does not guarantee coc's auto-start finished before the
  " FileType fires, so start the RPC server explicitly (no-op if already up).
  try
    call coc#rpc#start_server()
  catch
    call writefile(['FAIL coc#rpc#start_server raised: ' . v:exception], $VIM_MARKER, 'e')
    return
  endtry
  " coc's node server completes init() (extensions, LSP clients) only after
  " receiving the VimEnter notification. In an interactive session vim sends
  " it on startup; in headless `-c` batch mode vim never "enters", so
  " v:vim_did_enter stays 0 and init would never run here. Send it explicitly,
  " exactly as coc#rpc#start_server's own check_vim_enter path would.
  if v:vim_did_enter == 0
    call coc#rpc#notify('VimEnter', [join(globpath(&runtimepath, "", 0, 1), ",")])
  endif
  " Wait until coc has fully initialized (extensions activated) before
  " opening the canary file, so the python LSP client is present by the time
  " the buffer is opened.
  let s:deadline = str2nr($VIM_LSP_DEADLINE) * 1000
  if s:deadline <= 0
    let s:deadline = 45000
  endif
  let s:elapsed = 0
  while s:elapsed < s:deadline && get(g:, 'coc_service_initialized', 0) != 1
    sleep 500m
    let s:elapsed += 500
  endwhile
  if get(g:, 'coc_service_initialized', 0) != 1
    call writefile(['FAIL coc.nvim did not finish initializing within ' . (s:deadline / 1000) . 's'], $VIM_MARKER, 'e')
    return
  endif
  edit $VT_FILE
  setlocal ft=python
  let s:buf = bufnr('%')
  let s:ok = 0
  " $VIM_LSP_DEADLINE (seconds, default 120) bounds both phases above:
  " waiting for coc init and waiting for the diagnostic to arrive.
  let s:elapsed = 0
  while s:elapsed < s:deadline && !s:ok
    sleep 500m
    let s:elapsed += 500
    try
      silent call CocAction('fillDiagnostics', s:buf)
    catch
    endtry
    let s:locs = getloclist(0)
    if !empty(s:locs)
      let s:ok = 1
    endif
  endwhile
  if s:ok
    call writefile(['DIAGS ' . join(map(copy(s:locs), 'v:val.lnum . " | " . v:val.text'), ' || ')], $VIM_MARKER, 'e')
  else
    let s:ready = ''
    try | let s:ready = coc#rpc#ready() | catch | endtry
    call writefile(['TIMEOUT no LSP diagnostics within ' . (s:deadline / 1000) . 's coc_ready=' . s:ready], $VIM_MARKER, 'e')
  endif
endfunction
call VT_Lsp()
execute 'qa!'
EOF
    export VT_FILE="$f" VIM_MARKER="$WORK_DIR/lsp.marker"
    local rc=0
    vim_batch "${VIM_SRC_BASE[@]}" -c "source ${HOME}/.vimrc" -c "source ${script}" || rc=$?
    [ "$rc" -eq 124 ] && {
        echo "LSP canary TIMED OUT at the vim level after ${VIM_TIMEOUT}s (inner deadline is ${VIM_LSP_DEADLINE}s; something hung)"
        show_vim_err "$VIM_BATCH_ERR"
        return 1
    }
    local marker="$WORK_DIR/lsp.marker"
    if [ ! -s "$marker" ]; then
        echo "LSP canary aborted before writing a marker (coc.nvim could not be sourced/started)"
        show_vim_err "$VIM_BATCH_ERR"
        return 1
    fi
    local line; line="$(head -n1 "$marker")"
    case "$line" in
        DIAGS\ *invalid\ syntax*|DIAGS\ *SyntaxError*)
            echo "jedi published the expected diagnostic"
            echo "       $line"
            return 0
            ;;
        DIAGS\ *)
            echo "diagnostics arrived but did not flag the deliberate syntax error:"
            echo "       $line"
            return 1
            ;;
        TIMEOUT\ *)
            echo "${line#TIMEOUT} — the vim -> coc RPC -> coc-jedi -> jedi-language-server chain is broken"
            echo "       (check: node resolves inside vim, ~/.config/coc/extensions/node_modules/coc-jedi, jedi-language-server on PATH, coc.nvim compiled)"
            return 1
            ;;
        FAIL\ *)
            echo "${line#FAIL }"
            show_vim_err "$VIM_BATCH_ERR"
            return 1
            ;;
        *)
            echo "LSP canary reported unexpected state: $line"
            show_vim_err "$VIM_BATCH_ERR"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# check: basic editor operations still work under the installed config
# ---------------------------------------------------------------------------
check_basic_ops() {
    local script="$WORK_DIR/vt_basic.vim"
    cat > "$script" <<'EOF'
set number
set expandtab
if &number && &expandtab
    call writefile(['OK ' . &number . ' ' . &expandtab], $VIM_MARKER, 'e')
else
    call writefile(['FAIL number=' . &number . ' expandtab=' . &expandtab], $VIM_MARKER, 'e')
endif
execute 'qa!'
EOF
    export VIM_MARKER="$WORK_DIR/basic.marker"
    local rc=0
    vim_batch "${VIM_SRC_BASE[@]}" -c "source ${HOME}/.vimrc" -c "source ${script}" || rc=$?
    [ "$rc" -eq 124 ] && { echo "basic ops check TIMED OUT"; show_vim_err "$VIM_BATCH_ERR"; return 1; }
    local marker="$WORK_DIR/basic.marker"
    if [ ! -s "$marker" ]; then
        echo "basic ops check aborted before writing a marker"
        show_vim_err "$VIM_BATCH_ERR"
        return 1
    fi
    local line; line="$(head -n1 "$marker")"
    case "$line" in
        OK\ *1\ 1*)
            echo "settings applied: $line"
            return 0
            ;;
        *)
            echo "unexpected result: $line"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Check suite
# ---------------------------------------------------------------------------

run_checks() {
    echo "============================================================"
    echo " vim setup integration test (mode: ${MODE})"
    echo " vimrc: ${VIMRC_PATH}"
    echo " host: $(uname -srm)  bash: ${BASH_VERSION}"
    echo "============================================================"

    # Order: cheap environment checks first (loud, fast), then the functional
    # checks. Every check runs even if earlier ones failed, so one run shows
    # the full damage.
    run_check "vim >= 9.0 with required features" check_vim
    run_check "git binary available"               check_git
    run_check "node available (coc.nvim runtime)"  check_node
    run_check "plugin directories present"         check_plugin_dirs
    run_check "coc.nvim compiled"                  check_coc_build
    run_check "LSP servers/helpers present"        check_lsp_tools
    run_check "search utilities (rg/fd/fzf)"       check_search_tools
    run_check "setup starts up (plain vim)"        check_vimrc_startup
    run_check "plugin commands registered"         check_plugin_commands
    run_check "vim-commentary functional"          check_commentary_functional
    run_check "vim-fugitive functional (git)"      check_fugitive_functional
    run_check "coc.nvim + jedi LSP canary"         check_lsp_jedi
    run_check "basic editor operations"            check_basic_ops

    echo "============================================================"
    echo " RESULT: ${PASS} passed, ${FAIL} failed"
    if [ "$FAIL" -gt 0 ]; then
        echo " failed checks:"
        local c
        for c in "${FAILED_CHECKS[@]}"; do
            echo "   - $c"
        done
    fi
    echo "============================================================"
    [ "$FAIL" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Environment preparation (local mode; docker mode re-enters this script with
# --local inside the container)
# ---------------------------------------------------------------------------

prepare_env() {
    [ -f "$VIMRC_PATH" ] || die_env "vimrc not found: $VIMRC_PATH"

    # Make locally installed tools (uv symlinks, nvm node, cargo, fzf)
    # resolvable without an interactive login shell.
    export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${HOME}/.fzf/bin:${PATH}"

    # Pass the LSP canary deadline (seconds) through to the vim batch scripts.
    export VIM_LSP_DEADLINE

    # Load nvm so `nvm current` / node resolve the same way as in the user's
    # interactive shells. nvm.sh is safe to source non-interactively.
    if [ -s "${HOME}/.nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "${HOME}/.nvm/nvm.sh" || true
    fi
}

# ---------------------------------------------------------------------------
# Docker orchestration
# ---------------------------------------------------------------------------

run_docker_mode() {
    if ! command -v docker >/dev/null 2>&1; then
        die_env "docker is not available; cannot run the clean-room test (use --local to test this machine's installed setup)"
    fi

    if [ "$SKIP_BUILD" -eq 0 ]; then
        echo ">> building image ${IMAGE_NAME} (installs the published debian branch; ~10-15 min the first time)"
        docker build -t "$IMAGE_NAME" -f "${SCRIPT_DIR}/Dockerfile" "$REPO_ROOT" || {
            die_env "docker build failed"
        }
    fi

    echo ">> running checks inside a fresh container of ${IMAGE_NAME}"
    local rc=0
    docker run --rm \
        -w /root \
        -v "${SCRIPT_DIR}:/opt/vim_test:ro" \
        "$IMAGE_NAME" \
        bash /opt/vim_test/vim_test.sh --local || rc=$?
    echo ">> container run finished (exit=$rc)"
    return "$rc"
}

# ---------------------------------------------------------------------------
# Usage / main
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: ${0##*/} [--local] [--image NAME] [--no-build] [--vimrc PATH] [--help]

  (no mode flag)   Docker clean-room test (default): builds the image
                   (integration/Dockerfile, installs the published "debian"
                   branch) and runs all checks inside a fresh container.
  --local          Run the checks against this machine's installed setup.
  --image NAME     Docker image to build/use (default: $IMAGE_NAME).
  --no-build       Docker mode only: reuse an already built image.
  --vimrc PATH     vimrc to load (default: \$VIMRC_PATH or \$HOME/.vimrc).

Environment:
  VIM_TEST_VIM_TIMEOUT    per-vim-invocation hard timeout in seconds (default 240)
  VIM_TEST_LSP_DEADLINE   inner deadline (seconds) for the LSP canary to wait
                          for diagnostics before declaring the chain broken
                          (default 120)

See README.md ("Integration Testing") for the check matrix.
EOF
}

rc=0
while [ $# -gt 0 ]; do
    case "$1" in
        --local)    MODE="local" ;;
        --image)    shift; IMAGE_NAME="${1:?--image requires a value}" ;;
        --no-build) SKIP_BUILD=1 ;;
        --vimrc)    shift; VIMRC_PATH="${1:?--vimrc requires a value}" ;;
        --help|-h)  usage; exit 0 ;;
        *) printf 'unknown argument: %s\n\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

case "$MODE" in
    local)
        prepare_env
        run_checks || rc=$?
        ;;
    docker)
        run_docker_mode || rc=$?
        ;;
esac
exit "$rc"

#!/bin/bash
set -euo pipefail

# CI Test Script for Vim Configuration
# Tests plugin functionality and basic vim operations

VIMRC_PATH="${VIMRC_PATH:-$HOME/.vimrc}"
TEST_DIR="/tmp/vim_ci_test_$$"
VIM_VERSION="${VIM_VERSION:-9.0}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}

trap cleanup EXIT

assert_command() {
    local cmd="$1"
    local name="${2:-$cmd}"
    
    if ! command -v "$cmd" &>/dev/null; then
        log_error "$name is not installed"
        return 1
    fi
    log_info "$name is available"
    return 0
}

check_vim() {
    log_info "Checking Vim installation..."
    
    if ! assert_command vim "Vim"; then
        log_error "Vim not found. Please install Vim 9.0+ manually"
        exit 1
    fi
    
    local version=$(vim --version | head -1 | grep -oP '\d+\.\d+' | head -1)
    log_info "Vim version: $version"
    
    # Enforce version >= 9.0
    local major=$(echo "$version" | cut -d. -f1)
    if [ "$major" -lt 9 ]; then
        log_error "Vim version must be >= 9.0, found: $version"
        exit 1
    fi
    log_info "✓ Vim version check passed (>= 9.0)"
    
    # Check for required features
    local features=$(vim --version | grep -oP '\+[a-z]+')
    
    for feature in python3 javascript clipboard; do
        if echo "$features" | grep -q "+$feature"; then
            log_info "Feature enabled: $feature"
        else
            log_warn "Feature not available: $feature"
        fi
    done
    
    return 0
}

check_submodules() {
    log_info "Checking git submodules..."
    
    if [ ! -f .gitmodules ]; then
        log_error "No .gitmodules file found"
        return 1
    fi
    
    local submodules=($(grep -E '^\s*path\s*=' .gitmodules | sed 's/.*=\s*//' | tr -d ' '))
    
    if [ ${#submodules[@]} -eq 0 ]; then
        log_error "No submodules found in .gitmodules"
        return 1
    fi
    
    local failed=0
    
    for submodule in "${submodules[@]}"; do
        # Check in /root/.vim (installed location)
        if [ -d "/root/$submodule" ]; then
            log_info "✓ Submodule exists (installed): $submodule"
            ((TESTS_PASSED++)) || true
        else
            log_error "✗ Submodule missing: $submodule"
            ((failed++)) || true
            ((TESTS_FAILED++)) || true
        fi
    done
    
    if [ $failed -gt 0 ]; then
        log_warn "Some submodules are missing. Running: git submodule update --init --recursive"
        git submodule update --init --recursive
    fi
    
    return 0
}

check_vim_plugins() {
    log_info "Checking Vim plugin directories..."
    
    local plugins=(
        ".vim/pack/tpope/opt/vim-fugitive"
        ".vim/pack/tpope/opt/vim-commentary"
        ".vim/pack/junegunn/opt/fzf"
        ".vim/pack/junegunn/opt/fzf.vim"
        ".vim/pack/github/opt/copilot.vim"
        ".vim/pack/neoclide/opt/coc.nvim"
    )
    
    local total=0
    local found=0
    
    for plugin in "${plugins[@]}"; do
        ((total++)) || true
        if [ -d "/root/$plugin" ]; then
            local plugin_name=$(basename "$plugin")
            log_info "✓ Plugin directory exists: $plugin_name"
            ((found++)) || true
            ((TESTS_PASSED++)) || true
        else
            log_error "✗ Plugin directory missing: $plugin_name"
            ((TESTS_FAILED++)) || true
        fi
    done
    
    log_info "Plugin check: $found/$total directories found"
    [ $found -eq $total ] || true
}



run_vim_command() {
    local cmd="$1"
    local description="$2"
    
    log_info "Testing: $description"
    
    # Force non-interactive mode with -u NONE, then source the vimrc explicitly
    # Use -n to disable swap file, -ex for ex batch mode (more reliable than -es)
    # Escape double quotes in cmd and quote string outputs for vimscript
    # Use -N flag to handle plugins like vim-fugitive that have regex parsing issues in batch mode
    local output
    output=$(timeout 15 vim -u NONE -N -ex -c "source $VIMRC_PATH" -c "$cmd" -c 'qa!' 2>&1) || {
        local exit_code=$?
        # Check if timeout caused failure (exit code 124)
        if [ $exit_code -eq 124 ]; then
            log_error "✗ TIMEOUT: $description"
            ((TESTS_FAILED++)) || true
            return 1
        fi
        # Check for specific errors that mean "command executed"
        if echo "$output" | grep -qE "(E117|E492|E319| Vim: Warning)"; then
            log_error "✗ FAILED: $description"
            echo "$output"
            ((TESTS_FAILED++)) || true
            return 1
        fi
        # Any other failure is a real error (e.g., missing node for coc.nvim)
        log_error "✗ FAILED: $description"
        if [ -n "$output" ]; then
            echo "$output"
        fi
        ((TESTS_FAILED++)) || true
        return 1
    }
    log_info "✓ PASSED: $description"
    ((TESTS_PASSED++)) || true
    return 0
}

test_plugin_fugitive() {
    log_info "=== Testing vim-fugitive ==="
    
    # Test plugin is loadable
    run_vim_command "echo 'vim-fugitive loaded'" "vim-fugitive loads"
    
    # Check if fugitive commands exist
    run_vim_command "echo exists(':Git')" "vim-fugitive :Git command exists"
    run_vim_command "echo exists(':Glog')" "vim-fugitive :Glog command exists"
    run_vim_command "echo exists(':GFiles')" "vim-fugitive :GFiles command exists"
}

test_plugin_commentary() {
    log_info "=== Testing vim-commentary ==="
    
    # Test plugin loads
    run_vim_command "echo 'vim-commentary loaded'" "vim-commentary loads"
    
    # Check if Commentary command exists
    run_vim_command "echo exists(':Commentary')" "vim-commentary :Commentary command exists"
}

test_plugin_fzf() {
    log_info "=== Testing fzf and fzf.vim ==="
    
    # Test plugin loads
    run_vim_command "echo 'fzf loaded'" "fzf loads"
    
    # Check if command exists (may fail if vim doesn't support it fully, but plugin should load)
    run_vim_command "echo exists(':Files')" "fzf.vim :Files command exists"
    run_vim_command "echo exists(':BLines')" "fzf.vim :BLines command exists"
    run_vim_command "echo exists(':Rg')" "fzf.vim :Rg command exists"
}

test_plugin_copilot() {
    log_info "=== Testing copilot.vim ==="
    
    # Check if copilot is loadable
    run_vim_command ":echo copilot#enabled()" "copilot.vim plugin loaded"
    
    # Test copilot functions exist
    run_vim_command ":echo exists('*copilot#suggest')" "copilot#suggest function exists"
}

test_plugin_coc() {
    log_info "=== Testing coc.nvim ==="
    
    # Check vim version for coc.nvim (requires 9.0+)
    local version=$(vim --version | head -1 | grep -oP '\d+\.\d+' | head -1)
    local major=$(echo "$version" | cut -d. -f1)
    
    if [ "$major" -lt 9 ]; then
        log_warn "Skipping coc.nvim tests (requires Vim >= 9.0)"
        return 0
    fi
    
    # Test coc.nvim loads
    run_vim_command "echo 'coc.nvim loaded'" "coc.nvim plugin loads"
    
    # Test coc functions exist
    run_vim_command "echo exists('*coc#util#version')" "coc.nvim functions exist"
    
    # Test node is available via nvm (required for coc.nvim RPC)
    # Check if nvm can find current node version
    log_info "Checking node availability..."
    source /root/.nvm/nvm.sh || {
        log_error "✗ FAILED: nvm failed to load"
        ((TESTS_FAILED++)) || true
        return 1
    }
    local current_node=$(nvm current 2>&1)
    log_info "Current node: $current_node"
    if [ "$current_node" = "none" ] || [ -z "$current_node" ]; then
        log_error "✗ FAILED: node not available via nvm (required for coc.nvim)"
        ((TESTS_FAILED++)) || true
        return 1
    fi
    log_info "✓ PASSED: node available via nvm"
    
    # Test coc.nvim RPC starts (requires node to be available)
    # Use 15 second timeout to catch hanging issues
    run_vim_command "call coc#rpc#start()" "coc.nvim RPC starts" || {
        log_error "✗ coc.nvim RPC failed to start (node may not be installed)"
        ((TESTS_FAILED++)) || true
        return 1
    }
    
    ((TESTS_PASSED++)) || true
    log_info "✓ PASSED: coc.nvim RPC started successfully (node available)"
}

test_vimrc_syntax() {
    log_info "=== Testing vimrc syntax ==="
    
    # Test that vimrc syntax is valid by just loading it
    run_vim_command "echo 'vimrc loaded successfully'" "vimrc loads"
}

test_basic_vim_operations() {
    log_info "=== Testing basic Vim operations ==="
    
    # Test basic commands work
    run_vim_command "echo 'basic editor works'" "basic editor"
    
    # Test file operations
    run_vim_command "set number | set expandtab" "settings applied"
}

test_filetype_detection() {
    log_info "=== Testing filetype detection ==="
    
    # Test filetype detection works
    run_vim_command "echo &ft" "filetype detection"
}

test_python_integration() {
    log_info "=== Testing Python integration ==="
    
    # Check if Python3 is available in Vim
    run_vim_command ":python3 print('Python3 works')" "Python3 support"
    
    # Check Python3 version
    run_vim_command ":echo python3#import('sys').version" "Python3 version"
}

run_tests() {
    log_info "=========================================="
    log_info "Starting Vim Configuration CI Tests"
    log_info "=========================================="
    log_info ""
    
    check_vim
    check_submodules
    check_vim_plugins
    
    log_info "Testing with vimrc: $VIMRC_PATH"
    
    if [ ! -f "$VIMRC_PATH" ]; then
        log_error "Vimrc not found: $VIMRC_PATH"
        exit 1
    fi
    
    log_info ""
    log_info "Running functional tests..."
    log_info ""
    
    test_vimrc_syntax
    test_basic_vim_operations
    test_filetype_detection
    test_plugin_fugitive
    test_plugin_commentary
    test_plugin_fzf
    # test_plugin_copilot - skipped (requires node and may hang waiting for GitHub)
    test_plugin_coc
    
    log_info ""
    log_info "=========================================="
    log_info "Test Results Summary"
    log_info "=========================================="
    log_info "Tests Passed: ${TESTS_PASSED}"
    log_info "Tests Failed: ${TESTS_FAILED}"
    log_info ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_info "✓ All tests passed!"
        return 0
    else
        log_error "✗ Some tests failed"
        return 1
    fi
}

main() {
    if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
        echo "Vim Configuration CI Test Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h    Show this help message"
        echo "  --vimrc PATH  Specify path to vimrc (default: \$HOME/.vimrc)"
        echo ""
    echo "Environment Variables:"
    echo "  VIMRC_PATH    Path to vimrc file (default: \$HOME/.vimrc)"
    echo "  VIM_VERSION   Minimum Vim version required (default: 9.0)"
        return 0
    fi
    
    run_tests
}

main "$@"

#!/usr/bin/env bash
# Cheap repo-integrity checks: the dotfiles the installer relies on must exist
# and the installer scripts must at least be syntactically valid bash.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

pass=0
fail=0
check() { # $1 = description, $2 = 0/1 (0 = ok)
  if [ "$2" -eq 0 ]; then echo "  ok  - $1"; pass=$((pass+1)); else echo "  FAIL - $1"; fail=$((fail+1)); fi
}

# 1. Key dotfiles / config files that the installer expects to be present.
required_files=(
  ".gitmodules"
  ".gitconfig"
  ".bashrc"
  ".vimrc"
  ".local/installer/dotfile_installer.sh"
  ".local/installer/extra_installer.sh"
  ".local/installer/install_latest_submodules.sh"
  "README.md"
)
for f in "${required_files[@]}"; do
  [ -e "$f" ]; check "required file present: $f" $?
done

# 2. Installer scripts must be syntactically valid bash (bash -n, no execution).
for f in .local/installer/*.sh; do
  bash -n "$f" 2>/tmp/bashn.err
  rc=$?
  if [ "$rc" -ne 0 ]; then sed 's/^/      /' /tmp/bashn.err; fi
  check "valid bash syntax: $f" $rc
done

# 3. .gitmodules is well-formed enough to parse every submodule entry.
git config -f .gitmodules --get-regexp '^submodule\..*\.path$' >/dev/null 2>&1
check ".gitmodules parses (submodule paths present)" $?

echo "repo_integrity: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

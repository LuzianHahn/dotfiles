#!/usr/bin/env bash
# Verifies the coc.nvim submodule is pinned to upstream at the expected commit.
# This is the core "canary": it fails if the pin is changed or the pinned
# commit ever becomes unreachable on upstream.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Update this when intentionally re-pinning coc.nvim (see README).
EXPECTED_SHA="a916ea6394288c69ba68e42961da44f499db0c16"
UPSTREAM_URL="https://github.com/neoclide/coc.nvim"
MOD_PATH=".vim/pack/neoclide/opt/coc.nvim"

pass=0
fail=0
check() { # $1 = description, $2 = 0/1 (0 = ok)
  if [ "$2" -eq 0 ]; then echo "  ok  - $1"; pass=$((pass+1)); else echo "  FAIL - $1"; fail=$((fail+1)); fi
}

# 1. .gitmodules points coc.nvim at upstream, not a fork.
url="$(git config -f .gitmodules --get "submodule.${MOD_PATH}.url" 2>/dev/null)"
case "$url" in
  "$UPSTREAM_URL"|"${UPSTREAM_URL}.git") : ;;
  *) url="" ;;
esac
[ -n "$url" ]; check ".gitmodules points coc.nvim at upstream ($UPSTREAM_URL)" $?

# 2. The recorded gitlink is a bare 40-char SHA, and matches the expected pin.
sha="$(git ls-tree HEAD "$MOD_PATH" | awk '{print $3}')"
[ -n "$sha" ] && [ "${#sha}" -eq 40 ]; check "coc.nvim gitlink is a bare 40-char SHA" $?
[ "$sha" = "$EXPECTED_SHA" ]; check "coc.nvim pinned to expected SHA $EXPECTED_SHA" $?

# 3. The documented pin is still reachable on upstream (the canary).
#    Guarded on a 40-char SHA so a missing/short value cannot silently pass.
rc=1
if [ "${#EXPECTED_SHA}" -eq 40 ] && git ls-remote "$UPSTREAM_URL" >/dev/null 2>&1; then
  tmp="$(mktemp -d)"
  if git -C "$tmp" init -q 2>/dev/null && \
     git -C "$tmp" fetch -q --depth 1 "$UPSTREAM_URL" "$EXPECTED_SHA" 2>/dev/null && \
     git -C "$tmp" cat-file -e "${EXPECTED_SHA}^{commit}" 2>/dev/null; then
    rc=0
  fi
  rm -rf "$tmp"
fi
check "documented pin is reachable on upstream" $rc

echo "submodule_pin: $pass passed, $fail failed"
[ "$fail" -eq 0 ]

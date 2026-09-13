#!/usr/bin/env bash
# Runs every test_*.sh in this directory and exits non-zero if any fail.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")"

overall=0
for t in test_*.sh; do
  [ -e "$t" ] || continue
  echo "== $t =="
  if bash "$t"; then
    echo "-- passed"
  else
    echo "-- FAILED"
    overall=1
  fi
  echo
done

if [ "$overall" -eq 0 ]; then
  echo "ALL TESTS PASSED"
else
  echo "SOME TESTS FAILED"
fi
exit "$overall"

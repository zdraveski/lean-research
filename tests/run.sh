#!/bin/bash
# Runs every tests/test_*.sh with the bash that runs this script.
cd "$(dirname "$0")" || exit 1
rc=0
for t in test_*.sh; do
  if "$BASH" "$t"; then echo "PASS $t"; else echo "FAIL $t"; rc=1; fi
done
exit $rc

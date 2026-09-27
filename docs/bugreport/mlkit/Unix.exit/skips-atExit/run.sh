#!/bin/sh
# build and run bug.sml, then show the two files it should have written
MLKIT=${MLKIT:-mlkit}
cd "$(dirname "$0")" || exit 1
rm -f flushed.txt atexit.txt
"$MLKIT" -o bug bug.mlb > /dev/null && ./bug
echo "exit status $?"
echo "flushed.txt: [$(cat flushed.txt 2>/dev/null)]"
echo "atexit.txt: [$(cat atexit.txt 2>/dev/null)]"

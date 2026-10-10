#!/bin/sh
# lib/zmtp against a peer written from the specification in Python
# (tests/lib/zmtp/interop/peer.py), on the loopback interface: the server
# of interop/server.sml, compiled with RUNE and run on RUNEVM, and the peer
# at once. run-lib-tests.sh runs it after the library's tests.
#   tests/lib/zmtp/interop.sh RUNE RUNEVM OUT
set -u
rune=$1 runevm=$2 out=$3
command -v python3 > /dev/null || { echo "zmtp interop: skipped, no python3"; exit 0; }
"$rune" --library zmtp tests/lib/zmtp/interop/server.sml -o "$out/zmtp-server.rbc" || exit 1
rm -f "$out/zmtp-ports"
timeout 60 "$runevm" "$out/zmtp-server.rbc" "$out/zmtp-ports" > "$out/zmtp-server.out" 2>&1 &
server=$!
timeout 60 python3 tests/lib/zmtp/interop/peer.py "$out/zmtp-ports"
peer=$?
wait $server
status=$?
cat "$out/zmtp-server.out"
[ $peer -eq 0 ] && [ $status -eq 0 ] && grep -q '^server: done' "$out/zmtp-server.out"

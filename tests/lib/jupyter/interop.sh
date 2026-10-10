#!/bin/sh
# lib/jupyter against a client written from Jupyter's messaging
# specification in Python (tests/lib/jupyter/interop/client.py): the echo
# kernel of interop/kernel.sml, compiled with RUNE and run on RUNEVM, at
# ports the script picks. run-lib-tests.sh runs it after the library's
# tests. (jupyter_client itself, where it is installed, is M11's.)
#   tests/lib/jupyter/interop.sh RUNE RUNEVM OUT
set -u
rune=$1 runevm=$2 out=$3
command -v python3 > /dev/null || { echo "jupyter interop: skipped, no python3"; exit 0; }
"$rune" --library jupyter tests/lib/jupyter/interop/kernel.sml -o "$out/jupyter-kernel.rbc" || exit 1
python3 - "$out/jupyter-connection.json" <<'PY'
import json, socket, sys
ports = []
for _ in range(5):
    s = socket.socket(); s.bind(("127.0.0.1", 0)); ports.append(s.getsockname()[1]); s.close()
json.dump({"shell_port": ports[0], "iopub_port": ports[1], "stdin_port": ports[2], "control_port": ports[3],
           "hb_port": ports[4], "ip": "127.0.0.1", "key": "a-secret-key", "transport": "tcp",
           "signature_scheme": "hmac-sha256", "kernel_name": "echo"}, open(sys.argv[1], "w"))
PY
timeout 60 "$runevm" "$out/jupyter-kernel.rbc" "$out/jupyter-connection.json" > "$out/jupyter-kernel.out" 2>&1 &
kernel=$!
sleep 1
timeout 60 python3 tests/lib/jupyter/interop/client.py "$out/jupyter-connection.json"
client=$?
wait $kernel
status=$?
cat "$out/jupyter-kernel.out"
[ $client -eq 0 ] && [ $status -eq 0 ] && grep -q '^kernel: done' "$out/jupyter-kernel.out"

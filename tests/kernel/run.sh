#!/bin/sh
# rune-kernel (docs/kernel.md; docs/plans/repl.md, M11) driven by a client
# written from Jupyter's messaging specification with Python's standard
# library (tests/kernel/client.py, on the ZMTP peer of tests/lib/zmtp), at
# ports this script picks: what a notebook asks of a kernel, an interrupt
# among it. jupyter_client itself is tested where it is installed
# (tests/kernel/notebook_client.py).
#   tests/kernel/run.sh
set -u
cd "$(dirname "$0")/../.."
command -v python3 > /dev/null || { echo "kernel: skipped, no python3"; exit 0; }
out=tests/out/kernel
mkdir -p "$out"
python3 - "$out/connection.json" <<'PY'
import json, socket, sys
ports = []
socks = []
for _ in range(5):
    s = socket.socket(); s.bind(("127.0.0.1", 0)); ports.append(s.getsockname()[1]); socks.append(s)
for s in socks: s.close()
json.dump({"shell_port": ports[0], "iopub_port": ports[1], "stdin_port": ports[2], "control_port": ports[3],
           "hb_port": ports[4], "ip": "127.0.0.1", "key": "a-kernel-key", "transport": "tcp",
           "signature_scheme": "hmac-sha256", "kernel_name": "rune"}, open(sys.argv[1], "w"))
PY
RUNE_CACHE= timeout 300 bin/rune-kernel "$out/connection.json" > "$out/kernel.out" 2>&1 &
kernel=$!
sleep 1
timeout 240 python3 tests/kernel/client.py "$out/connection.json" "$kernel"
client=$?
wait $kernel
status=$?
[ $client -eq 0 ] && [ $status -eq 0 ] || { echo "the kernel's output:"; cat "$out/kernel.out"; }
fail=0
[ $client -eq 0 ] && [ $status -eq 0 ] || fail=1
if python3 -c 'import jupyter_client' 2> /dev/null; then
  timeout 240 python3 tests/kernel/notebook_client.py || fail=1
else
  echo "kernel: jupyter_client is not installed; its test skipped"
fi
echo "kernel: $([ $fail = 0 ] && echo passed || echo FAILED)"
[ $fail = 0 ]

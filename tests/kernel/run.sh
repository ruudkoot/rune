#!/bin/sh
# rune-kernel (docs/kernel.md; docs/plans/repl.md, M11) driven by a client
# written from Jupyter's messaging specification with Python's standard
# library (tests/kernel/client.py, on the ZMTP peer of tests/lib/zmtp), at
# ports this script picks: what a notebook asks of a kernel, an interrupt
# among it. jupyter_client itself is tested where it is installed
# (tests/kernel/notebook_client.py).
#   tests/kernel/run.sh [--windows]
# With --windows, the kernel and its engine are runevm.exe's, staged in the
# directory tests/windows-dir.sh names, and a Python of Windows drives them
# (tests/kernel/windows.py), interrupting by JPY_INTERRUPT_EVENT.
set -u
cd "$(dirname "$0")/../.."
if [ "${1:-}" = --windows ]; then
  if ! python.exe -c 'import ctypes' > /dev/null 2>&1; then
    echo "kernel (Windows): skipped, no Python of Windows (python.exe)"
    exit 0
  fi
  if ! windir=$(sh tests/windows-dir.sh); then
    echo "kernel (Windows): no Windows to run on (tests/windows-dir.sh)" >&2
    exit 1
  fi
  stage=$windir/kernel
  mkdir -p "$stage/bin" "$stage/tests/kernel" "$stage/tests/lib/zmtp/interop"
  cp bin/runevm.exe bin/rune-repl.img bin/rune-kernel.rbc "$stage/bin/"
  for dll in bin/*.dll; do [ -f "$dll" ] && cp "$dll" "$stage/bin/"; done
  cp tests/kernel/client.py tests/kernel/windows.py "$stage/tests/kernel/"
  cp tests/lib/zmtp/interop/peer.py "$stage/tests/lib/zmtp/interop/"
  if (cd "$stage" && timeout 300 python.exe -u tests/kernel/windows.py); then
    echo "kernel (Windows): passed"
  else
    echo "kernel (Windows): FAILED"
    exit 1
  fi
  exit 0
fi
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

#!/usr/bin/env python3
"""rune-kernel on Windows (tests/kernel/run.sh --windows), run by a Python of
Windows in the directory the files were staged in: bin/ holds runevm.exe,
the REPL's image and the kernel's program. The kernel is started as
jupyter_client starts one there -- an inheritable event named by
JPY_INTERRUPT_EVENT, which an interrupt sets -- at ports picked here, and
tests/kernel/client.py drives it, inheriting the event.

  windows.py"""
import ctypes
import ctypes.wintypes
import json
import os
import socket
import subprocess
import sys

here = os.path.dirname(os.path.abspath(__file__))
stage = os.path.dirname(os.path.dirname(here))
bin_ = os.path.join(stage, "bin")


class SecurityAttributes(ctypes.Structure):
    _fields_ = [("nLength", ctypes.wintypes.DWORD), ("lpSecurityDescriptor", ctypes.c_void_p),
                ("bInheritHandle", ctypes.wintypes.BOOL)]


kernel32 = ctypes.windll.kernel32
kernel32.CreateEventA.restype = ctypes.wintypes.HANDLE
inherit = SecurityAttributes(ctypes.sizeof(SecurityAttributes), None, True)
event = kernel32.CreateEventA(ctypes.byref(inherit), False, False, None)
ports, socks = [], []
for _ in range(5):
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    ports.append(s.getsockname()[1])
    socks.append(s)
for s in socks:
    s.close()
connection = os.path.join(stage, "connection.json")
json.dump({"shell_port": ports[0], "iopub_port": ports[1], "stdin_port": ports[2], "control_port": ports[3],
           "hb_port": ports[4], "ip": "127.0.0.1", "key": "a-kernel-key", "transport": "tcp",
           "signature_scheme": "hmac-sha256", "kernel_name": "rune"}, open(connection, "w"))
vm, program = os.path.join(bin_, "runevm.exe"), os.path.join(bin_, "rune-kernel.rbc")
with open(os.path.join(stage, "kernel.out"), "w") as out:
    kernel = subprocess.Popen([vm, program, "--vm", vm, "--image", os.path.join(bin_, "rune-repl.img"),
                               "--program", program, connection],
                              env=dict(os.environ, JPY_INTERRUPT_EVENT=str(event), RUNE_CACHE=""),
                              stdout=out, stderr=subprocess.STDOUT, close_fds=False)
    try:
        client = subprocess.call([sys.executable, os.path.join(here, "client.py"), connection, "event:%d" % event],
                                 close_fds=False, timeout=240)
    except subprocess.TimeoutExpired:
        client = "timed out"
    try:
        status = kernel.wait(timeout=60)
    except subprocess.TimeoutExpired:
        kernel.kill()
        status = "killed"
if client != 0 or status != 0:
    print("the client: %s, the kernel: %s; the kernel's output:" % (client, status))
    print(open(os.path.join(stage, "kernel.out")).read())
sys.exit(0 if client == 0 and status == 0 else 1)

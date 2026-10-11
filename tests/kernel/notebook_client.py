#!/usr/bin/env python3
"""rune-kernel under jupyter_client itself (docs/plans/repl.md, M11), where it
is installed: the kernelspec installed in a directory of the test's own and
found through JUPYTER_PATH, a kernel started as a notebook starts one, code
executed with its output collected, an interrupt by interrupt_kernel, and a
shutdown. tests/kernel/run.sh runs it after its own client. (Not named jupyter_client.py,
which would import itself.)"""
import os
import subprocess
import sys
import threading
import time

import jupyter_client

root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
prefix = os.path.join(root, "tests", "out", "kernel", "jupyter")
os.makedirs(prefix, exist_ok=True)
subprocess.check_call([os.path.join(root, "bin", "rune-kernel"), "--install", "--prefix", prefix])
os.environ["JUPYTER_PATH"] = os.path.join(prefix, "share", "jupyter")
os.environ["RUNE_CACHE"] = ""
ok = True


def check(name, cond, detail=""):
    global ok
    print(("PASS " if cond else "FAIL ") + "jupyter_client: " + name + ("" if cond else ": " + str(detail)))
    ok = ok and bool(cond)


km, kc = jupyter_client.manager.start_new_kernel(kernel_name="rune")
try:
    outputs = []
    reply = kc.execute_interactive("val x = 1 + 2", timeout=60, output_hook=outputs.append)
    results = [m["content"]["data"]["text/plain"] for m in outputs if m["msg_type"] == "execute_result"]
    check("execute", reply["content"]["status"] == "ok" and results == ["val x = 3 : int"], (reply, outputs))
    outputs = []
    kc.execute_interactive('print "hello\\n";', timeout=60, output_hook=outputs.append)
    streams = [m["content"]["text"] for m in outputs if m["msg_type"] == "stream"]
    check("a stream", "hello\n" in streams, outputs)
    threading.Timer(2.0, km.interrupt_kernel).start()
    reply = kc.execute_interactive("fun loop () : unit = loop (); loop ();", timeout=60, output_hook=lambda m: None)
    check("interrupt_kernel", reply["content"]["status"] == "error" and reply["content"]["ename"] == "Interrupt", reply)
    reply = kc.complete("List.fil", 8, reply=True, timeout=30)
    check("complete", "filter" in reply["content"]["matches"], reply)
finally:
    kc.stop_channels()
    km.shutdown_kernel(now=False)
    # gone before the interpreter ends, whose logging its __del__ uses
    del kc, km
sys.exit(0 if ok else 1)

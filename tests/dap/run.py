#!/usr/bin/env python3
"""rune-dap driven as an editor's debugger drives it (docs/dap.md;
docs/plans/repl.md, M12), with the standard library alone: the Debug
Adapter Protocol's messages framed by Content-Length on the adapter's
standard input and output.

  tests/dap/run.py

Two sessions: prog.sml stopped at a breakpoint -- its frames, scopes,
variables, an expression in its frame, a step --, at a raise its own
handler takes, and run to its end, its output given as events; and
loop.sml paused while it runs."""
import json
import os
import select
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ok = True


def check(name, cond, detail=""):
    global ok
    print(("PASS " if cond else "FAIL ") + name + ("" if cond or not detail else ": " + str(detail)))
    ok = ok and bool(cond)


class Adapter:
    def __init__(self):
        self.p = subprocess.Popen(["bin/rune-dap"], cwd=ROOT, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE)
        self.seq = 0
        self.buf = b""
        self.seen = []

    def send(self, command, arguments=None):
        self.seq += 1
        m = {"seq": self.seq, "type": "request", "command": command}
        if arguments is not None:
            m["arguments"] = arguments
        body = json.dumps(m).encode()
        self.p.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
        self.p.stdin.flush()
        return self.seq

    def message(self, deadline):
        while True:
            i = self.buf.find(b"\r\n\r\n")
            if i >= 0:
                n = int(self.buf[:i].split(b":")[1])
                if len(self.buf) >= i + 4 + n:
                    m = json.loads(self.buf[i + 4:i + 4 + n])
                    self.buf = self.buf[i + 4 + n:]
                    return m
            left = deadline - time.monotonic()
            if left <= 0:
                raise RuntimeError("no message in time")
            r, _, _ = select.select([self.p.stdout], [], [], left)
            if r:
                data = os.read(self.p.stdout.fileno(), 65536)
                if not data:
                    raise RuntimeError("the adapter ended")
                self.buf += data

    def until(self, pred, seconds=60):
        deadline = time.monotonic() + seconds
        while True:
            m = self.message(deadline)
            self.seen.append(m)
            if pred(m):
                return m

    def response(self, seq, seconds=60):
        return self.until(lambda m: m.get("type") == "response" and m.get("request_seq") == seq, seconds)

    def event(self, name, seconds=60):
        return self.until(lambda m: m.get("type") == "event" and m.get("event") == name, seconds)

    def request(self, command, arguments=None):
        return self.response(self.send(command, arguments))

    def outputs(self):
        return "".join(m["body"]["output"] for m in self.seen
                       if m.get("type") == "event" and m.get("event") == "output" and m["body"]["category"] == "stdout")

    def end(self):
        try:
            self.request("disconnect", {})
        except RuntimeError:
            pass
        try:
            self.p.wait(timeout=30)
        except subprocess.TimeoutExpired:
            self.p.kill()


def frames(a):
    r = a.request("stackTrace", {"threadId": 1})
    return r["body"]["stackFrames"]


def variables(a, frame):
    r = a.request("scopes", {"frameId": frame})
    ref = r["body"]["scopes"][0]["variablesReference"]
    r = a.request("variables", {"variablesReference": ref})
    return {v["name"]: v["value"] for v in r["body"]["variables"]}


prog = "tests/dap/prog.sml"
a = Adapter()
r = a.request("initialize", {"adapterID": "rune", "linesStartAt1": True, "columnsStartAt1": True})
check("initialize", r["success"] and r["body"]["supportsConfigurationDoneRequest"], r)
a.event("initialized")
check("launch", a.request("launch", {"program": prog})["success"])
r = a.request("setBreakpoints", {"source": {"path": prog}, "breakpoints": [{"line": 3}]})
check("setBreakpoints", r["success"] and len(r["body"]["breakpoints"]) == 1, r)
check("setExceptionBreakpoints", a.request("setExceptionBreakpoints", {"filters": ["all"]})["success"])
check("configurationDone", a.request("configurationDone", {})["success"])
e = a.event("stopped")
check("stopped at the breakpoint", e["body"]["reason"] == "breakpoint", e)
r = a.request("threads", {})
check("threads", r["body"]["threads"] == [{"id": 1, "name": "main"}], r)
fs = frames(a)
check("stackTrace", fs[0]["name"] == "f" and fs[0]["line"] == 3 and fs[0]["source"]["path"] == prog, fs)
vs = variables(a, fs[0]["id"])
check("variables", vs == {"x": "20", "y": "21"}, vs)
r = a.request("evaluate", {"expression": "x + y * 10", "frameId": 0, "context": "repl"})
check("evaluate in the frame", r["success"] and r["body"]["result"] == "230", r)
r = a.request("evaluate", {"expression": "nothere + 1", "frameId": 0, "context": "repl"})
check("evaluate an error", not r["success"] and "nothere" in r.get("message", ""), r)
check("next", a.request("next", {"threadId": 1})["success"])
e = a.event("stopped")
fs = frames(a)
check("stopped at the next line", e["body"]["reason"] == "step" and fs[0]["line"] == 4, (e, fs))
vs = variables(a, 0)
check("its variables", vs == {"x": "20", "y": "21", "z": "42"}, vs)
check("continue", a.request("continue", {"threadId": 1})["success"])
e = a.event("stopped")
fs = frames(a)
check("stopped at a raise", e["body"]["reason"] == "exception" and fs[0]["name"] == "h"
      and "zero" in e["body"].get("text", ""), (e, fs))
check("continue again", a.request("continue", {"threadId": 1})["success"])
a.event("terminated")
check("the program's output", a.outputs() == "r = 63\ndone 4\n", repr(a.outputs()))
ex = [m for m in a.seen if m.get("event") == "exited"]
check("exited 0", ex and ex[0]["body"]["exitCode"] == 0, ex)
a.end()
check("the adapter ends", a.p.returncode == 0, a.p.returncode)

a = Adapter()
a.request("initialize", {"adapterID": "rune"})
a.request("launch", {"program": "tests/dap/loop.sml"})
a.request("configurationDone", {})
time.sleep(1.0)
check("pause", a.request("pause", {"threadId": 1})["success"])
e = a.event("stopped")
fs = frames(a)
check("paused in the loop", e["body"]["reason"] == "pause" and fs[0]["name"] == "loop", (e, fs))
vs = variables(a, 0)
check("the loop's variable", "n" in vs, vs)
a.end()
check("ended while stopped", a.p.returncode == 0, a.p.returncode)

print("dap: " + ("passed" if ok else "FAILED"))
sys.exit(0 if ok else 1)

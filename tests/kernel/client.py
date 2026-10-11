#!/usr/bin/env python3
"""The client of tests/kernel/run.sh: rune-kernel driven as a notebook drives
a kernel, with the standard library alone, on the ZMTP peer of tests/lib/zmtp
and Jupyter's messaging specification (5.4). Every message must carry the
right signature.

  client.py CONNECTION-FILE KERNEL-PID"""
import hashlib
import hmac
import json
import os
import signal
import sys
import time
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib", "zmtp", "interop"))
import peer  # noqa: E402

conn = json.load(open(sys.argv[1]))
kernel_pid = int(sys.argv[2])
key = conn["key"].encode()
session = uuid.uuid4().hex
ok = True


def check(name, cond, detail=""):
    global ok
    print(("PASS " if cond else "FAIL ") + name + ("" if cond or not detail else ": " + str(detail)))
    ok = ok and bool(cond)


def sign(parts):
    return hmac.new(key, b"".join(parts), hashlib.sha256).hexdigest().encode()


def send(sock, msg_type, content):
    header = {"msg_id": uuid.uuid4().hex, "session": session, "username": "test",
              "date": "2026-10-10T00:00:00Z", "msg_type": msg_type, "version": "5.4"}
    parts = [json.dumps(x).encode() for x in (header, {}, {}, content)]
    sock.sendall(peer.message([b"<IDS|MSG>", sign(parts)] + parts))
    return header["msg_id"]


def receive(sock):
    frames = peer.read_message(sock)
    i = frames.index(b"<IDS|MSG>")
    signature, parts = frames[i + 1], frames[i + 2:i + 6]
    if not hmac.compare_digest(signature, sign(parts)):
        check("a signed message", False)
    header, parent, metadata, content = (json.loads(p) for p in parts)
    return header, parent, content


shell = peer.connect(conn["shell_port"], b"DEALER", b"client")
control = peer.connect(conn["control_port"], b"DEALER", b"client")
stdin = peer.connect(conn["stdin_port"], b"DEALER", b"client")
iopub = peer.connect(conn["iopub_port"], b"SUB")
iopub.sendall(peer.command(b"SUBSCRIBE", b""))
hb = peer.connect(conn["hb_port"], b"REQ")
time.sleep(0.5)


def iopub_until_idle(mid):
    """what iopub said for the request mid, to its idle"""
    said = []
    while True:
        h, p, c = receive(iopub)
        if p.get("msg_id") != mid:
            continue
        said.append((h["msg_type"], c))
        if h["msg_type"] == "status" and c["execution_state"] == "idle":
            return said


def request(msg_type, content, sock=shell, stdin_answer=None):
    mid = send(sock, msg_type, content)
    if stdin_answer is not None:
        h, p, c = receive(stdin)
        check("input_request on stdin", h["msg_type"] == "input_request" and p["msg_id"] == mid, h["msg_type"])
        send(stdin, "input_reply", {"value": stdin_answer})
    header, parent, reply = receive(sock)
    check(msg_type + " answered", header["msg_type"] == msg_type.replace("_request", "_reply")
          and parent["msg_id"] == mid, header["msg_type"])
    return reply, iopub_until_idle(mid)


def execute(code, allow_stdin=False, stdin_answer=None):
    return request("execute_request", {"code": code, "silent": False, "store_history": True, "user_expressions": {},
                                       "allow_stdin": allow_stdin, "stop_on_error": True}, stdin_answer=stdin_answer)


def of(said, kind):
    return [c for t, c in said if t == kind]


hb.sendall(peer.message([b"", b"beat"]))
check("the heart beats", peer.read_message(hb) == [b"", b"beat"])

reply, _ = request("kernel_info_request", {})
check("kernel_info", reply["language_info"]["name"] == "sml" and reply["implementation"] == "rune-kernel"
      and reply["protocol_version"] == "5.4" and reply.get("debugger") is True, reply)

reply, said = execute("val x = 1 + 2")
results = of(said, "execute_result")
check("a declaration without its ;", reply["status"] == "ok" and reply["execution_count"] == 1, reply)
check("its result as text", len(results) == 1 and results[0]["data"]["text/plain"] == "val x = 3 : int", results)
check("its result as HTML in the palette's styles",
      len(results) == 1 and "rune-syn-number" in results[0]["data"]["text/html"]
      and "<style>" in results[0]["data"]["text/html"], results)

reply, said = execute('val () = print "hello\\n"; val () = TextIO.output (TextIO.stdErr, "to stderr\\n");')
streams = of(said, "stream")
check("the program's output as streams", {"name": "stdout", "text": "hello\n"} in streams
      and {"name": "stderr", "text": "to stderr\n"} in streams, streams)

reply, said = execute("val y = x + undefined;")
errors = of(said, "error")
check("a compile error", reply["status"] == "error" and len(errors) == 1
      and "unbound variable or constructor: undefined" in errors[0]["traceback"][0], (reply, errors))

reply, said = execute('fun f 0 = raise Fail "zero" | f n = f (n - 1); f 2 : int;')
errors = of(said, "error")
check("an uncaught exception", reply["status"] == "error" and reply["ename"] == "Fail" and len(errors) == 1
      and errors[0]["traceback"][0] == "uncaught exception Fail: zero"
      and any("in f at" in l for l in errors[0]["traceback"]), (reply, errors))

reply, _ = request("is_complete_request", {"code": "val z = let in 1"})
check("is_complete: incomplete", reply["status"] == "incomplete", reply)
reply, _ = request("is_complete_request", {"code": "val z = 1;"})
check("is_complete: complete", reply["status"] == "complete", reply)

reply, _ = request("complete_request", {"code": "List.fil", "cursor_pos": 8})
check("complete", "filter" in reply["matches"] and reply["cursor_start"] == 5 and reply["cursor_end"] == 8, reply)

reply, _ = request("inspect_request", {"code": "List.map", "cursor_pos": 6, "detail_level": 0})
check("inspect", reply["found"] and "val List.map" in reply["data"]["text/plain"], reply)

reply, said = execute("val l = TextIO.inputLine TextIO.stdIn;", allow_stdin=True, stdin_answer="typed")
results = of(said, "execute_result")
check("input from the notebook", len(results) == 1
      and results[0]["data"]["text/plain"] == 'val l = SOME "typed\\n" : string option', results)

reply, said = execute('Display.displayAs ("d", [("text/html", "<b>first</b>"), ("text/plain", "first")]); '
                     'Display.update ("d", [("text/plain", "second")]); Display.clear true;')
kinds = [t for t, _ in said]
check("Display: display_data, update_display_data, clear_output",
      "display_data" in kinds and "update_display_data" in kinds and "clear_output" in kinds
      and of(said, "display_data")[0]["data"]["text/html"] == "<b>first</b>"
      and of(said, "display_data")[0]["transient"] == {"display_id": "d"}
      and of(said, "update_display_data")[0]["data"] == {"text/plain": "second"}, said)

# JupyterLab's debugger: DAP in debug_request on the control channel, a stop
# a debug_event, a cell compiled under the file its code's hash names


def murmur2_x86(data, seed):
    """ipykernel's, which JupyterLab names a cell's file by"""
    m = 0x5BD1E995
    data = data.encode("utf8")
    h = seed ^ len(data)
    end = len(data) & ~3
    for i in range(0, end, 4):
        k = data[i] | (data[i + 1] << 8) | (data[i + 2] << 16) | (data[i + 3] << 24)
        k = (k * m) & 0xFFFFFFFF
        k ^= k >> 24
        k = (k * m) & 0xFFFFFFFF
        h = ((h * m) & 0xFFFFFFFF) ^ k
    rest = len(data) & 3
    if rest:
        k = 0
        if rest == 3:
            k = data[end + 2] << 16
        if rest >= 2:
            k |= data[end + 1] << 8
        k |= data[end]
        h = ((h ^ k) * m) & 0xFFFFFFFF
    h ^= h >> 13
    h = (h * m) & 0xFFFFFFFF
    return h ^ (h >> 15)


dseq = 0


def debug(command, arguments=None):
    global dseq
    dseq += 1
    mid = send(control, "debug_request", {"seq": dseq, "type": "request", "command": command,
                                          "arguments": arguments or {}})
    h, p, c = receive(control)
    check("debug " + command + " answered", h["msg_type"] == "debug_reply" and p["msg_id"] == mid
          and c.get("request_seq") == dseq, (h["msg_type"], c))
    return c


check("debug initialize", debug("initialize", {"clientID": "test", "adapterID": "rune"})["success"])
check("debug attach", debug("attach", {})["success"])
info = debug("debugInfo")["body"]
check("debugInfo", info["isStarted"] and info["hashMethod"] == "Murmur2" and info["tmpFileSuffix"] == ".sml", info)
cell = "fun dbl x =\n  let val y = x + 1\n  in y * 2\n  end"
path = debug("dumpCell", {"code": cell})["body"]["sourcePath"]
check("dumpCell names the cell by its hash",
      path == info["tmpFilePrefix"] + str(murmur2_x86(cell, info["hashSeed"])) + info["tmpFileSuffix"]
      and open(path).read() == cell, path)
r = debug("setBreakpoints", {"source": {"path": path}, "breakpoints": [{"line": 2}]})
check("setBreakpoints", r["success"] and len(r["body"]["breakpoints"]) == 1, r)
check("configurationDone", debug("configurationDone")["success"])
reply, said = execute(cell)
check("the cell compiled under its file", reply["status"] == "ok", reply)
mid = send(shell, "execute_request", {"code": "dbl 20;", "silent": False, "store_history": True,
                                      "user_expressions": {}, "allow_stdin": False, "stop_on_error": True})
while True:
    h, p, c = receive(iopub)
    if h["msg_type"] == "debug_event":
        break
check("a stop is a debug_event", c["event"] == "stopped" and c["body"]["reason"] == "breakpoint", c)
frames = debug("stackTrace", {"threadId": 1})["body"]["stackFrames"]
check("stackTrace: the cell's frame", frames[0]["name"] == "dbl" and frames[0]["line"] == 2
      and frames[0]["source"]["path"] == path, frames)
ref = debug("scopes", {"frameId": 0})["body"]["scopes"][0]["variablesReference"]
vs = {v["name"]: v["value"] for v in debug("variables", {"variablesReference": ref})["body"]["variables"]}
check("variables", vs == {"x": "20"}, vs)
r = debug("evaluate", {"expression": "x * 2", "frameId": 0, "context": "repl"})
check("evaluate in the frame", r["success"] and r["body"]["result"] == "40", r)
check("continue", debug("continue", {"threadId": 1})["success"])
header, parent, reply = receive(shell)
said = iopub_until_idle(mid)
results = of(said, "execute_result")
check("the cell ends", reply["status"] == "ok" and results and results[0]["data"]["text/plain"] == "val it = 42 : int",
      (reply, results))
check("debug disconnect", debug("disconnect", {"restart": False})["success"])

# an interrupt, as Jupyter gives it with interrupt_mode signal
mid = send(shell, "execute_request", {"code": "fun loop () : unit = loop (); loop ();", "silent": False,
                                      "store_history": True, "user_expressions": {}, "allow_stdin": False,
                                      "stop_on_error": True})
time.sleep(1.5)
os.kill(kernel_pid, signal.SIGINT)
header, parent, reply = receive(shell)
said = iopub_until_idle(mid)
check("an interrupt ends the execution", reply["status"] == "error" and reply["ename"] == "Interrupt", reply)
reply, said = execute("x + 1;")
results = of(said, "execute_result")
check("the session goes on", reply["status"] == "ok" and results and results[0]["data"]["text/plain"] == "val it = 4 : int",
      results)

send(control, "shutdown_request", {"restart": False})
header, _, content = receive(control)
check("shutdown", header["msg_type"] == "shutdown_reply" and content["status"] == "ok", content)
sys.exit(0 if ok else 1)

#!/usr/bin/env python3
"""The client of tests/lib/jupyter/interop.sh, written from Jupyter's
messaging specification (5.4) on the ZMTP peer of tests/lib/zmtp, with the
standard library alone: it asks the kernel for its info, executes code and
checks what iopub says around it (busy, the input, a stream, the result,
idle), asks whether code is complete, beats the heart, and shuts the
kernel down on the control channel. Every message it receives must carry
the right signature.

  client.py CONNECTION-FILE"""
import hashlib
import hmac
import json
import os
import sys
import time
import uuid

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "zmtp", "interop"))
import peer  # noqa: E402

conn = json.load(open(sys.argv[1]))
key = conn["key"].encode()
session = uuid.uuid4().hex
ok = True


def check(name, cond):
    global ok
    print(("PASS " if cond else "FAIL ") + name)
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
    check("a signed message", hmac.compare_digest(signature, sign(parts)))
    header, parent, metadata, content = (json.loads(p) for p in parts)
    return header, parent, content


shell = peer.connect(conn["shell_port"], b"DEALER", b"client")
control = peer.connect(conn["control_port"], b"DEALER", b"client")
iopub = peer.connect(conn["iopub_port"], b"SUB")
iopub.sendall(peer.command(b"SUBSCRIBE", b""))
hb = peer.connect(conn["hb_port"], b"REQ")
time.sleep(0.3)

hb.sendall(peer.message([b"", b"beat"]))
check("the heart beats", peer.read_message(hb) == [b"", b"beat"])

mid = send(shell, "kernel_info_request", {})
header, parent, content = receive(shell)
check("kernel_info_reply", header["msg_type"] == "kernel_info_reply" and parent["msg_id"] == mid
      and content["protocol_version"] == "5.4" and content["language_info"]["name"] == "echo")
states = [receive(iopub) for _ in range(2)]
check("busy, then idle", [h["msg_type"] for h, _, _ in states] == ["status", "status"]
      and [c["execution_state"] for _, _, c in states] == ["busy", "idle"]
      and all(p["msg_id"] == mid for _, p, _ in states))

mid = send(shell, "execute_request", {"code": "abc;", "silent": False, "store_history": True,
                                      "user_expressions": {}, "allow_stdin": False, "stop_on_error": True})
header, parent, content = receive(shell)
check("execute_reply", header["msg_type"] == "execute_reply" and content["status"] == "ok"
      and content["execution_count"] == 1 and parent["msg_id"] == mid)
said = [receive(iopub) for _ in range(5)]
check("iopub around an execution", [h["msg_type"] for h, _, _ in said]
      == ["status", "execute_input", "stream", "execute_result", "status"])
check("the stream", said[2][2] == {"name": "stdout", "text": "you said: abc;"})
check("the result", said[3][2]["data"] == {"text/plain": ";cba"} and said[3][2]["execution_count"] == 1)

send(shell, "is_complete_request", {"code": "val x = 1"})
header, _, content = receive(shell)
check("is_complete_reply", header["msg_type"] == "is_complete_reply" and content["status"] == "incomplete")
[receive(iopub) for _ in range(2)]

send(control, "shutdown_request", {"restart": False})
header, _, content = receive(control)
check("shutdown_reply", header["msg_type"] == "shutdown_reply" and content == {"status": "ok", "restart": False})
sys.exit(0 if ok else 1)

#!/usr/bin/env python3
"""The other side of bin/rune-protocol-check interop zmtp: a peer written from ZMTP
3.1 (rfc.zeromq.org/spec/37) with the standard library alone, which
talks to lib/zmtp's ROUTER as a DEALER, to its REP as a REQ and to its PUB
as a SUB, and pings the ROUTER's connection (PING and PONG).

  peer.py PORTFILE"""
import socket
import struct
import sys
import time


def frame(flags, body):
    if len(body) < 256:
        return bytes([flags, len(body)]) + body
    return bytes([flags | 2]) + struct.pack(">Q", len(body)) + body


def message(parts):
    return b"".join(frame(1 if i < len(parts) - 1 else 0, p) for i, p in enumerate(parts))


def command(name, data=b""):
    return frame(4, bytes([len(name)]) + name + data)


def exact(s, n):
    out = b""
    while len(out) < n:
        chunk = s.recv(n - len(out))
        if not chunk:
            raise EOFError("the connection closed")
        out += chunk
    return out


def read_frame(s):
    f = exact(s, 1)[0]
    n = struct.unpack(">Q", exact(s, 8))[0] if f & 2 else exact(s, 1)[0]
    return f, exact(s, n)


def read_message(s):
    parts = []
    while True:
        f, body = read_frame(s)
        if f & 4:
            continue
        parts.append(body)
        if not f & 1:
            return parts


def connect(port, kind, identity=b""):
    s = socket.create_connection(("127.0.0.1", port), timeout=10)
    greeting = b"\xff" + b"\0" * 8 + b"\x7f" + b"\x03\x01" + b"NULL".ljust(20, b"\0") + b"\0" + b"\0" * 31
    s.sendall(greeting)
    peer = exact(s, 64)
    assert peer[0] == 0xFF and peer[9] == 0x7F and peer[10] == 3, "a bad greeting: %r" % peer[:12]
    assert peer[12:32].rstrip(b"\0") == b"NULL", "mechanism %r" % peer[12:32]
    meta = bytes([11]) + b"Socket-Type" + struct.pack(">I", len(kind)) + kind
    if identity:
        meta += bytes([8]) + b"Identity" + struct.pack(">I", len(identity)) + identity
    s.sendall(command(b"READY", meta))
    f, body = read_frame(s)
    assert f & 4 and body[1:1 + body[0]] == b"READY", "no READY: %r" % body
    return s


def main():
    ports = None
    for _ in range(200):
        try:
            ports = [int(p) for p in open(sys.argv[1]).read().split()]
            break
        except (OSError, ValueError):
            time.sleep(0.05)
    router, rep, pub = ports
    ok = True

    def check(name, cond):
        nonlocal ok
        print(("PASS " if cond else "FAIL ") + name)
        ok = ok and cond

    dealer = connect(router, b"DEALER", b"py")
    dealer.sendall(message([b"hello", b"world", b"x" * 300]))
    check("DEALER to ROUTER and back, a long frame among them",
          read_message(dealer) == [b"x" * 300, b"world", b"hello"])
    dealer.sendall(command(b"PING", struct.pack(">H", 100) + b"ctx"))
    f, body = read_frame(dealer)
    check("PING and PONG", f & 4 and body == bytes([4]) + b"PONG" + b"ctx")

    req = connect(rep, b"REQ")
    req.sendall(message([b"", b"ping"]))
    check("REQ to REP and back", read_message(req) == [b"", b"pong:ping"])

    sub = connect(pub, b"SUB")
    sub.sendall(command(b"SUBSCRIBE", b"topic"))
    time.sleep(0.3)
    dealer.sendall(message([b"publish"]))
    check("the ROUTER asked to publish", read_message(dealer) == [b"published"])
    check("SUB receives what it subscribed to", read_message(sub) == [b"topic.x", b"data"])

    dealer.sendall(message([b"quit"]))
    check("the server ends", read_message(dealer) == [b"bye"])
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

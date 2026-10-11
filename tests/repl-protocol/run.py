#!/usr/bin/env python3
"""The REPL engine's protocol (docs/repl-protocol.md; docs/plans/repl.md, M10),
as a front drives it: each tests/repl-protocol/NAME.script is played to
`rune-repl --engine`, the protocol on the descriptors 3 and 4, and what comes
back -- the engine's messages, and what the program writes on its standard
output and error, drained before each message is read, as D20 asks of a
front -- is NAME.out, which must be NAME.expected.

  tests/repl-protocol/run.py [--update] [FILTER]

A script is one command per line; `#` starts a comment.

  send JSON          a message, framed as the run is (lines, or with
                     --framing content-length, Content-Length headers)
  raw TEXT           bytes as they are (\\n escapes), to test what is no JSON
  until METHOD|ID    read until a message that is the response to ID or a
                     message of METHOD has come
  input TEXT         the answer to the engine's next `input` request
  signal             SIGINT to the engine, 0.3 s after it has said it is busy
  sleep MS           only to let the engine start what is to be interrupted
  end                close the channel and wait for the engine to end

The engine's version in an answer is written VERSION, and status
notifications are left out of the transcript, so that it says what was
answered rather than when.
"""
import json
import os
import re
import select
import signal
import subprocess
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DIR = os.path.join(ROOT, "tests", "repl-protocol")
OUT = os.path.join(ROOT, "tests", "out", "repl-protocol")


def start(extra):
    to_r, to_w = os.pipe()        # what the front sends: the engine's 3
    from_r, from_w = os.pipe()    # what the engine answers: its 4

    # the channel made the child's 3 and 4, and the ends that are the
    # front's closed there, so that the engine sees the end when the front
    # closes its own; subprocess would close 3 and 4 again after preexec_fn
    # where close_fds is set
    def child():
        os.dup2(to_r, 3)
        os.dup2(from_w, 4)
        for fd in (to_w, from_r, to_r, from_w):
            if fd not in (3, 4):
                os.close(fd)
        # a pipe is made close-on-exec, which dup2 onto itself leaves set
        os.set_inheritable(3, True)
        os.set_inheritable(4, True)

    env = dict(os.environ)
    env["RUNE_CACHE"] = ""
    p = subprocess.Popen(["bin/runevm", "--heap-size", "67108864", "--restore", "bin/rune-repl.img", "--",
                          "--no-init", "--engine"] + extra,
                         cwd=ROOT, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         close_fds=False, preexec_fn=child, env=env)
    os.close(to_r)
    os.close(from_w)
    return p, to_w, from_r


class Run:
    def __init__(self, framing):
        self.framing = framing
        self.p, self.to, self.fr = start([])
        self.buf = b""
        self.lines = []
        self.inputs = []
        self.busy = False

    def drain(self):
        for name, f in (("stdout", self.p.stdout), ("stderr", self.p.stderr)):
            while True:
                r, _, _ = select.select([f], [], [], 0)
                if not r:
                    break
                data = os.read(f.fileno(), 65536)
                if not data:
                    break
                for l in data.decode("utf-8", "replace").splitlines():
                    self.lines.append("%s: %s" % (name, l))

    def frame(self, text):
        data = text.encode("utf-8")
        if self.framing == "content-length":
            return b"Content-Length: %d\r\n\r\n" % len(data) + data
        return data + b"\n"

    def send(self, text):
        # busy again only once the engine says so of what is sent now
        self.busy = False
        os.write(self.to, self.frame(text))

    def messages(self):
        """the messages the bytes so far complete"""
        out = []
        while True:
            if self.framing == "content-length":
                m = re.match(rb"Content-Length: (\d+)\r\n\r\n", self.buf)
                if not m or len(self.buf) < m.end() + int(m.group(1)):
                    return out
                n = m.end() + int(m.group(1))
                out.append(self.buf[m.end():n].decode("utf-8"))
                self.buf = self.buf[n:]
            else:
                i = self.buf.find(b"\n")
                if i < 0:
                    return out
                out.append(self.buf[:i].decode("utf-8"))
                self.buf = self.buf[i + 1:]

    def record(self, m):
        if m.get("method") == "status":
            self.busy = m["params"]["state"] == "busy"
            return
        if m.get("method") == "input":
            text = self.inputs.pop(0) if self.inputs else None
            self.lines.append("engine asks: input")
            self.send(json.dumps({"jsonrpc": "2.0", "id": m["id"], "result": text}))
            return
        r = m.get("result")
        if isinstance(r, dict) and isinstance(r.get("implementation"), str):
            r["implementation"] = re.sub(r" .*", " VERSION", r["implementation"])
        self.lines.append("<- " + json.dumps(m, sort_keys=True))

    def until(self, what, seconds=60.0):
        deadline = time.monotonic() + seconds
        while True:
            for text in self.messages():
                self.drain()
                m = json.loads(text)
                self.record(m)
                response = "result" in m or "error" in m
                ident = "null" if m.get("id") is None else str(m.get("id"))
                if (response and ident == what) or m.get("method") == what:
                    return
            left = deadline - time.monotonic()
            if left <= 0:
                raise RuntimeError("no %s after %g s" % (what, seconds))
            r, _, _ = select.select([self.fr], [], [], left)
            if r:
                data = os.read(self.fr, 65536)
                if not data:
                    raise RuntimeError("the engine closed its channel before %s" % what)
                self.buf += data

    def wait_busy(self, seconds=20.0):
        deadline = time.monotonic() + seconds
        while not self.busy:
            for text in self.messages():
                self.record(json.loads(text))
            if self.busy:
                return
            r, _, _ = select.select([self.fr], [], [], max(0.0, deadline - time.monotonic()))
            if not r:
                raise RuntimeError("the engine is not busy")
            self.buf += os.read(self.fr, 65536)

    def end(self):
        os.close(self.to)
        self.p.wait(timeout=30)
        self.drain()
        rest = self.p.stdout.read().decode("utf-8", "replace") + self.p.stderr.read().decode("utf-8", "replace")
        for l in rest.splitlines():
            self.lines.append("output: " + l)
        self.lines.append("ended %d" % self.p.returncode)


def play(path, framing):
    run = Run(framing)
    try:
        for raw in open(path, encoding="utf-8"):
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            command, _, rest = line.strip().partition(" ")
            if command == "send":
                run.lines.append("-> " + rest)
                run.send(rest)
            elif command == "raw":
                run.lines.append("-> (raw) " + rest)
                os.write(run.to, rest.encode("utf-8").decode("unicode_escape").encode("latin-1"))
            elif command == "until":
                run.until(rest)
            elif command == "input":
                run.inputs.append(rest.encode("utf-8").decode("unicode_escape"))
            elif command == "signal":
                # once busy, a moment for the evaluation to be running, so
                # that what is interrupted is the same every time
                run.wait_busy()
                time.sleep(0.3)
                run.p.send_signal(signal.SIGINT)
                run.lines.append("SIGINT")
            elif command == "sleep":
                time.sleep(int(rest) / 1000.0)
            elif command == "end":
                run.end()
            else:
                raise RuntimeError("unknown command %r" % command)
    except RuntimeError as e:
        run.lines.append("FAILED: %s" % e)
        try:
            run.p.kill()
        except ProcessLookupError:
            pass
    return "\n".join(run.lines) + "\n"


def main():
    args = sys.argv[1:]
    update = "--update" in args
    args = [a for a in args if a != "--update"]
    filt = args[0] if args else ""
    os.makedirs(OUT, exist_ok=True)
    passed = failed = 0
    for name in sorted(os.listdir(DIR)):
        if not name.endswith(".script") or filt not in name:
            continue
        base = name[:-len(".script")]
        framing = "content-length" if base.endswith("-headers") else "lines"
        got = play(os.path.join(DIR, name), framing)
        open(os.path.join(OUT, base + ".out"), "w", encoding="utf-8").write(got)
        expected = os.path.join(DIR, base + ".expected")
        if update:
            open(expected, "w", encoding="utf-8").write(got)
        want = open(expected, encoding="utf-8").read() if os.path.exists(expected) else None
        if got == want:
            passed += 1
        else:
            failed += 1
            print("FAIL repl-protocol.%s (diff %s %s)" % (base, expected, os.path.join(OUT, base + ".out")))
    print("repl-protocol: passed %d, failed %d" % (passed, failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()

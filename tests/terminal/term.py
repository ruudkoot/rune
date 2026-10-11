#!/usr/bin/env python3
"""Drive a program on a terminal and check what the terminal shows
(docs/plans/repl.md, M1).

  tests/terminal/term.py SCRIPT [NAME=VALUE ...]

The program runs in a tmux server of its own, at the size the script asks
for; the script types at it, resizes it, and waits for the screen to show
what it should. Every wait is on the screen, never on time alone, so a slow
machine makes a test slower, not wrong. On Windows (through WSL interop) a
program started in a pane gets a console of the pane's size, so the same
scripts drive runevm.exe.

A script is one command per line; `#` starts a comment, and @NAME@ is
replaced by the NAME=VALUE given on the command line.

  start COLS ROWS CMD...    start CMD in a pane of that size
  send TEXT                 type TEXT (\\n \\r \\t \\e \\xNN escapes)
  keys KEY...               tmux's names of keys: Up C-a M-b Enter Escape BSpace
  paste TEXT                TEXT inside bracketed-paste markers
  wait REGEX [SECONDS]      until the screen matches REGEX (default 20 s)
  waits REGEX [SECONDS]     the same, on the screen with its styles as SGR
                            escapes (tmux's capture-pane -e; \\e for ESC)
  gone REGEX [SECONDS]      until the screen no longer matches REGEX
  resize COLS ROWS          the pane's new size
  expect FILE               the screen, trailing blanks dropped, is FILE's
  capture FILE              write the screen to FILE (to make an expectation)
  exited [STATUS] [SECONDS] until the program has ended, with STATUS if given
  sleep MS                  only to give a program time to do something wrong

Exits 0 when the script ran to its end, 1 with the screen printed at the
first command that failed. Text is typed as bytes (tmux's send-keys -H),
since tmux takes a lone `;` among its arguments for its own separator.
"""
import os
import re
import signal
import subprocess
import sys
import time

SOCKET = "rune-terminal-%d" % os.getpid()
PANE = "t"


def tmux(*args, check=True):
    r = subprocess.run(["tmux", "-L", SOCKET, "-f", "/dev/null"] + list(args),
                       capture_output=True, text=True)
    if check and r.returncode != 0:
        raise RuntimeError("tmux %s: %s" % (" ".join(args), r.stderr.strip()))
    return r.stdout


def screen(escapes=False):
    return tmux("capture-pane", "-p", "-t", PANE, *(["-e"] if escapes else []))


def plain(text):
    return "\n".join(l.rstrip() for l in text.rstrip("\n").split("\n")).rstrip("\n") + "\n"


def bytes_of(text):
    return (text.encode("utf-8").decode("unicode_escape").encode("latin-1")
            if "\\" in text else text.encode("utf-8"))


def type_bytes(data):
    for i in range(0, len(data), 256):
        tmux("send-keys", "-t", PANE, "-H", *["%02x" % b for b in data[i:i + 256]])


class Failure(Exception):
    pass


def wait_for(pattern, seconds, present, escapes=False):
    deadline = time.monotonic() + seconds
    rx = re.compile(pattern.replace("\\e", "\x1b") if escapes else pattern, re.M)
    while True:
        if bool(rx.search(screen(escapes))) == present:
            return
        if time.monotonic() > deadline:
            raise Failure("%s %r after %g s" % ("no" if present else "still", pattern, seconds))
        time.sleep(0.02)


def pane(field):
    return tmux("display-message", "-p", "-t", PANE, "#{%s}" % field).strip()


def run(path, subst):
    started = False
    for number, raw in enumerate(open(path, encoding="utf-8"), 1):
        line = raw.rstrip("\n")
        for k, v in subst.items():
            line = line.replace("@%s@" % k, v)
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        command, _, rest = line.strip().partition(" ")
        try:
            if command == "start":
                cols, rows, program = rest.split(" ", 2)
                tmux("new-session", "-d", "-s", PANE, "-x", cols, "-y", rows, program)
                started = True
                tmux("set-option", "-t", PANE, "status", "off")
                tmux("set-option", "-t", PANE, "remain-on-exit", "on")
                tmux("set-option", "-s", "escape-time", "0")
                tmux("resize-window", "-t", PANE, "-x", cols, "-y", rows)
            elif command == "send":
                type_bytes(bytes_of(rest))
            elif command == "keys":
                tmux("send-keys", "-t", PANE, *rest.split())
            elif command == "paste":
                type_bytes(b"\x1b[200~" + bytes_of(rest) + b"\x1b[201~")
            elif command in ("wait", "gone", "waits"):
                pattern, seconds = rest, 20.0
                m = re.match(r"(.*) ([0-9.]+)$", rest)
                if m:
                    pattern, seconds = m.group(1), float(m.group(2))
                wait_for(pattern, seconds, command != "gone", command == "waits")
            elif command == "resize":
                cols, rows = rest.split()
                tmux("resize-window", "-t", PANE, "-x", cols, "-y", rows)
            elif command == "expect":
                want = open(rest, encoding="utf-8").read()
                # what a screen writes @KEY@ is the script's KEY: @VERSION@
                for k, v in subst.items():
                    want = want.replace("@%s@" % k, v)
                got = plain(screen())
                if plain(want) != got:
                    open(rest + ".got", "w", encoding="utf-8").write(got)
                    raise Failure("the screen is not %s (it is in %s.got)" % (rest, rest))
            elif command == "capture":
                open(rest, "w", encoding="utf-8").write(plain(screen()))
            elif command == "exited":
                parts = rest.split()
                status = parts[0] if parts else None
                seconds = float(parts[1]) if len(parts) > 1 else 20.0
                deadline = time.monotonic() + seconds
                while pane("pane_dead") != "1":
                    if time.monotonic() > deadline:
                        raise Failure("the program has not ended after %g s" % seconds)
                    time.sleep(0.02)
                # tmux may say the pane is dead a moment before it has the
                # status: wait for it a little. Here (tmux 3.4 on WSL 2) the
                # server sometimes misses the SIGCHLD of the pane's process
                # and leaves it a zombie, unreaped (4 runs in 80 of a REPL
                # ending, 2026-10-10); a SIGCHLD sent to the server makes it
                # reap the process and take the status
                settled = time.monotonic() + 5
                nudge = time.monotonic() + 0.5
                got = pane("pane_dead_status")
                while got == "" and time.monotonic() < settled:
                    time.sleep(0.02)
                    if time.monotonic() > nudge:
                        os.kill(int(tmux("display-message", "-p", "#{pid}").strip()), signal.SIGCHLD)
                        nudge = time.monotonic() + 0.5
                    got = pane("pane_dead_status")
                if status is not None and got != status:
                    raise Failure("the program ended with %s, not %s" % (got or "no status", status))
            elif command == "sleep":
                time.sleep(int(rest) / 1000.0)
            else:
                raise Failure("unknown command %r" % command)
        except (Failure, RuntimeError) as e:
            sys.stdout.write("%s:%d: %s\n" % (path, number, e))
            if started:
                sys.stdout.write("--- the screen ---\n%s------------------\n" % plain(screen()))
            return False
    return True


def main():
    subst = dict(a.split("=", 1) for a in sys.argv[2:])
    try:
        ok = run(sys.argv[1], subst)
    finally:
        tmux("kill-server", check=False)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()

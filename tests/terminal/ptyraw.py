#!/usr/bin/env python3
"""Run a program on a pty of a given size, write to it, and time what it
writes back, to the microsecond (docs/plans/repl.md, M1;
scripts/perf-repl.sh). tests/terminal/term.py is for screens; this is for
bytes and times.

Usage: ptyraw.py COLS ROWS SCRIPT -- CMD...

SCRIPT lines:
  write TEXT          write TEXT (\\e, \\xNN, \\r escapes) to the program
  until REGEX [SECS]  read output until the bytes so far (decoded latin-1)
                      match REGEX; prints the elapsed ms since the last write
  quiet MS            read until no output for MS milliseconds
  winch COLS ROWS     resize the pty and send SIGWINCH
  mark LABEL          start a timing interval
  report LABEL        print ms since the mark
  dump                print everything read since the last dump, as escaped text
Output is a log on stdout: one line per event, with timestamps.
"""
import fcntl, os, pty, re, select, signal, struct, sys, termios, time

def setsize(fd, cols, rows):
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

def unescape(s):
    return s.encode("utf-8").decode("unicode_escape").encode("latin-1")

def main():
    cols, rows, script = int(sys.argv[1]), int(sys.argv[2]), sys.argv[3]
    cmd = sys.argv[sys.argv.index("--") + 1:]
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(cmd[0], cmd)
    setsize(fd, cols, rows)
    os.kill(pid, signal.SIGWINCH)
    buf = b""
    seen = 0
    dumped = 0
    t_write = t_mark = time.monotonic()

    def read_for(timeout):
        nonlocal buf
        r, _, _ = select.select([fd], [], [], timeout)
        if not r:
            return False
        try:
            data = os.read(fd, 65536)
        except OSError:
            return None
        if not data:
            return None
        buf += data
        return True

    for raw in open(script, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        cmd_, _, rest = line.strip().partition(" ")
        if cmd_ == "write":
            # Write while reading: a cooked tty echoes what it is given, and
            # a writer that does not read its echo deadlocks on a full buffer.
            data = unescape(rest)
            t_write = time.monotonic()
            while data:
                r, w, _ = select.select([fd], [fd], [], 10.0)
                if r:
                    read_for(0)
                if w:
                    n = os.write(fd, data[:1024])
                    data = data[n:]
        elif cmd_ == "until":
            parts = rest.rsplit(" ", 1)
            secs = 10.0
            if len(parts) == 2 and re.fullmatch(r"[0-9.]+", parts[1]):
                rest, secs = parts[0], float(parts[1])
            pat = re.compile(rest.encode("latin-1"), re.S)
            deadline = time.monotonic() + secs
            while not pat.search(buf, seen):
                left = deadline - time.monotonic()
                if left <= 0 or read_for(left) is None:
                    print("TIMEOUT until %r; have %r" % (rest, buf[seen:]))
                    sys.exit(1)
            seen = pat.search(buf, seen).end()
            print("UNTIL %r %.2f ms" % (rest, (time.monotonic() - t_write) * 1000))
        elif cmd_ == "quiet":
            ms = int(rest)
            while read_for(ms / 1000.0):
                pass
        elif cmd_ == "winch":
            c, r = rest.split()
            setsize(fd, int(c), int(r))
            os.kill(pid, signal.SIGWINCH)
        elif cmd_ == "mark":
            t_mark = time.monotonic()
        elif cmd_ == "report":
            print("REPORT %s %.2f ms" % (rest, (time.monotonic() - t_mark) * 1000))
        elif cmd_ == "dump":
            print("DUMP %d bytes: %r" % (len(buf) - dumped, buf[dumped:]))
            dumped = len(buf)
        else:
            print("unknown command %r" % cmd_)
            sys.exit(2)
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    os.waitpid(pid, 0)

if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Types a transcript to the REPL with interrupts in it (tests/repl/run.sh).

    tests/repl/drive.py OUT CMD...

Each line of the standard input is typed to CMD, whose standard output and
standard error together go to OUT, except a line

    #!interrupt after TEXT

which waits until OUT holds TEXT once more than it did when the last such line
waited, then a fifth of a second, and sends CMD SIGINT, as Ctrl-C at a
terminal would. CMD starts with SIGINT as the system has it by default,
whatever this was started with. Exits 1 where CMD never writes TEXT, or does
not end within two minutes of the end of the input.
"""
import signal
import subprocess
import sys
import time

out_path, cmd = sys.argv[1], sys.argv[2:]
lines = sys.stdin.read().splitlines(keepends=True)
seen = {}


def default_interrupt():
    signal.signal(signal.SIGINT, signal.SIG_DFL)


with open(out_path, "wb") as out:
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=out, stderr=subprocess.STDOUT,
                         preexec_fn=default_interrupt)

    def wait_for(text):
        want = seen.get(text, 0) + 1
        deadline = time.time() + 60
        while time.time() < deadline:
            with open(out_path, "rb") as f:
                if f.read().count(text.encode()) >= want:
                    seen[text] = want
                    return True
            if p.poll() is not None:
                return False
            time.sleep(0.05)
        return False

    for line in lines:
        if line.startswith("#!interrupt after "):
            text = line[len("#!interrupt after "):].rstrip("\n")
            if not wait_for(text):
                p.kill()
                p.wait()
                sys.stderr.write("drive.py: %s never wrote %r\n" % (cmd[0], text))
                sys.exit(1)
            time.sleep(0.2)
            p.send_signal(signal.SIGINT)
        else:
            p.stdin.write(line.encode())
            p.stdin.flush()
    p.stdin.close()
    try:
        p.wait(timeout=120)
    except subprocess.TimeoutExpired:
        p.kill()
        p.wait()
        sys.exit(1)

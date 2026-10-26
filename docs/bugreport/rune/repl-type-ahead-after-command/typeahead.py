# Type a line at the REPL while a command it was given runs, through a pty,
# and say whether the line ran. The window is the command's own run: with
# DELAY=0.002 a line typed after `:set pause on` or `:help` is lost to a
# continuation prompt about half the time and more; with no delay (the
# editor still raw) or 10 ms (the command done, the editor raw again) it
# runs, and a line typed after code (`val c = 1;`) always runs.
#
#   DELAY=0.002 python3 typeahead.py bin/rune-repl ':set pause on'
import os, pty, sys, time, select, re
repl = sys.argv[1]
cmd = sys.argv[2] if len(sys.argv) > 2 else ":set pause on"
delay = float(os.environ.get("DELAY", "0.002"))
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execv(repl, [repl, "--no-init"])
def drain(t):
    out = b""; end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.05)
        if r:
            try: out += os.read(fd, 65536)
            except OSError: break
    return out
drain(3.0)                                      # the banner and the first prompt
os.write(fd, (cmd + "\r").encode())             # the command
time.sleep(delay)
os.write(fd, b"val typedAhead = 40 + 2;\r")     # the next line, while it runs
out = drain(4.0)
os.write(fd, b"\x04"); drain(0.5)
txt = re.sub(rb"\x1b\[[0-9;?]*[a-zA-Z]|\x1b\][^\x07]*\x07|\r", b"", out).decode("utf-8", "replace")
ran = "val typedAhead = 42" in txt
cont = bool(re.search(r"^= ?$", txt, re.M))
print("ran" if ran else "NOT RUN", "| continuation prompt" if cont else "")
sys.exit(0 if ran else 1)

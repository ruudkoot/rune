# Two terminal tests race a resize against what the program has not yet done

Found 2026-10-25, from failures of `terminal/term-resize` and
`terminal/edit-complete` in `make check` at `d551f19dd` during the
functors-units roadmap, at loads of 30 to 44 (the machine shared with
another session's runs). Status: fixed 2026-10-29;
[fixes and regressions](../terminal-races-fixed.md). Run again at that load, both passed
once in three; at ordinary loads they pass.

## `terminal/term-resize`

The script (`tests/terminal/term-resize.script`) waits for `size 80x24`,
resizes the window to 100 by 30, and waits for `resized 100x30`. It waited
out its 20 s with the screen still at:

```
size 80x24
```

The program it drives, `tests/terminal/keys.sml`, prints the size and only
then reads the count of resizes it compares later ones with:

```sml
val () = say ("size " ^ sizeText ())
val () = loop (Terminal.resizes ())
```

A resize the script makes as soon as it sees the size line, before the
program has read the count, is in the count: `burst` compares each later
count with it, finds them equal, and never says `resized`. A slow machine
widens the gap between the print and the read. **A fix:** read the count
before printing the size (`val seen = Terminal.resizes ()` first, then
`say`, then `loop seen`).

## `terminal/edit-complete`

The later [under-load investigation](../terminal-tests-under-load/BUGREPORT.md)
established that the apparent missing row was the old drawing truncated by
the resize: no redraw happened. The fix preserves the original script and
its expected screen, and makes the runtime retain resize wake-ups.
The analysis below is the original, preliminary diagnosis.

The script (`tests/terminal/edit-complete.script`) types
`abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGH`, waits only for
`^> abcdefghij`, narrows the window to 20 columns, and wants the input drawn
again at the new width:

```
> abcdefghijklmnopqr
stuvwxyz0123456789AB
CDEFGH
```

It waited out its 20 s on:

```
> abcdefghijklmnopqr
CDEFGH
```

the middle row missing. Again on 2026-10-26 in `make check` at
`56c86ddd4`, at a load of 13 to 18, the same screen; it passed three times
in three runs after. The wait matches the first ten letters, so the
resize can come while the rest of the typed text is still arriving or being
drawn; what was seen fits a redraw at the new width that the keys after it
then extend from a wrong row. Not run down: it is either the editor's
drawing when keys follow a resize (`lib/terminal/line_edit_fn.sml`), which
would be a bug of its own, or the test's emulator. **To find out:** a script
that sends the tail of the text after the resize, on purpose. **For the
test alone:** wait for the whole input (`^> abcdefghij.*GH$` at the old
width) before resizing.

## The record

`build/test-history.tsv` of the check worktree keeps each test's last five
times and the times its verdict changed: `term-resize` and `edit-complete`
each changed 4 times, their failing runs 20.1 s (the screen wait's limit)
against a fraction of a second when they pass.

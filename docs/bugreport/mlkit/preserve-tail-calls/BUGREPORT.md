# MLKit 4.7.23 and 4.7.25: a tail call inside a `let` keeps a region and a frame alive for every step

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a
specification bears on.** A loop whose every step is a tail call, written
inside the `let` that makes a string, runs in constant space on MLton,
SML/NJ, Poly/ML and Rune. MLKit wraps the region of the string around the
tail call, so that every step keeps its region and its frame until the loop
ends: a million steps take 4.3 GB. MLKit's own option `--preserve_tail_calls`,
on by default and implied by garbage collection, says it avoids exactly
this ("Avoid the wrapping of letregion constructs around tail calls").

## Status: not reported upstream

Found on 2026-10-18 (docs/plans/utf8.md, E4 and M5), with the MLKit that
`~/.local/rune-hosts/mlkit` links to (4.7.23) and with 4.7.25.

## What happens

`repro.sml`, built with `$(SML_LIB)/basis/basis.mlb` and `repro.sml`:

```
$ mlkit -o r r.mlb && /usr/bin/time -f "%M KB" ./r
PASS
4316644 KB
$ mlkit -no_ri -o n r.mlb && /usr/bin/time -f "%M KB" ./n
PASS
2676 KB
```

MLton (1.5 MB), Poly/ML (24 MB) and SML/NJ 110.99.9 (24 MB) run it in
constant space. Under `ulimit -v 10000000` MLKit's program still passes,
but the same loop of three million steps stops at 5 GB with "I could not
allocate more memory ... Cannot allocate memory".

`mlkit -Psme` shows the region `r11` of the string bound around the call
of `go`, which is then no longer a tail call:

```
let fun go c =
        case c > 1000000 of
          true => true
        | _ =>
          let region r11:INF; val s = toString[atbot r11] c in go (c + String.size s - String.size s + 1) end;
```

It is the same when the test before the call is an `if` or an `andalso`
(`size s > 0 andalso go (c + 1)`), and when the loop returns `unit`. A
string made in an inner `let` that ends before the call
(`let val ok = let val s = ... in ... end in ok andalso go (c + 1) end`)
is popped before the call, and the loop runs in 3.5 MB.

## What it breaks

`tests/lib/unicode/utf8.sml` writes and reads back every scalar value in
such a loop (`let val s = Utf8.encode c in ... andalso go (c + 1) end`): on
MLKit `unicode.utf8` takes 7.1 GB, where the other compilers take a few
MB, and it fails with "Cannot allocate memory" where the machine cannot
give it that (under `ulimit -v 14000000`, as E4 of docs/plans/utf8.md ran
it). `tests/lib/deviations.txt` has a `HOST-FLAKY` line for it, since it
passes where the memory is there. The test is not changed for it
(AGENTS.md).

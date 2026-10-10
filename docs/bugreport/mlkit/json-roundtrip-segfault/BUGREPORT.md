# MLKit 4.7.23: a segmentation fault in the code of `tests/lib/json/roundtrip.sml`

**Class 1 of 4: a fault of the compiler or the runtime, which no reading of a
specification bears on.** The program compiles without a warning and dies
with `SIGSEGV` before it prints anything; MLton, SML/NJ, Poly/ML and Rune
run it to `PASS`.

## Status: not reported upstream, not reduced

## What happens

`tests/lib/run-hosts.sh mlkit` builds `json.roundtrip` from
`$(SML_LIB)/basis/basis.mlb`, `lib/random`'s two files, `lib/unicode`'s
`utf8_sig.sml` and `utf8.sml`, `lib/json`'s two files and
`tests/lib/json/roundtrip.sml`, and the program it makes dies:

```
$ ./mlkit-json.roundtrip
Segmentation fault (core dumped)
```

`gdb` stops in generated code, `L_selLab_EgTJnEFV2ACp8Yo5RMO6jd`. It is the
same when the seven files are copied to a fresh directory and built there,
so it is not the reuse of `MLB` directories of
[separate-compilation-reuse](../separate-compilation-reuse/BUGREPORT.md),
and the same with an unlimited stack.

## What was tried

* The test's four parts alone: the escapes, the errors of `decode` and
  the integers at the edges of `int` pass; the random round trips die.
* The round trips with the value drawn and not used pass; with it encoded
  (`Json.encode`), or printed by a small function that walks it, they die
  before the first value is printed, though that is printed and flushed
  before it is encoded.
* The drawing function copied into a program of its own, with a walk that
  counts the nodes of each value, runs to its end and counts right.

So the fault needs the test's own structure around the drawing and the
walk; it has not been made smaller than the test.

## What it breaks

`tests/lib/deviations.txt`, `native:mlkit | json.roundtrip`. `lib/json` is
not changed for it (AGENTS.md).

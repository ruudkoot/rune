# Command-line parser generator validation

All 56 primary smoke/normal cases pass on Rune's four engines at O0/O2 and six
native hosts at defaults. All twenty auxiliary invocations pass 112 assertions,
totaling 2240. Eight normal count samples agree under Rune's engine comparison
rules, including allocation. Six serial single fresh-process native smoke
samples pass after correctness prechecks. They are adapter diagnostics; existing
budgets and the default ten-sample policy remain unchanged.

The original GHC program completes all source repetition counts with empty
stdout. Separate RTS diagnostics show allocation scaling with repetitions,
so the translation retains repeated parsing/generation and per-block hashing.
A consumer-only observer forces the original hash, then captures full text and
channel selection without changing parser/generator algorithms.

Both finite text policies match nine complete source cases in text, block
hashes and output channels. The default input has 41 flag/type pairs, 62 output
blocks and 18794 generated characters. Seven invalid specifications agree with
the unmodified usage message. Tests cover corrupted/missing/extra blocks,
normalization, reader choices, exact hash wrapping, repetitions, early output
stop, shared text and an undefined suffix beyond a mismatching type prefix.

Generated text remains a persistent character list, with source continuation
composition and string-append order. The lazy policy defers text cells; the
strict policy materializes finite text. Literal comparisons preserve source
short circuiting. Four static auxiliary templates remain shared. Source Crown
Copyright 1992 and N. D. North/NPL attribution are retained. The earlier C
mkprog is explicitly a different implementation, not a duplicate import.

Final-source Rune O2 calibration passes the original normal 3800 repetitions
under both policies within its recorded resource guard. Large retains 18000;
full SML large validation remains unrecorded. Timed profiles use hashed stdout;
named-file channel selection is covered by auxiliary capture, without selecting
an append-file timing profile. Historical generated Haskell syntax is preserved.

The archive keeps original runs, observer changes, source fixtures, invalid
cases, allocation diagnostics, initial and final demand tests, guards, all
canonical attempts and samples. Compiled artifacts and heaps are excluded.
The full 1036-profile make check passes; validation.md links the transcript.
M4 remains in progress.

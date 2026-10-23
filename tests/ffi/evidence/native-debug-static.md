# Static-library DWARF regression

2026-10-23. The final static-libffi full run
`20261023-134115-3192404` exposed an oracle defect: the native debug checks
compared every linked compilation unit against Rune's bytecode locations.
The compiler expected 32,014 line transitions, while GNU readelf returned
35,443; the first extra transition was line 39 of `prep_cif.c`. The same
cause affected LLVM, `rt.interrupt_self`, and the launcher fault that must
reach the planted incorrect `addr2line` output. The failed full-run receipt
is retained; these focused reruns do not make that run clean.

[NativeChecks](../../runner/nativechecks.sml) now selects rows using the
half-open address ranges of generated Rune functions. `nm --numeric-sort
--print-size` supplies ELF text-symbol ranges, and the disassembled function
indexes require exactly one positive-sized symbol per Rune function. The
filter does not inspect source names or expected locations, so incorrect
Rune filenames, lines, and columns remain visible to the existing exact
comparisons. Linked C/assembly debug information remains intact. LLVM file
and directory maps reset at each `debug_line` table boundary.

The corrected checker was compiled with the final self-hosted compiler.
The six actual checks reused copied, unchanged static-linked executables
from the failed run, avoiding a rebuild that could change the evidence.
Both readers passed for all three programs, with no diagnostics and
byte-identical expected/actual location files:

| Program | GNU line transitions | LLVM file/line/column transitions |
| --- | ---: | ---: |
| Compiler | 32,014 | 42,591 |
| `dec.val_simple` | 23 | 28 |
| `rt.interrupt_self` | 717 | 907 |

The complete `NativeFaults.one()` suite also passed, including its real
launcher/cache/supervisor cases and the existing planted wrong-location
case. Thirteen added assertions exercise external C units before and after
Rune rows, reused LLVM file indexes, independent file/directory map resets,
half-open ranges, missing/duplicate/empty symbols, missing Rune rows, and
incorrect Rune filenames, lines, and columns. The fixtures explicitly
retain wrong Rune locations rather than filtering them by `.sml` suffix or
an expected filename list.

The ordinary acceptance commands are:

```sh
bin/rune-native-check native-debug bin/rune.stack.rbc
bin/rune-native-check native-dwarf bin/rune.stack.rbc
bin/rune-native-check native-debug tests/out/dec.val_simple.rbc
bin/rune-native-check native-dwarf tests/out/dec.val_simple.rbc
bin/rune-native-check native-debug tests/out/rt.interrupt_self.rbc
bin/rune-native-check native-dwarf tests/out/rt.interrupt_self.rbc
bin/rune-test run 'native/launcher/faults'
```

For this focused receipt, `RUNE_TEST_ROOT` and the working directory pointed
at the unchanged failed-run checkout so its ELF compilation directory
remained the source-location oracle. `RUNE_TEST_RUN` and `RUNEOPT_CACHE`
pointed at private copies in `runeffi-dwarf`; no active acceptance inputs or
caches were changed. The fault suite ran entirely in that private worktree.
The checker and fault controller were compiled from the changed SML files
with `--library test/runner --library digest` and their existing main
entrypoints (the fault main calls `NativeFaults.one()`).

[The machine receipt](native-debug-static.json) records the exact commands,
source and binary hashes, reader versions, private artifact paths, row
counts, and planted fixtures. GNU binutils 2.42 and LLVM 18.1.3 were used.
The full repository rerun remains the parent delivery's acceptance gate.

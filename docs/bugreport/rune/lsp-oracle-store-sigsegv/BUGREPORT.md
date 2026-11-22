# The LSP oracle's stored run died of signal 11 on a store a machine restart had cut

Found 2026-11-14, timing `make test-lsp-oracle` for the haskell98 lead. Status:
not reproduced, not fixed; the store that did it is gone.

## What happened

In hs-t at haskell98 `1e5c2c7e5`, the four steps of `make test-lsp-oracle` ran
one by one. The store step finished at 16:04:32:

```
bin/runevm --count --heap-size 67108864 bin/rune.rbc --lib "$PWD/lib" --units -O0 --build rune.build \
  --cache-dir build/lsp/store -o build/lsp/store.rbc
```

Then the stored run began, which reads that store and writes the editor's
sidecars into it (`tests/lsp/README.md`, *Keeping what is computed*). The
machine restarted at about 16:18, with every process, while that run was
still going. Its output stopped at 16:16.

At 16:20:34, the same run was started again on the store the restart had left:

```
bin/runevm --count --jit=opt --equality-work 1000000000 --heap-limit 4294967296 bin/rune-lsp-oracle.rbc \
  --lib "$PWD/lib" --build "$PWD/rune.build" --scenarios tests/lsp/oracle/rune.tsv --focus \
  --out build/lsp/oracle-rune-store.jsonl --store build/lsp/store \
  --require placed,walked,rebound,loaded,cutoff,broken,failed,cancelled,query,opened,stored,byneed
```

It ended after 805 s (664 s user, 77 s sys, 1.6 GB at its peak) with
`Command terminated by signal 11` and status 139. It printed 34 lines, where a
whole run prints 45. The last was scenario `mid-type`'s second repetition:

```
mid-type 2: 0.014 s, checked 1, reused 173, placed, rebound 0, loaded 0, cutoff 0, broken 0, diagnostic: .../lib/compiler/util/source.sml:7: val binding: type mismatch between {file : string, start : int, stop : int} and {file : string, start : int, stop : string} ...
```

So it died in the scenario after `mid-type` (`leaf-type`), or in the restore
of `mid-type`'s file between them. There was nothing on standard error but the
lines a run prints, and `ulimit -c` was 0, so no core.

Then the store was built again, with the same command, and the same stored run
passed: 1,079 s, 41 checks, 0 disagreements. Building it again removed the
store that had crashed the run. Load was 16 to 34 throughout.

## What it is not, as far as was tried

A signal 11 is the VM's own fault. A store that does not read raises an SML
exception, which the store's readers handle by refusing the entry: every
damage tried below was refused that way. So the store may have been only what
set off a fault of the VM's (its JIT at `--jit=opt`, its collector at a 4 GB
heap limit, or code that trusts what it has read), or the crash had nothing to
do with the store.

- **A store a timeout left.** `make check` kills the job at 3,600 s, often in
  the stored run. batch16's tree, at the same `1e5c2c7e5`, kept its store from
  13:09; a copy, run by that tree's own oracle, passed (950 s, 41 checks). An
  entry is written whole under another name and renamed
  (`lib/compiler/driver/unitstore.sml`), so a kill leaves none half-written. A
  restart is different, because no write is synced, so a renamed file can come
  back empty or cut.
- **Damage done by hand**, on copies of a store built in hs-t at `f97c003e3`
  (with its split of the oracle), whose sidecars one stored run had written.
  On each, `bin/rune --units -O0 --build rune.build --cache-dir COPY` and the
  stored oracle on three scenarios (`leaf-comment`, `mid-type` twice,
  `leaf-type`) were run. Every one ended with status 0, and every oracle run
  took the stored path:
  - sidecars (`editor/units/*`), each of them: made empty; cut in half; cut
    to one byte; made all zeros; the second half zeroed; the second half random.
  - the largest sidecar alone: made empty; cut in half; second half zeroed.
  - entries (the configuration's directories), each of them: made empty; cut
    in half; second half zeroed; second half random; all replaced by the first.
  - `memo` removed; `plan` removed; `about` and `trimmed` removed; every file of
    `memo` and `plan` cut in half; their second halves random.
- **Whole runs**, every scenario, on a store with every entry's second half
  zeroed and on one with every sidecar's second half random: both passed (41
  checks, 0 disagreements).

## What is left to try

- At `1e5c2c7e5` itself (batch16's tree has its binaries), rather than at
  `f97c003e3`. Between them is D15's eval/apply, which changed every engine.
- Damage that cutting a file does not make: zeros in the middle of a file, a
  directory entry with no inode, two stores' files mixed.
- Running the stored oracle many times on one undamaged store, at the load
  `make check` runs it at, to see whether signal 11 comes without any damage at
  all.
- On the next crash or kill: copy `build/lsp/store` aside before anything runs
  again. `test-lsp-oracle-store` removes it first, as it did here. Then run
  with `ulimit -c unlimited` and a VM built with symbols, so that the next
  signal 11 leaves a core.

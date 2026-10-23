# FFI measurement component — 2026-10-23

The opt-in `make ffi-performance` tool builds the native subject and its
independent direct C baseline, compiles the SML workers, alternates paired
execution order and checks every checksum. It retains commands and streams
and reports all samples with source/binary identities and per-phase medians.
No performance threshold is added to correctness checks.

Validation:

* Strict C17 `-O2 -Wall -Wextra -Werror -pedantic` subject and direct baseline
  compilation passed.
* A 100-iteration correctness smoke with collection stress 7 and heap
  verification passed all scalar, buffer and callback checks, ending with
  zero native resources. The generation worker passed ten deterministic
  input/analysis/emission/packaging repetitions.
* Three 100-iteration paired smoke samples passed, followed by five
  10,000-iteration samples and five **50,000-iteration** accepted samples.
* The accepted run explicitly selected register interpretation
  (`--jit=off`). All five direct C/Rune pairs agree with their independently
  calculated expected scalar, byte-mutation and callback checksums.
* The initial worker compilation exposed an integer/word mismatch in the
  resource-count assertion; it was corrected before any passing worker run.

The committed [raw report](performance-linux-x86_64.json) names measurement
tool commit `fb1d42cbc20015a99f1aedc301f985a660dc1c9e` and library snapshot
`8a94f13139be441e2410295269e742eaed1b8bb1`. It is component evidence, not
performance acceptance of later generator/runtime additions. Other builds
were active on the host; these are observed timings, not an idle-host
regression threshold. Direct C intervals are small and clock resolution
limits ratio precision. No aggregate performance score or GUI-throughput
claim is derived from them. M10 remains planned pending cumulative release
acceptance and final implementation measurements.

Reproduction from a complete checkout:

```sh
make ffi-performance FFI_PERF_OUT=tests/out/ffi-performance-new \
  FFI_PERF_ITERATIONS=50000 FFI_PERF_SAMPLES=5 FFI_PERF_MODE=off
```

For isolated worktrees the SML coordinator also accepts `RUNE`, `RUNEVM`
and `RUNE_LIB` overrides. The report records the actual library revision,
source hashes, worker bytecode hashes and VM/subject binary hashes.

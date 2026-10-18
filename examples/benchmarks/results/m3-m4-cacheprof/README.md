# Cacheprof GC and application validation

All four consumer/data-policy variants pass all 112 canonical smoke/normal
cases on Rune O0/O2 across stack, register, JIT and native engines and all six
managed SML hosts. The final bounded semantic target passes 822 assertions in
each of twenty invocations: 16440 pass, none failed or unreached. Native O0/O2
labels repeat host-default compiler settings.

Original complete annotated output agrees for all three supplied input sizes
in both policies. Original observations cover 299 synthetic cases: 286 accepted
and thirteen rejected. These exercise all 206 opcode/effect entries, applicable
arities, indirect forms, source locations, repeat expansion, peepholes and three
profiling levels. Independent evaluated metadata confirms all 67 original
nonJumpy members. The original explicit list/order is retained.

The pinned GC stdout fixture exactly matches the unmodified original fed the
13708-line full input reservoir. Its current 600-line default input naturally
produces a shorter result. Preserve both identities and that concrete pairing:
GC large uses the complete golden pair; normal uses reviewed current-input
output. Raw GC checks/emits hook text; the real consumer fully validates
annotated output while retaining per-iteration unused-hook open/close.

Original prefix observations verify that level zero can emit a leading comment
without parsing an invalid later instruction, while level two's global location
guard must inspect it. Memoized heads, strict materialization, unchanged
persistent stage data, driver output, zero work and deliberate corrupt/truncated
result controls pass. No assembly or hook code is executed.

An initial mixed 824-assertion target passes 8232 assertions over ten O0/native
invocations and then leaves eight incomplete when ML Kit exhausts the 1 GiB
limit in strict full-reservoir result materialization. No wrong assertion is
accepted. Preserve that raw failure and its exact test subject separately.

The final bounded target separates those large inputs. Four explicit large
checks—both materialized outputs and both streaming GC drivers—pass on ML Kit
at the declared 8 GiB large-profile limit. The guarded combined process tree
peaks at 1235728 KiB and exits zero without interruption. Kernel and expected
bytes are unchanged; this is not a new all-host/all-large claim.

All sixteen full-normal Rune count samples agree; all four guards exit zero
without interruption. Twelve serial single fresh-process native smoke samples
pass before heavy validation, including their correctness preflights. They are
adapter diagnostics, not ten-sample comparative performance claims.

The full 200-repetition normal application pilot passes both policies and both
raw consumers without guard interruption. Full final SML large-profile runs
across configurations remain unrecorded beyond the explicit ML Kit probe.

All 124 inventory regressions and the five-pin 861-entry replay pass. Guarded
individual notices credit Julian Seward; complete original GPL2-or-later
notices, supplied COPYING text, input origins, hooks, source identities and
distinct failed development assertions are retained. The public semantic shell
target passes Rune O0/O2. Full repository acceptance is recorded separately.

Repeated fixture copies inside per-configuration semantic/large directories
are represented by input-identities.tsv, input-groups.tsv and input-copies.tsv.
Every omitted copy was byte-checked against the committed canonical fixture
before removal. These tables retain its original relative path, configuration
directory, length and SHA-256; copy the listed group from the canonical paths
to reconstruct that working directory. Raw stdout, logs, drivers and commands
remain per invocation. The archive omits 28138 redundant files (113599738 bytes).

Full make JOBS=4 check exits zero with 1367 catalogue profiles, including
all compiler, runedoc and runeopt cross-build comparisons. Large/host scopes
not explicitly recorded above remain outstanding.

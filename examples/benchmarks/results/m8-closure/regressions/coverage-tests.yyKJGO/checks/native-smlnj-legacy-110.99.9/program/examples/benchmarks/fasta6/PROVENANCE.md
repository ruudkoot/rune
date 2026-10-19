# fasta6 provenance

Sandmark revision 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/fasta3.ml and fasta6.ml. Both headers credit Troestler
Christophe and Mauricio Fernandez; fasta3 credits Tony Tavener's Bytes changes,
and fasta6 credits Fabrice Le Fessant and Roman Kashitsyn. Retain each complete
source, build/run data, directory Revised BSD notice and aggregate Unlicense.
The ALU sequence and probability tables are embedded program literals, with
no separately acquired dataset or additional dataset notice. Their exact
source origins and the reference-cycle acquisition are recorded.

## Algorithms, variants and numeric semantics

Both programs print repeated ALU data, then IUB and Homo sapiens random sequences.
The reference seed is 42, widths 60 and lengths 2n/3n/5n. Preserve every RNG draw,
the original cumulative distributions and seed continuity across random blocks.

fasta3 builds a 61-byte line buffer, scans cumulative probabilities from zero,
and evaluates max*Real.fromInt(state)/139968. fasta6 uses reciprocal
multiplication, begins lookup on one side of the table midpoint, and allocates
a complete n+ceil(n/60) output buffer for each random block. It passes its seed
explicitly, while fasta3's source uses a global ref. Both algorithms remain
separate; identical reference output does not make them implementation duplicates.

Real operations use binary64 in source order. These OCaml variants differ from
the separately imported nofib fasta's explicitly binary32 table arithmetic;
that lookup implementation is not substituted. The integer recurrence's largest
intermediate is542681632, below the signed 31-bit bound. All selected sequence lengths,
indices and byte counts also fit 31 bits. Source Char/Bytes ASCII values are
represented by SML char values, arrays and CharArray buffers. Generic real/char
arrays may have different boxing/storage from OCaml arrays.

## Portable translation and output

One SML97 module shares immutable data, integer RNG stepping and circular output
support. Each variant keeps its own CDF construction/search and buffering.
The circular writer preserves a returned index equal to source length, including
the next empty wrap segment. Fasta6 copies ALU into a mutable CharArray as in its
Bytes.of_string input. Its output array receives the defined initial value
required by SML97; the source Bytes.create leaves its subsequently overwritten
contents unspecified. This adds an explicit initialization pass.

Output callbacks consume original text slices, mutable buffers and individual
characters without allocating a full immutable copy of the large buffers.
The exact checker replaces stdout IO, with its comparison cost included in
execution. Fasta3 resets its global seed at the suite call boundary to reproduce
fresh-program semantics during repeated execution. Fasta6 already carries its
seed locally. The suite requires an explicit input instead of fallback 1000.

## Profiles, oracle and references

Smoke 151 exercises wrapping and partial lines; normal 50000 covers a complete
RNG period for both distributions; large 25000000 preserves the published input.
Original OCaml and an independent periodic reference agree byte for byte/SHA256
on all selected complete outputs, including the large streams. All 139968 RNG
states are distinct before returning to 42. Original cycle observers and an
independent Python distribution builder agree on every state for each variant.
The two current variants have identical complete character cycles.

The SML checker uses only reviewed cycle bytes, ALU data, indices and a line/header
state machine. It does not rerun the RNG or cumulative-probability algorithm.
Every emitted byte, seed handoff, line break, header and final boundary is checked,
including large outputs without storing those outputs as fixtures. The retained
cycles/data are machine-identified oracle files, copied into controlled working
directories. Oracle loading/storage and per-byte checking are documented costs.
Nine semantic checks cover source smoke fixtures, line/ALU boundaries, reset,
cycle agreement and corrupted/truncated/extra output rejection. Large SML
execution is claimed only where explicitly recorded.

The retained Benchmark Game sources and shared measurement survey provide
history/context. RNG arithmetic, CDF search, buffer sizing, generic array layout,
initialization and IO/checking costs are source-based questions until established
by measurement or compiler inspection. Standard comparisons use identical SML;
OCaml supplies correctness references. No historical timing claim is transferred.

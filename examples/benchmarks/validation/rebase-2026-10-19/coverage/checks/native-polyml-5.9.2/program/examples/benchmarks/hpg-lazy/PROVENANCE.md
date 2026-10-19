# Haskell Program Generator provenance

## Algorithm and workload

Generate algebraic types, values and expressions using an immutable
continuation-passing environment, seeded random choices and infinite name
streams. Render the header, declarations and generated test program as three
source chunks. Hash and print each chunk on every one of 100 repetitions.
This workload generates Haskell text; it does not execute the generated test.

## History, authorship, revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/hpg.
The retained hpg.tex manual names N. D. North of the National Physical
Laboratory; MAIL identifies Nick North and the early distribution history.
Retain the 1991/1992 Crown Copyright module/manual notices individually.
The pinned version is 1.20 dated 92/07/20. Historical correspondence is not
treated as an additional general licence grant. README.nofib records the
disabled random-number debug printing; upto still forces each chosen integer.

## Known variants

hpg-lazy memoizes finite types, values, expressions and environment lists.
hpg-strict materializes those finite fields eagerly. Both keep lazy control
for infinite RNG/name streams, candidate continuations and prefix-consumed
Cartesian index enumeration. Unselected continuations do not run. Source
Integer/Float/Double tags in generated values retain their original Int-valued
payload; they are not replaced by another generator or arithmetic workload.

## Translation and adaptations

Preserve character-list identifiers and the globally shared constructor/type/value
name streams across environment creations. Keep the eight-field immutable
environment, random-consumption order,
weighted/rejected choices, lambda push/pop, declaration insertion and printing.
Even a one-candidate function list consumes a random draw. Preserve initial
seeds (9807,65,32975), including the unnormalized initial third seed; emit the
initial combined value before advancing seeds.

RNG operations round after every binary32 operation, with truncation at the
same points as the source. The reused finite-binary32 helper's selected
zero/normal domain covers these bounded calculations. All selected counters,
numeric payloads, seed products and names fit signed 31-bit integers; modular
64-bit hashing and its signed rendering are explicit.

Candidate continuations are suspended as control. Cartesian enumeration
retains the source nested-product algorithm, re-evaluating suffix products
at the original positions. The portable control loop discards completed
empty branches without retaining a chain of deferred administrative steps.
Finite attributes retain their selected policy. No product sharing,
algorithm replacement, input reduction or guard increase was used to obtain
agreement on the large case. Preserve ShowS composition, split_str at 70
characters, Haskell punctuation, numeric tags, character escapes and spaces.

## Profiles and validation

All profiles retain 100 source repetitions. Parameters are:
smoke nt=8, dt=4, nv=10, dv=6, de=6;
normal 40,5,60,6,6; large 80,8,100,8,8.
These are the original FAST/NORM/SLOW options, with default seeds and Main
module name. The manifest records three independent chunk digests per profile.
All generated chunks are retained as full reference files. Default limits
apply unless a later override is recorded explicitly.

Private GHC observations agree on all 18 complete chunks (three profiles,
three chunks, two policies), including the 121341-byte large declaration
chunk and 221465-byte large test chunk. All 10000 observed binary32 RNG words
agree exactly. The original 100-repetition smoke driver passes locally.
Earlier failed translation attempts and unchanged guard interruptions remain
preliminary evidence; they are not large-workload limit failures.
Public profile, count and repository acceptance checks are recorded below.

## Runtime questions and literature

Continuation construction, captured environments, recursive types, weighted
choices, symbolic output and retained sharing are source-based diagnostic
questions. The source manual hpg.tex and included module documentation are the
benchmark-specific account. The RNG's reference is
[Wichmann and Hill (1982)](https://academic.oup.com/jrsssc/article/31/2/188/6985277).
Its bibliographic context does not establish a Rune performance result.

### Compilation and execution phases

SML/NJ exported images evaluate declarations while the image is built.
Global tables and memoized streams can therefore enter the compilation
phase. Record build and fresh-process execution separately and interpret
them together. Repeated execution retains source global sharing and does
not imply steady state. Profiling/count instrumentation runs separately.


### Recorded public validation

The [application-wave evidence](../results/m4-parser-reptile-hpg-fluid/README.md)
records smoke/normal checks at O0/O2, all applicable Rune engines, supplied SML
hosts, independent semantic assertions, normal allocation counts, serial
adapter diagnostics and full repository acceptance. All 128 Rune profile
combinations pass. Host failures remain explicit; this link does not imply
that every host or the full large matrix passed.

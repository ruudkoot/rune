# mandelbrot6 provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/mandelbrot6.ml. The header credits Paolo Ribeca and
its earlier OCaml 3 ancestry to Christophe Troestler, Christian Szegedy and
Yaron Minsky. Retain that header and the directory Revised BSD notice with
its original CRLF bytes. No external image/input dataset is acquired.

## Algorithm and variants

Render the source viewport with zr/zi/trmti scalar refs, at most 50 iterations
and strict squared escape test >4. Preserve zi-before-zr updates, cached previous
square difference, increment order and per-pixel Exit exception/handler.
A successful last iteration sets the bit; an escape clears it. Emit the exact
binary P4 header, MSB-first bytes and zero-padded final row byte.

The source carries one shifting int accumulator across all rows without reset.
Only its low eight bits reach output_byte. The port uses Word8 shifts/or with
modulo 256 truncation, preserving every observed byte while making machine-width
arithmetic portable. Do not replace it by a signed 31-bit accumulator that can
overflow. Keep the shared accumulator, odd-width padding and exception pattern.
Other classic/nofib Mandelbrot programs have different viewport/iteration/data
representations and remain separately named.

## Profiles and result checks

Smoke 17 explicitly exercises partial bytes; normal 256 is reduced comparative
work. Large preserves the selected 16,000-square source run. Inputs use the
same coordinate division and fixed 50-step limit, with no clock-dependent search.
All selected counters fit 31 bits; numerical operations use binary64.

A thin emit callback replaces output_byte. It reads and compares every expected
PBM byte through SML97 BinIO, then requires EOF. Streaming verification keeps
memory bounded rather than retaining the full image; expected-file I/O and
comparison are measured work. The source's diagnostic header and bit encoding
remain exact. The final result reports width:checked-bytes. There is no
floating error tolerance that accepts a different classification bitmap.

Original images at 1/7/8/9/16/17/64/256 and 16,000 have verified headers, sizes
and identities. An independent direct-complex iterator with separate row-bit
packing agrees on every byte through normal size. Full 32,000,015-byte large
source image is retained. Large SML execution is claimed only where explicitly
recorded. Numeric roundoff near escape boundaries is therefore observable.

Semantic/negative checks cover every small image, aligned and partial rows,
perturbation (including padding), truncation and extra bytes. No SIMD batching,
algorithmic symmetry, alternate inside test or skipped output replaces the
source. Float refs, loops, exceptions, byte arithmetic, branch behavior and
stream I/O are source-based diagnostic questions until measured or inspected.

## References

The [Benchmarks Game Mandelbrot description](https://benchmarksgame-team.pages.debian.net/benchmarksgame/description/mandelbrot.html)
provides problem context; the retained source defines this 50-step approximation
and output convention. Standard reports compare identical SML, with OCaml and
independent complex arithmetic as correctness references.

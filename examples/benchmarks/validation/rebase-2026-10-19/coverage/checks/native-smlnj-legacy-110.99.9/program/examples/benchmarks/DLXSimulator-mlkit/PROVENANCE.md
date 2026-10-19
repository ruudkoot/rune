# DLXSimulator-mlkit provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/DLXSimulator.sml`.
Matthew Thomas Fluet, Harvey Mudd College; Stephen Weeks benchmark driver,
Martin Elsman 2001 repetition adjustment. Individual source notices and
aggregate ML Kit notice are retained.

Simulate the DLX RISC instruction set with immutable register/memory arrays,
cache bookkeeping and decoding. This older version uses a three-component
PC/register/memory state and direct I/O instructions. The newer MLton version
carries a fourth trap state with general input/output callbacks and selects
five programs. Preserve the old simulator kernel and its Simple-only workload.
Smoke/normal/large run Simple 1/10/100 times; 100 is the original count.
The program loads hexadecimal 0x2F (decimal 47) into register 14, traps to output it and halts: review
its instructions and require every output line to equal `Output: 47`.
Legacy Word.fromLargeWord calls become Word.fromLarge(Word32.toLarge ...);
pre-SML97 string inputLine is explicitly unwrapped. Quiet statistics/progress
and capture actual trap output; unsupported input is not used by selected
programs. Preserve Word32 modular arithmetic and signed register interpretation.
Immutable-array/caching costs are source hypotheses, not measurements.
The individual header references Patterson and Hennessy, Computer Architecture:
A Quantitative Approach, second edition (1996); see [literature](../literature.md).

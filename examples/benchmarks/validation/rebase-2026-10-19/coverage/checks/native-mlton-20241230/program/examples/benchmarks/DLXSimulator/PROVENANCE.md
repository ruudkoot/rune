# DLXSimulator provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/DLXSimulator.sml`. Original, adaptation patch and notices retained.

DLX instruction simulator with the five original programs (Simple, Twos,
Abs, factorial 12, GCD). Retains instruction decoding, memory and pipeline
model. Every simulated program output is returned for every invocation;
statistics printing is removed. The arithmetic outputs have independent
mathematical checks. Full instruction fixtures remain embedded upstream.

Smoke execution exceeded its initial 30-second quota on Rune. Its explicit
limit is now 120 seconds; normal repeats the full five-program set twice.
The timeout is retained in validation records, not counted as a passing run.

The source credits Matthew Thomas Fluet (Harvey Mudd College) and updates by
Stephen Weeks and Matthew Fluet; all header notices are retained.

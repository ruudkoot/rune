# vliw-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/vliw`.
All ordered modules, notices and original assembly data are retained.

Read ndotprod abstract assembly, build dependency nodes, schedule/compress
instructions with window nine and emit uncompressed/compressed assembly.
Preserve the modern modular implementation, custom sets/maps, sorting,
delay/idempotency logic and source input. Smoke/normal/large repeat the full
workload 1/3/250 times; 250 is the original modern count. The older monolith
uses a different launcher and contains historical runtime adapters.
Hide the BMARK launcher ascription to call the existing parameterized run;
suppress debug progress, close input/output files and validate every emitted
instruction from independent original fixture streams. Normalize GETREAL
literal spelling to an exact binary64 mantissa/exponent so numeric formatting
differences are accepted without accepting a changed value or instruction.
No simulator feature is added: upstream disables SimStuff.cmprog itself
because it raises Subscript. Scheduling/allocation/window effects are source
hypotheses, not measured performance causes. See [literature](../literature.md).

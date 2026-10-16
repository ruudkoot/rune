# Mutable-record n-body and streamed Mandelbrot bitmaps

Recorded 2026-10-16. Two imports bring the catalogue to 272 programs and
810 profiles. All 56 smoke/normal cases pass on Rune's four engines at both
levels and all six managed native hosts. Twenty semantic/negative checks pass
all ten configurations at both levels. Eight normal count samples pass the
combined comparison with unchanged budgets. Six serial native smoke samples
also validate MLton, SML/NJ and Poly/ML adapters. These single-sample diagnostics
and instrumented counts are separate from headline timings.

N-body retains mutable records, exact source constants, momentum/energy order,
force-product association and velocity-before-position updates. Every check
consumes initial/final energies and all 35 body fields. Original full-precision
states include the selected 50,000,000-step input. Independent 60-digit integration
validates complete zero/smoke/normal states and momentum; normal maximum state
error is about 6.8e-12 and energy error 5.3e-16.

Mandelbrot retains float refs, cached square differences, source stopping,
per-pixel exceptions, carried byte accumulator and P4 layout. Modulo-256 Word8
operations preserve observed low bytes. BinIO compares every emitted byte and
EOF with bounded memory. Independent direct-complex/row-packing results agree
on every byte through the normal size, including odd widths. The complete
32,000,015-byte original large fixture is retained in the benchmark directory;
its identity is recorded here without a second archive copy.

Raw results, complete semantic logs, source/output identities, original sources,
observers, independent references and exact Revised BSD notices are retained.
Negative checks reject physical-state errors and corrupted/padded/truncated/
extra bitmap data. Input/reset/representation and validation costs are documented.
No prerequisite compiler/runtime feature or universal large SML execution is
claimed. M5 remains in progress.

# Byte-key nucleotide counting

Recorded 2026-10-16. All 28 selected smoke/normal cases pass across Rune's
four engines at both levels and all six managed native hosts. Sixteen semantic/
negative checks pass all ten configurations at both levels. Initial sandbox
attempts could not launch native32 (SIGSYS); exact replays outside that filter
pass. Original attempts remain distinguishable from canonical results.

Four normal count samples agree; existing budgets are unchanged and these
new profiles are currently unbudgeted. Three serial native
smoke samples validate MLton, SML/NJ and Poly/ML adapters. These single-sample
diagnostics and instrumented counts remain separate from headline timings.
Complete original outputs agree with an independent dictionary-based counter
at smoke/normal/large. Source-specific edge fixtures, malformed-input rejection,
256 independent four-mer counts through forced collisions/multiple resizes,
per-length clearing and bad/truncated/extra output checks are retained.

The port keeps byte keys, copied insertion keys, mutable counters, source hash,
clearing, chain order, resizing threshold, sort comparison and formatting.
All sequence/table state is initialized per call, and every output byte/EOF is
validated. The pinned OCaml library sources match the installed originals;
their LGPL notice/linking exception and the kernel's BSD notice are retained.

Original knucleotide3 outputs and independent packed-key/cumulative-table
replays document its omitted final window and retained cross-length counts.
That materially different variant is not claimed imported by this wave.
Generator parameters, source-specific behavior, representation/library costs
and original default inputs are explicit. No prerequisite compiler/runtime
feature or universal large SML execution is introduced or claimed. M5 remains
in progress.

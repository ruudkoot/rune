# model-elimination provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/model-elimination.sml`. Original, adaptation patch and notices retained.

Joe Hurd's September 2002 model-elimination benchmark, using the embedded
Metis code and original first-order problem sets. Preserves meson settings,
problem pruning, CNF normalization choices, clause machinery and scheduling.
Select a prefix of the original problem order and impose the existing
inference meter instead of a CPU-time limit. The count-reference Timer
adapter advances by 100 microseconds per observation and is reset per run;
scheduler readings are deterministic. Slice and overall limits are inference
counts. This stopping/scheduling adaptation is explicit, not a clock claim.
Consume each actual prover result as name/proved-or-unknown; a returned proof
must have an empty clause. Runtime exceptions propagate. Unknown under a
work limit is distinguished from a proved theorem in the result trace.
Reference traces come from the pinned SML program with these documented
work limits on MLton, and are reviewed problem by problem.

Suppress diagnostic printing while retaining the result trace. Smoke stops
P26 as unknown under 1000 inferences. Normal proves nine of the fourteen
selected problems under 50000; large proves all fourteen under 200000.
The three reviewed name/status traces accompany the expected digests.

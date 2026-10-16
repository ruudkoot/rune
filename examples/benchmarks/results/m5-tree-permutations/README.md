# Sequential tree and permutation workloads

Recorded 2026-10-16. Two imports bring the catalogue to 256 programs and
762 profiles. [All 84 smoke/normal cases](correctness.tsv) pass for the two new
programs and the refactored classic tree benchmark, on four Rune engines at both
levels and all six managed native hosts. Twelve normal count samples pass a
combined SML comparison. Counts remain unbudgeted; instrumentation times do not
provide headline timings.

The tree datatype is shared with classic binary-trees. Its generator and leaf
shortcut remain unchanged. The Sandmark variant retains explicit right-first
construction/traversal and calls on Empty children. Complete output agrees with
the original OCaml program and independent complete-tree formulas. Eight actual
checker/semantic tests pass all ten configurations at both requested levels.
No custom GC/keepalive facility or allocator is introduced.

The sequential permutation source partitions work into 32 chunks. Its pinned
-unsafe build reads/writes past the counter array during the unused terminal
transition. The checked original fails on input 3; an observer locates that
access. The SML port adds a reviewed terminal guard while retaining every call,
the preceding mutations, optimized flip loop and source zero-first convention.
Corrected checked OCaml and independent managed-MLton references agree at edge,
smoke, normal and large sizes. Chunk bounds and global prefix ranges establish
the selected integer-width assumptions. Full repair/source/compiler evidence is
retained. Ten semantic/negative-check tests pass all ten configurations at both
levels. This does not certify the original unsafe program.

The initial combined tree test failed to compile on ML Kit 4.7.23 with
DropRegions.filter_bl while the kernel and test had the same basename. Distinct
test filenames compile and pass. The original crash transcript remains under
binarytrees5/initial-semantic-attempt/ and initial-mlkit-log; benchmark kernels
were not changed to resolve that adapter issue. No broader root cause is claimed.

Program/dataset origins, individual directory notices, exact source bytes,
default/selected parameters, output-checking costs and representation changes
are documented. The original depth-21 and size-12 references are available;
large execution of the new SML ports is claimed only where explicitly recorded.
M5 remains in progress.

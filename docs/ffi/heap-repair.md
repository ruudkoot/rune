# Large-object ownership repair — 2026-10-22

The original-header oracle introduced by Runeffi reads Clang AST JSON of
about 135 MiB. This exposed an existing heap ownership fault, independently
reduced to `tests/lang/rt.gc_large-metadata.sml`: two 64 MiB character
arrays/strings and an explicit collection. Before the repair, heap
verification fails at collection 2. The full oracle also crashed in
`mark_value`, reading table bytes as object fields; ASan/UBSan and a debugger
backtrace confirmed the invalid object header.

`chunk_of` obtains ownership by masking an object's header address to its
2 MiB chunk boundary. Tables proportional to a very large mapping had
pushed the payload beyond that first chunk. Very large mappings now keep
the fixed-offset cards and dirty bytes before their payload and place the
remaining tables after it. An explicit capacity excludes the trailing
metadata from allocation. Ordinary chunks and compiled barrier offsets
retain their layout. Copying-space dedicated runs also close at the
object's boundary, so a later header cannot occupy alignment slack beyond
the first chunk.

The reduced case passes with `--gc-verify` on stack/register VMs, sanitizer
VMs, and the copying collector selected by `--nursery 0`. Native executions
also pass on Windows x86 and x86-64, Linux x86, big-endian PPC64 and AArch64.
The original frontend oracle passes ASan/UBSan after the repair.

The full repository run completed 19,383 cases: 19,379 passed, three known
skips and one host-inventory guard failure caused by the new library.
Updating that guard to 25 programs and requiring the frontend entry passed
a focused 6/6 rerun. The host matrix completed 3,338 cases with 3,182 passes
and 156 documented unsupported-extension skips. Windows and portability
builds passed. Commands and remaining frontend gates are recorded in
`tests/ffi/evidence/m1.md`.

A redundant sanitizer run that verified the entire growing heap while
reading the full 135 MiB oracle was stopped after 22 minutes. It is not a
passing result; the reduced case supplies the direct heap-verification
regression, and the unreduced case supplies the sanitizer reproduction.

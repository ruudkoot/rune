# Opaque allocation and stack probe fixtures

The four OCaml sources retain exact Sandmark bytes from revision
5605805954a00497ed197c930641cddd580e1507, benchmarks/simple-tests/.
Their individual source author and additional license grant are unstated.
The aggregate upstream Unlicense is retained in LICENSE.md.

These fixtures exercise inventory classification rather than runnable SML
benchmarks. Each probe uses Sys.opaque_identity to preserve otherwise discarded
calls or allocations. Source digests guard the reviewed dispositions; changed
sources and unreviewed paths require fresh review. Algorithmic uses of opacity
are not classified by keyword alone.

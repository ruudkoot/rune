# mlyacc provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/mlyacc.sml`. Original, adaptation patch and notices retained.

Classic SML mlyacc application from the SML/NJ tools, through MLton.
Preserves the full generator and original SML grammar/lexer input. Uses fixed
relative filenames to remove host working-directory identities from output.
Every generated source/signature/report is byte-exact checked against the
pinned source compiled by MLton. The fixture comparison and file reads are
included in the workload; compilation of the generated source is separate
validation. Original input notices are retained.

Array.sub and Array.update are explicitly rebound after each combined
Array/List open. SML/NJ adds List.sub and List.update extensions; these
otherwise shadow the intended array operations. The binding change selects
the original mutable-array operations, without a kernel rewrite.

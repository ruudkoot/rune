# Final generator bytecode agreement across seven compiler builds

2026-10-23. All seven delivered Rune compiler variants compiled the same
56 relative source arguments from `runeffi.build`, with the same options,
working directory, and library tree. They ran serially, writing bytecode
and logs only under `/tmp/runeffi-seven-hosts`. Every invocation returned
status 0 and produced nonempty, byte-identical output:

| Delivered compiler | Output bytes | Result |
| --- | ---: | --- |
| MLton | 868,680 | matches delivered generator |
| SML/NJ legacy 64-bit | 868,680 | matches delivered generator |
| SML/NJ legacy 32-bit | 868,680 | matches delivered generator |
| SML/NJ development | 868,680 | matches delivered generator |
| Poly/ML | 868,680 | matches delivered generator |
| MLKit | 868,680 | matches delivered generator |
| Rune self-hosted | 868,680 | matches delivered generator |

Every output has SHA-256
`9144040b994bba876d34a90c0ee905efa56a29bf6827f1b25cf6323fcb5641ba`,
the hash of the delivered `bin/runeffi.rbc`. The explicit source sequence
was checked against both the current build file and the earlier two-way
[bootstrap receipt](final-generator-bootstrap.json); all 56 source hashes
remain identical. This extends that receipt without relabeling it.

The input freeze covered 747 files: explicit sources, the build file,
delivered compiler wrappers/binaries/heaps, the self-hosted compiler and VM,
the delivered generator, and every library SML source, `library.build`, and
`MANIFEST`. Hashes before and after were identical; no main-checkout files
were modified. SML/NJ 32-bit ran outside the restricted sandbox.

[The machine receipt](final-generator-seven-hosts.json) records all seven
commands, statuses, output sizes and hashes, timings, compiler assets,
source hashes, and the complete input-map digest before and after. Full
per-file freeze maps and raw logs remain at the recorded private temporary
paths. This gate compares generator bytecode; the separate generator host
and native Windows receipts cover executing the generator and its output.

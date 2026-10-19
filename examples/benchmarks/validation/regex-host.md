# Legacy SML/NJ lazy-regex observer

Recorded 2026-10-03 on the managed `make hosts` builds. The selected expression
expands 622080 characters; original GHC, independent Cartesian-product hashing,
MLton, Poly/ML, all four Rune engines and SML/NJ 2026.2 produce the signed
64-bit hash `~1989802086544331776`.

A read-only observer of the unchanged lazy port prints these values on three
fresh legacy 110.99.9 processes, each still with character count 622080:

| Attempt | Legacy hash | Modern 2026.2 hash |
|---|---|---|
| 1 | ~2510343298014682496 | ~1989802086544331776 |
| 2 | 4534140575926827253 | ~1989802086544331776 |
| 3 | ~4373229627267849429 | ~1989802086544331776 |

The benchmark rejects that output. The observer is diagnostic, not a correctness
approval; its loader-success marker in the original logs does not validate the
hash. [regex-host.sml](regex-host.sml) observes the same calculation and reports
zero correctness checks. Load the ordered lazy-regex manifest sources, replacing
`shared/main.sml` with this observer; no Rune Basis or benchmark workaround is
required to reproduce the host difference.

The nondeterministic pure result establishes an incorrect legacy-host execution.
The known [GC-root defect](reference-hosts.md) affecting untagged Word64 values is
a candidate explanation; this probe does not isolate the exact GC/calling-
convention fault. No alternate hash fixture, relaxed check or source workaround
has been introduced. These failures cannot contribute timing samples.

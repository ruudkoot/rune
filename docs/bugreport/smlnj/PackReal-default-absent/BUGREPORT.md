# Optional default-real packing structures absent in SML/NJ

Confirmed 2026-10-23 with the repository's SML/NJ 110.99.9 64/32-bit and
2026.2 hosts. These native Basis installations provide `PackReal64Big` and
`PackReal64Little`, but do not bind `PackRealBig` or `PackRealLittle`.
Those structures are optional Basis facilities; this is an availability
limit, not a language or compiler-correctness claim.

The minimal probe is:

```sml
val _ = PackRealBig.bytesPerElem;
val _ = PackRealLittle.bytesPerElem;
```

Each host reports an unbound structure. `ForeignBytes` uses the default-real
packing interface for its SML `real` arguments and checks its width before
claiming a binary64 representation. Its native-host suite is recorded as
`HOST-ABSENT` on these hosts. Rune's Basis supplies both structures, so
compiling the library with each host against Rune's Basis is a separate
acceptance path. Substituting SML/NJ's sized structures would also encounter
the separately recorded native `PackReal64Big`/`Little` byte-order bug in
`tests/basis/deviations.txt`; no byte-order workaround is added here.

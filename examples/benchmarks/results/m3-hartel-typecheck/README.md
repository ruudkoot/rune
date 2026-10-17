# Functional-substitution typechecker validation

Both ports pass all 56 primary smoke/normal cases across Rune O0/O2 engines and
six managed native SML hosts. Twenty semantic invocations pass all 28 assertions:
560 passing assertions, none failed or unreached. Eight full normal Rune count
samples agree. Six serial single fresh-process native smoke adapter samples pass
separately from instrumentation and comparative performance claims.

Original GHC matches all FAST/NORM/SLOW fixtures. Export-only observers record
eight exact inferred rows, six further expressions and substitution/name/scheme
edge cases. Callable substitutions, right-to-left unification, source constructor-
arity truncation, reversed duplicate order, shadowed environment lookup and
recursive-let stages remain. A deliberately changed int/nit row has the same
weak checksum but fails exact per-row validation. Both child policies retain
source failure demand and memoized substitution; global AST/name-supply sharing
is explicit, without adding a result cache across repetitions.

Normal keeps 5000 repeats and large 25000; smoke reduces FAST's 500 to one.
The original checksum is retained and every inferred row additionally compared
with reviewed text. All counters fit signed 31-bit arithmetic in these profiles.
Full final SML large repetitions remain unrecorded. Earlier private normal pilots
are development evidence; canonical checks use the final shared initial supply,
standalone checksum helper and registered source identities.

Full make JOBS=4 check exits zero with 1171 profiles and all compiler/runedoc/
runeopt cross-build comparisons. Raw original sources/compatibility shim, fixtures,
process outputs and measurement metadata accompany this report. Remaining Hartel,
nofib application and Sandmark entries are unfinished work.

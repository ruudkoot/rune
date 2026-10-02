# kitmolgard provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kitmolgard.sml`.
Generated CPN/Design simulator, Niels 2001-02-17 benchmark adaptation.
Individual source history and aggregate notice are retained. No model-author
name is supplied beyond the source history; do not infer authorship from
this filename. The _smlnj source differs only in launcher/legacy Basis/time
adapters, all recorded and retained with the same simulation implementation.

Simulate the four-transition counting/logging coloured Petri net with the
original markings, bindings, random transition selection and mutable tables.
Seed 87 is explicit upstream state and is preserved per invocation. Select
100/10000/100000 counting transitions per batch and five completed batches;
large preserves actual upstream maxcnt=100000 and report indices 0..5.
The header's "25 lines" description is stale; the code stops at index 5.
Replace process exit with a loop-stop flag so results can be consumed and
repeated. Replace wall-clock elapsed seconds in diagnostic clock tokens by
zero for the initial full marking, then one logical second per completed batch; this clock does not decide which
transition is enabled. Batch counter/marking logic and RNG draw order stay
unchanged. Parameterized deterministic work permits count correctness.
Read and compare every complete counter/clock report and verify the number
of fired transitions independently: one set, six get/out pairs (the initial count marking is already full),
and five batches of n count firings, totaling 1+12+5*n.
Legacy Byte array tuple unpacking becomes Word8ArraySlice, TextIO.input
becomes inputAll in inactive interactive helpers, and its erroneous unused
closeIn alias is corrected. Existing upstream unavailable interactive/export
stubs remain unavailable and are not reached by this simulation. Close the
fixed log file at completion. Original data and all initialization are inside
the parameterized run. Event selection/mutable marking costs are source
hypotheses, not measured causes; see [simulation/ML Kit literature](../literature.md).

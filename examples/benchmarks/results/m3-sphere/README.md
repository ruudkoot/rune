# Sphere tracer validation

Two ports contribute to the 367-program, 1093-profile import wave. Of 56
primary smoke/normal cases, 55 pass; only lazy normal on legacy 64-bit SML/NJ
fails pixel validation. All Rune and strict-profile cases pass. Twenty 69-check
semantic invocations pass all 1380 assertions. Eight normal count samples agree.
Six serial single fresh-process native smoke adapter samples pass.

Original GHC reproduces every 100-line hash fixture. Full 73400-pixel observers
and an independent eager tracer agree on all quantized colors. Both full normal
SML profiles pass calibration. A separate diagnostic reproduces a raw-color
difference at (33,74) in the legacy full program. Computing that pixel alone
passes six configurations; development SML/NJ instead fails to load that smaller
context. Keep both outcomes and the unresolved mechanism in the host note.

The source algorithms, numeric sharing, signed cutoff, nearest-hit tie order,
unbounded shadow check and other historical choices remain. Numeric bounds do
not permit the observed mismatch. No workaround or tolerance increase is added.
Full large SML repetitions remain unrecorded. Full repository acceptance passes
with 1093 profiles and all compiler/runedoc/runeopt cross-build comparisons.

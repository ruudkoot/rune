# Sphere tracer host results

The canonical primary matrix records 55 passes across 56 smoke/normal attempts.
Only lazy normal on legacy 64-bit SML/NJ 110.99.9 fails pixel validation.
Its strict normal case passes, as do every Rune case and the remaining native
host cases. All twenty 69-check semantic invocations pass: 1380 assertions.

A separate diagnostic driver retains the canonical kernel and prints the first
mismatching pixel. It reproduces a substantial raw-color difference at (33,74):
approximately (0.3801255031772972, 0.4720307423739426, 0.5837412207672337)
versus original GHC reference
(0.3873607150475331, 0.4792659542441786, 0.5909764326374696).
This difference exceeds the documented numeric bounds; it is not accepted as
an equivalent decimal spelling or explained away as a quantization boundary.

The canonical source/checker and ordinary host settings remain unchanged.
The diagnostic adds observation and can change allocation/compilation context;
its controls and raw outputs remain distinct from the primary ledger.
The same pixel computed alone passes both policies on Rune, MLton, legacy
64-bit/32-bit SML/NJ, Poly/ML and ML Kit. Development SML/NJ does not load
this smaller compilation context successfully; retain its exact diagnostic
separately from a numeric assertion result. The passing smaller program
does not reproduce the original legacy failure. Preserve both outcomes
rather than call the full-program failure fixed.
The compiler/runtime mechanism is unresolved; no workaround or tolerance
increase is introduced.

Both full normal profiles pass final-source Rune O2 calibration. Eight normal
count samples agree under Rune's engine model rules. Six serial fresh-process
native smoke adapter samples pass, including legacy SML/NJ; that smaller input
does not override its normal-profile failure. Incorrect results cannot supply
accepted measurements.

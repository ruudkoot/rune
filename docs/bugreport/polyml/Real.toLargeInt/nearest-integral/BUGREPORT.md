# Poly/ML 5.9.2: nearest conversion changes an exactly integral real

Recorded 2026-10-16 during the nofib SCS benchmark port. The managed Poly/ML 5.9.2
host returns 4503599627370498 from `Real.toLargeInt IEEEReal.TO_NEAREST`
applied to 4503599627370497.0. The input is an exactly representable binary64
integer. TO_ZERO returns 4503599627370497 from the same value. The minimal
[reproducer](bug.sml) uses only the native Basis and prints both results.

The [Basis REAL specification](https://smlfamily.github.io/Basis/real.html#SIG:REAL.toLargeInt:VAL)
requires conversion with the supplied rounding mode. Rounding an already
integral value to nearest must leave it unchanged; no tie is involved.

The benchmark's original bit encoder scaled a mantissa into an integral real
and used nearest conversion. This host behavior made correct normal rational-
to-double conversions appear incorrect in four cases. The encoder now uses exact
truncation, while separate nearest-conversion regression checks retain the host
failure. The SCS kernel performs no Real.toLargeInt operation and is unchanged.

The direct probe also reproduces the error at 6004799503160661 and
9007199254740991. Rune and the tested MLton/SML/NJ hosts return the unchanged
integer. This report records observed behavior; its implementation cause and
other Poly/ML releases have not been established. No upstream issue has been
filed as part of this benchmark work.

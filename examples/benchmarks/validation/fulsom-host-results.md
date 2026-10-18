# Fulsom auxiliary observations on SML/NJ

All twenty final semantic invocations reach all 184 assertions: 3420 pass,
260 fail and none are unreached. Each invocation on legacy 64-bit and
development 64-bit SML/NJ has 43 failures; each 32-bit invocation has 44.
Native O0/O2 labels repeat host-default flags. Actual runnable smoke/normal
profile checks remain a separate ledger.

The 43 interval-result assertions pattern-match the strict functor's
two-real Range payload outside the functor. The internal interval comparisons
and all complete raster/hash checks through depth five pass. A reduced
two-real constructor program passes its internal accessor on every host,
but external matching reads incorrect values on all three SML/NJ builds.
Rune, MLton, Poly/ML and ML Kit pass both checks.

This reproduces the existing
[parameterized-type real-pair report](../../../docs/bugreport/smlnj/Datatype/real-pair-through-type-constructor/BUGREPORT.md)
from PIC. It needs no renderer, floating arithmetic or collector stress.
The exact compiler pass responsible remains unestablished. The kernel and
valid external-pattern assertions are retained unchanged.

The additional 32-bit failure uses an all-ones Word64 literal. Its isolated
probe prints FFFFFFFF3FFFFFFF and fails three of four controls, matching the
existing [low-half literal report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md).
Actual signed negative raster hashes pass; the kernel's sign-mask literal has
a zero low half and does not trigger this control's damaged literal.

These failures remain incorrect-result outcomes in the auxiliary ledger.
No expected value, tolerance or host-specific access path accepts them.
No issue was posted or remote status inferred from these local reports.

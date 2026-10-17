# PIC state access on SML/NJ

All 56 primary PIC smoke/normal cases pass, including both policies on all three
managed SML/NJ hosts. The measured driver calls the functor's scalar accessor
and validates its result. Eight Rune count samples agree and all six native
adapter diagnostics pass.

The auxiliary test instead unpacks the functor's point constructors directly.
For both invocations each SML/NJ host passes 115 assertions, fails 66 full-state
assertions and then terminates during a constructor-based push test. The
64-bit releases exit 135; the 32-bit release reports a fatal bogus overflow
fault with signal 11. Twenty-one assertions are unreached per invocation.
The other fourteen invocations pass all 202 assertions.

The complete ledger therefore records 3518 passing assertions, 396 failed
assertions, 126 unreached assertions and six runtime-failure outcomes.
Native labels O0/O2 repeat the host's defaults; only Rune compilation levels
differ. All failures and their underlying logs remain visible.

A reduced program constructs a point with two real D.t fields in a functor,
then instantiates D.t with the identity constructor. Internal access returns
1.25 and 2.5; external constructor matching produces garbage on all three
SML/NJ hosts. Rune, MLton, Poly/ML and ML Kit pass. First-order abstract-type,
mixed real/int and array controls pass, narrowing this to the tested
parameterized-type/two-real constructor context.

[The self-contained report and reproducer](../../../docs/bugreport/smlnj/Datatype/real-pair-through-type-constructor/BUGREPORT.md)
records the formal constructor/pattern rules, observed versions and related
upstream context. The exact compiler pass responsible is not established.
This reduction needs no PIC arithmetic, geometry or collector stress.

The benchmark kernel, direct state checks and failing reproducer are retained.
No access-path rewrite, numeric tolerance increase or host-specific program is
used to turn the failure into a pass. The suite's added full-state observations
remain distinct from the original timestep-only demand. No issue was posted.

See the [semantic ledger](../results/m4-pic/semantic-summary.tsv) and
[raw diagnostic records](../results/m4-pic/host-diagnostics/point-probe.sml).

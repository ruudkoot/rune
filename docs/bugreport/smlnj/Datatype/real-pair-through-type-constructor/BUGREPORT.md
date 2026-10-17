# Real-pair constructor payload changes across a functor boundary

Class 1: an observed compiler/runtime representation fault. No floating
arithmetic is required.

## Status

Not posted upstream. Reproduced on the managed Linux SML/NJ 110.99.9 releases
for 64 and 32 bits and SML/NJ 2026.2, checked 2026-10-17. No fix or newer source
build was tested. This came from the PIC benchmark's additional state checks.

## Trigger and expected behavior

A functor defines a constructor with two fields of type real D.t, where D.t is
a parameterized abstract type constructor. Instantiate D with the identity
type constructor. The functor constructs Point(1.25,2.5); its own accessor reads
those values correctly. External pattern matching of that same point instead
reads garbage on all three SML/NJ hosts.

Run the self-contained program with the host's own Basis:

~~~sh
"$HOME/.local/rune-hosts/smlnj-legacy/bin/sml" bug.sml
"$HOME/.local/rune-hosts/smlnj32/bin/sml" bug.sml
"$HOME/.local/rune-hosts/smlnj-dev/bin/sml" bug.sml
~~~

Expected: two PASS lines and SUMMARY 2 checks, 0 failed. The probe records
internal success and external failure; typical 64-bit external values are
tiny numbers around 1e-310. The 32-bit values can differ substantially.
Addresses and erroneous values are not stable expected outputs.

The [Definition of Standard ML, revised 1997](https://smlfamily.github.io/sml97-defn.pdf),
section 6.7, rule 97 preserves the argument in a constructed value. Rule 144
matches the constructor's payload; tuple/record pattern rules 138/142 and
variable rule 135 bind its fields unchanged. Thus the two access paths must
recover the same literal real values. No approximate-operation tolerance,
integer-width choice or NaN behavior explains this discrepancy.

## Validation and controls

Rune, MLton 20241230, Poly/ML 5.9.2 and ML Kit 4.7.23 pass the reduced two-real
probe. Each tested SML/NJ passes its internal check and fails the external one.

The following related controls pass on the tested SML/NJ hosts:

- a first-order abstract type parameter instantiated with real;
- a mixed real/int constructor payload;
- an abstract-element array read inside and outside the functor.

Both lazy and strict functor instantiations together also pass the mixed-field
and array control. The failing two-real case needs neither a large dataset
nor a collector stress loop. The compiler/runtime pass responsible has not
been identified, so a particular code-generation or GC fix is not asserted.

The broader PIC benchmarks pass their primary smoke/normal scalar checks on
all hosts. Its auxiliary consumer unpacks point coordinates outside the
functor, producing 66 bad full-state checks and a later fatal fault per SML/NJ
invocation. That consumer and the minimal program are retained as diagnostics.

## Related upstream report

[Legacy issue 353](https://github.com/smlnj/legacy/issues/353) is closed and
describes another representation inconsistency involving a parameterized
abstract type constructor. Its example uses an int payload and constructor
boxing, unlike this two-real case. The [2026.2 release notes](https://smlnj.cs.uchicago.edu/dist/working/2026.2/README.html)
list that issue as fixed; the case here still fails on the tested 2026.2 build.
This is related context, not evidence that the same fix or cause applies.

Raw full-state and reduced-program logs are retained in the benchmark
validation archive linked from its host-results note. The benchmark kernel
and valid external-pattern tests are unchanged.

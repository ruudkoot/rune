Draft only; not posted.

Title: Real-pair constructor through a parameterized abstract type reads wrong outside its functor

The attached bug.sml constructs Point(1.25,2.5) inside a functor whose fields
have type real D.t, then instantiates D.t with the identity constructor.
The internal accessor returns both literal values; external pattern matching
returns garbage. It reproduces on the managed 64-/32-bit 110.99.9 releases and
2026.2. Rune, MLton, Poly/ML and ML Kit pass.

The program is self-contained with the host Basis and contains no floating
arithmetic. First-order abstract-type, mixed real/int payload and abstract-array
controls pass. This resembles the parameterized-type representation concern in
legacy issue 353, but that report has a different constructor-boxing example;
no shared cause is established.

Expected: both checks pass and exit status 0.
Observed on the tested SML/NJ hosts: internal check passes, external check fails.

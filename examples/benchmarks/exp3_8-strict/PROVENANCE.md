# exp3_8-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/exp3_8/Main.hs`.
Lennart Augustsson's 1992 Haskell translation; the source retains Joern von
Holten's discussion of the original ASpecT 3^8 benchmark. Preserve the full
mail history, source and Makefile. No individual licence statement is given;
record that gap rather than assigning an inferred licence.

Compute 3^n by strict Peano addition and multiplication, then force the complete unary result.
Keep Z/S unary naturals, recursive addition, multiplication x*(S y)=x*y+x,
and exponentiation by recursive unary multiplication. Do not replace the
workload by machine exponentiation. The independent integer 3^n calculation
is used only after forcing/counting every constructor of the actual result.
The strict variant fully evaluates recursive products/additions before
constructing successors, materially changing evaluation/allocation and sharing
relative to the lazy source. It is separately named and measured.
Smoke uses exponent 3; normal 8 is the upstream fast parameter and large 9
is the upstream normal/slow parameter. All selected counts fit machine ints
on every host; the unary representation stays unchanged. Process arguments
are thin driver input. Forcing, thunk allocation, recursion and retained
constructors are source hypotheses; see [nofib literature](../literature.md).

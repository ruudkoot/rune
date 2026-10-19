# wheel-sieve2-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/wheel-sieve2/Main.hs`.

Colin Runciman, March 1996. The source cites his 1997 functional pearl
[Lazy wheel sieves and spirals of primes](https://doi.org/10.1017/S0956796897002670).
Keep the established Mark I/Mark II variant distinction. Complete source,
Makefile and available fixtures are retained with individual SHA256 identities;
the program supplies no explicit individual licence notice, recorded as a gap.

Both ports preserve circular prime dependencies, delayed list heads and spines,
wheel residues and periods, prime squares, bounds, and indexed result selection.
The helper retains lazy folds whose branch may ignore the remainder and a
shared lazy span whose prefix can be consumed without forcing the full split.
There is no strict approximation: prematurely forcing these infinite/circular
structures changes termination and the algorithm. IntInf replaces machine Int
for wheel arithmetic and n^2/n^4 bounds, preventing host-width overflow.
Selected guard values fit the original GHC 64-bit range; this representation
change adds arbitrary-precision arithmetic costs, explicitly part of the port.

The original 100 printed results become separately selected repetition counts
and one consumed sum. Each invocation builds its own prime knot, while sharing
within that knot is preserved. Smoke/normal use one invocation; large preserves
100. Zero-based prime indices are unchanged. Independent finite Eratosthenes
fixtures agree with the original GHC kernel on all selected inputs. All actual
prime values are checked. Incorrect values, loss of sharing or excessive forcing
are rejected by result and stream-semantic checks.

The paper supports the algorithm distinction and the need to avoid black holes.
Effects of memoization, bigint representation, retention and compiler
specialization are source-derived hypotheses until measured on these ports.
See [the literature survey](../literature.md).

Mark II retains the spiral's turn0/turn/roll functions, branch replacement
by the next spiral, dropWhile alignment, and span-based residue split. In
particular the initial candidate 2 is emitted before forcing its square bound.
The source's recursively re-created wheel stream is retained rather than
replacing it with Mark I's single self-referential wheel root. Profiles are
(32,1), (700,1), (2000,100); normal/large preserve original FAST/NORM indices.
Original SLOW 4000 and its Haskell 300 MiB runtime heap setting are recorded;
our manifest's standard per-profile limits are separately explicit.

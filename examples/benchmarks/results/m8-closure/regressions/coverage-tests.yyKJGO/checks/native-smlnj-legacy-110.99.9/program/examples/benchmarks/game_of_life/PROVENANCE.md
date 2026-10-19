# game_of_life provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`,
benchmarks/multicore-numerical/game_of_life.ml. The individual author is unstated.
Retain original source, build/configuration data, aggregate Unlicense and hashes.
Sequential and parallel executables remain distinct.

## Algorithm, inputs and variants

Keep square arrays of rows, all eight neighbor reads, zero exterior, the exact
live/birth/death cases, two buffers, row/column traversal and pointer swaps.
The get helper catches out-of-bounds exceptions as in the original; an explicit
bounds-branch implementation does not replace that diagnostic behavior. Original
inline hints become ordinary SML functions, allowing each compiler's optimization.
Both buffers remain live through complete output validation.

Input is the original Random.int 2 default stream, reproduced by the shared
pinned OCaml 4.14.1 helper. Full initial boards agree with an independent generator
at all selected sizes. Retain original Random source, copyright and complete
LGPL 2.1/OCaml linking exception. State setup/boxing differences are documented
in the shared array ports. No external dataset is acquired.

## Profiles, translation and correctness

Arguments preserve generations and board side: smoke 2/8, normal 64/128 and
large 256/1024. Large retains the published single argument 256 and original
board-size fallback 1,024; source generation fallback 2 is retained in provenance.
All cell, index, neighbor and count arithmetic fits 31 bits for these inputs.
SML97 row arrays, two local references and standard Subscript handling replace
OCaml arrays/refs. The generator is fresh on each driver invocation.

Original Main discards boards. An observer saves initial/current/spare buffers.
The driver checks EVERY cell of both final buffers against reviewed ASCII
fixtures and consumes live counts plus a Word32 modulo 2^32 fingerprint. Returning
both buffers preserves their original liveness during the added checks. Streaming
fixture reads and full cell comparisons are measured validation additions.

Bounded original OCaml and independent zero-boundary stencil calculations agree
on smoke/normal current AND previous boards. Original large fixtures are
available; large SML execution is claimed only for recorded cases. Ten semantic
checks cover borders, single/block/blinker, zero generations, previous-buffer
identity/isolation and deliberately perturbed checker input. The managed 32-bit
SML/NJ generator arithmetic issue remains the same independently isolated
[host failure](../validation/smlnj32-random.md); source/expected results are not
rewritten for that host.

## Runtime questions and references

Row lookup, exception frequency at borders, loop inlining, buffer reuse,
generator/checking cost and heap representation are source-based hypotheses
until measured or established by IR. This dense bounded-buffer workload is
distinct from the existing nofib list-based Life ports. See the retained source,
shared OCaml generator provenance and cellular-automaton/measurement survey.

Historical background: Gardner, [Mathematical Games, October 1970](https://www.scientificamerican.com/article/mathematical-games-1970-10/).
The array representation, boundary handling and buffer lifetimes are established
by this pinned program, rather than attributed to the historical article.

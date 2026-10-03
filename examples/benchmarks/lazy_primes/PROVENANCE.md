# lazy_primes provenance

Sandmark `5605805954a00497ed197c930641cddd580e1507`, `benchmarks/simple-tests/lazy_primes.ml`.

The individual author is unspecified. Original source, dune declarations,
SHA256 identities and the aggregate public-domain notice are retained. Kernels
and translation support are SML97. Compiler/runtime explanations below come
from source inspection and remain performance hypotheses until measured.

## Algorithm, history and variants

Keep Cons(strict head, memoized tail), the infinite integer stream from 2,
removing filter, and successive sieve layers. The ordinal is one-based.
`take 1 (drop (nth-1) primes)` forces the next tail even though take 0 returns
empty: preserve this extra demand from strict OCaml arguments. This differs
from the nofib lazy-head/lazy-spine ports, which retain their own names and
forcing decisions. No array sieve, trial division or eager infinite list
replaces the algorithm. Unused take/drop/zip helpers remain in pristine source.

## Translation, inputs and validation

BenchLazy preserves memoized tails and exceptions. Source heads remain strict;
no separate head delay is added. All selected values fit 31 bits. Fixed profiles
use ordinals 10/1000/5000; normal/large preserve entries in micro_multicore.json,
and the other original ordinals 2000..10000 are retained in reviewed config
extracts with complete file identities. Results29/7919/48611 agree with unchanged
OCaml and independent trial division. Semantic checks verify the additional
tail demand, memoization, predicate-removing filter and prime prefixes. Stream
retention, sieve closures and demand are hypotheses until measured. Large SML
execution is not universally claimed. References: retained source/configuration
and the shared nofib/Sandmark literature survey.

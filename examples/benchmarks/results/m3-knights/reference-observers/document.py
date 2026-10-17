from pathlib import Path
root=Path.cwd();suite=root/'examples/benchmarks';p=root/'tests/out/benchmarks/knights-originals'
url='https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/knights'
body='''### Algorithm and workload

Find closed knight tours with depth-first search over the source queue/list of
starting squares. Keep move order UL, UR, DL, DR, LU, LD, RU, RD; detect isolated
squares, select a unique single-descendant move, or order candidates by onward
degree with the source list-comprehension quicksort. All boards compare equal
under the source Eq instance; degree ties therefore retain traversal order.
The printed backtracking-moves counter increases with depth, not with the total
number of nodes searched. Preserve this historical output label and behavior.

### History, authorship and upstream variants

[Jonathan Hill's knights source](SOURCE_URL), version 1.4 with 1992 module
headers, is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. README declares
Hill's authorship and distinguishes this sequential search from a separate
parallel demonstration. All original literate modules, README and bibliography
are retained under knights-lazy/upstream. No separate individual redistribution
grant is stated in these files; retain the source notices and suite provenance.
The active program imports ChessSetList. The unused ChessSetArray alternative
has materially different storage, copying, deletion metadata and formatting;
its -array variants have separate names and reference outputs.

### Translation, representation and evaluation

List variants retain a persistent reversed trail, lazy init/last operations,
size, move number and starting square. Array variants retain immutable boxed
arrays and copying updates; portable memoized vectors store delayed element
values. No mutable in-place board replaces the source persistent structure.
The array's tileIndex is (x-1)*size+y. Preserve its unused indexTile's original
quotient/remainder quirk and deleteFirst's unchanged move count/reset first
square. The board render layouts differ between representations.

-lazy memoizes numeric metadata and candidate degrees. -strict evaluates those
fields eagerly. Both preserve the lazy search frontier, finite child streams,
trail/array roots and first-square field. A deleted singleton can have an unused
undefined first square in the list source; forcing it eagerly changes behavior.
The degree enumeration for singles and the fresh enumeration for sorting remain
separate calls, as in the source. Search, output streams and demanded prefixes
are memoized explicitly. Both variants preserve the source quicksort rather
than replace it with a host library sort.

The inactive array renderer contains logTen 1 = 0 and otherwise recurses with
x div 10. Original spaces 64 1 overflows its stack after reaching zero repeatedly.
For the array variants only, change this formatting base case to logTen 0 = 0.
The reference observer makes exactly that repair and selects ChessSetArray;
retain the failing original and bounded diagnostic. Search, board updates,
numeric values and stopping conditions are unchanged. This is a documented
source repair, not an exact duplicate of the active list program.

### Inputs, profiles and checks

Smoke uses one repetition on an 8-by-8 board and asks for one tour. Normal retains
100 repetitions on a 14-by-14 board; large retains 100 on a 20-by-20 board.
Source FAST also uses 100 repetitions; reducing only the smoke repetition count
keeps routine checks practical. Source normal and large parameters are retained.
All indices, coordinates and search counters fit signed 31-bit arithmetic for
these profiles. The total checked-character counter uses IntInf as metadata.

The original program prints the length of its rendered tour in each repetition.
The port compares every rendered character with an original full-tour fixture,
and reports repetitions plus total checked characters. This extra validation
and character forcing are explicit consumer adaptations. Every repetition
restarts the search; no memoized result is added across Benchmark.run calls.
Original GHC 9.4.7 matches all active FAST/NORM/SLOW fixtures. Export-only
observers record seven full-tour cases, including three tours, no solution and
zero requested solutions. Array fixtures use the separately reviewed repair.
No floating-point tolerance applies.

Independent tests verify every square is visited once, bounds, each knight move
and the closing jump. Also test original complete rendering, stable degree ties,
odd-board rejection, zero-demand behavior, unused first-square demand, metadata
memoization, persistent predecessors and incorrect-output rejection. Array tests
check its distinct deletion/index behavior. See the validation archive for actual
configuration outcomes; full SML large repetitions remain unrecorded unless listed.

### Literature and runtime questions

The pinned KnightHeuristic commentary credits Richard Bornat's Programming from
First Principles, under Positively the last flourish; functional.bib records a
1986 Prentice-Hall entry. This is an upstream attribution, not a claim to have
reviewed the book's algorithm. [The source bibliography](SOURCE_URL/functional.bib)
records it. [Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides suite context. The program's own sorting comments are historical
observations, not performance findings for these ports.

Investigate degree recomputation, laziness, list membership, persistent array
copying, dead-end pruning, equal-key ordering and rendering costs. These are
source-based diagnostic hypotheses. Exact original output and independent tour
legality support correctness for the selected inputs; count/timing records are
separate measured evidence.
'''.replace('SOURCE_URL',url)
readme=suite/'README.md';text=readme.read_text();pos=text.index('\n## ');rows=''
for rep in ['list','array']:
 for mode in ['lazy','strict']:
  name='knights-'+('array-'if rep=='array'else'')+mode
  (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
  rows+='| ['+name+'](#'+name+') | [nofib]('+url+') | Search closed knight tours with a persistent '+rep+' board and '+mode+' numeric metadata. |\n'
  text+='\n## '+name+'\n\n'+body
text=text[:pos].rstrip()+'\n'+rows+text[pos:];readme.write_text(text)

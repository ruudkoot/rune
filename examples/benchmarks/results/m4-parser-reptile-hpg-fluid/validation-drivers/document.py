from pathlib import Path
import csv,json,hashlib
suite=Path('examples/benchmarks')
revision='b7391df4540ac8b11b35e1b2e2c15819b5171798'
texts={}
texts['parser']=r'''# nofib parser provenance

## Algorithm and workload

Tokenize Haskell source, apply layout, and parse modules with higher-order
combinators and a fixity environment. Build the source AST, preserve the next
token and environment, render the complete report, and compute the source's
strict left-fold hash. Preserve 500 fresh parses and reports per invocation.

## History, authorship, revision and aliases

Use nofib REVISION, real/parser, Main.hs.
The selected source and input headings do not state an author or a separate
licence. Retain the actual original headings and this gap. The three input
files contain progressively larger portions of the Parser module; they are
upstream fixtures. Their source identities are recorded independently.
The canonical common/NofibUtils.hs and its directory symlink are recorded
separately. The utility uses a strict fold and an explicit salt barrier.

## Known variants

parser-lazy memoizes finite token attributes, AST fields and output lists.
parser-strict evaluates those finite attributes eagerly. Both keep memoized
lexer/parser control, positions, alternatives and the infinite EOF stream.
Their complete outputs agree with GHC for every selected profile. The name
has no classic SML collision; these policies are explicit suffixes.

## Translation and adaptations

Retain the combinator algorithms, alternative order, first-success behavior,
furthest-error comparison and dynamic precedence/associativity handling.
Recursive parser builders are memoized functions, without caching parse
results. Preserve the source's parenthesized-token text quirks, nonnested
comments, backquoted identifiers, column accounting and CPP-line skipping.
An EOF singleton cycles with line/column 99997. Position delays preserve the
source's ignored undefined line number after a lone hash at EOF.

Retain ShowS-style character output and Haskell literal Read/Show behavior.
Selected input is ASCII. The input string is read eagerly before memoized
character consumption, and remains shared across repetitions. Each repetition
constructs fresh lexer/parser/report work. The Haskell salt barrier maps to
this explicit driver call boundary; no new compiler feature is introduced.

Selected integer literals and positions fit signed 31-bit integers. Hashes
use explicit modular 64-bit arithmetic, with signed rendering through IntInf.
This preserves the pinned 64-bit GHC hash on hosts with narrower default Int.
The driver checks every complete-report hash, prints each source hash line,
then reports the verified repetition count.

## Inputs, validation and limits

Smoke/normal/large preserve parser.faststdin, parser.stdin and parser.slowstdin:
992, 6949 and 43999 bytes, with 500 repetitions each. Original complete reports
have 1434, 15653 and 98649 bytes; retained reference files expose every byte.
Their signed hashes are 4438664785162099485, -175746672012950975 and
-9015528911864443912. Each profile records its full modular digest in the manifest.
Default time/memory limits apply unless a later recorded override says otherwise.

Private checks agree with upstream stdout fixtures and all six complete
Need/Strict reports. Additional observations cover complete raw/layout token
streams, 26 lexical controls, 33 typed parser cases, all report hashes, ignored
input/continuations, error-position demand and semantic sharing. The original
500-repetition smoke and normal drivers pass locally. Public host/profile,
count and repository acceptance gates are pending and are recorded separately.

## Runtime questions and literature

Higher-order calls, closure lifetimes, recursive parser construction, failed
alternatives, layout, AST allocation and report generation are source-based
diagnostic questions. Attribute materialization and retained input can affect
space use. Performance conclusions require measurements of the identical SML
sources on each host.

[Hutton and Meijer, Monadic parser combinators (1996)](https://nottingham-repository.worktribe.com/output/1024440/monadic-parser-combinators)
is background on higher-order parsing. No authorship or direct derivation of
this historical parser is inferred from that report. Original Main.hs and
the retained fixtures remain the implementation references.
'''
texts['reptile']=r'''# Reptile provenance

## Algorithm and workload

Run a scripted tiling editor and generate its complete MGR terminal protocol.
Keep editor modes, rational geometry, drawing/erasure, transformations, tile
orientation and associations. Hash the complete protocol 500 times from the
source initial state and scripted input.

## History, authorship, revision and aliases

Use nofib REVISION, real/reptile.
Module headings credit Sandra Foubister's 1990 LML original and Colin Runciman's
May 1991 Haskell translation. Preserve their separate roles and all individual
headings. The pinned files do not supply the LML implementation or a separate
general licence grant. The scripted input files and hash stdout fixtures are
upstream data, with no additional authorship asserted.

## Known variants and selected executable

reptile-lazy memoizes finite drawing, association and text attributes;
reptile-strict materializes finite attributes eagerly. Both keep memoized
input-line and editor-transition control, and lazy producers before bounded
grid/tile prefixes. All complete protocol bytes and editor states agree.
The selected nofib Main consumes scripts and emits hashes; it does not need
a running MGR server.

Preserve the source's disabled SAVE/GET handlers as no-ops. The original
PostScript helpers remain in upstream/Psfuns.hs; only the used concrep helper
belongs to this executable path. No port of unused PostScript entry points
is claimed. The source's LML history is provenance, not a second imported port.

## Translation and adaptations

Keep exact rational-pair arithmetic, normalization, integer root search,
list geometry, association lookup/update order and finite editor state.
Use explicit two's-complement modular 64-bit integers for the pinned Haskell
Int operations. Hashing is also modular 64-bit; signed decimal conversion is
explicit. Preserve duplicate-removal quirks and both removals in deline.

The control state and transition tuples are memoized independently of the
finite-data policy. Infinite grids, indices and repeat producers are bounded
by the original consumers. concrep retains concat/take/repeat structure.
The driver reads and retains the fixed script eagerly; each repetition
starts the immutable source state and constructs fresh protocol output.
Every protocol hash is checked and printed before the verified count.

## Inputs, validation and limits

Smoke/normal/large preserve the three original scripts (18, 343 and 1029 bytes),
each with 500 source repetitions. Complete protocols have 22845, 47172 and
154800 bytes. Their signed hashes are -7953762212385260731,
5842283869563187271 and -992743539523439187. Full references and all three
modular digests are retained. Default profile limits remain unchanged.

Private checks match all three original stdout fixtures, all six complete
protocols, 178 complete transition-state observations and 38 protocol/geometry
component comparisons. Both policies pass the original smoke and normal
500-repetition drivers. A private combined six-case run reached its overall
600-second deadline during large; this is an incomplete combined check, not
a failure under the large profile's 3600-second allowance. Public host/profile,
count and repository acceptance gates remain pending.

## Runtime questions and literature

State retention, list copying, exact arithmetic, protocol construction and
sharing of immutable tables are source-based performance questions. Separate
instrumentation is needed to attribute allocation or GC costs. Original
module headers, Mgrfuns.hs and Progfuns.hs are the benchmark-specific references.
The roadmap's nofib literature supplies the suite context; historical
authorship does not itself establish a performance result.
'''
texts['hpg']=r'''# Haskell Program Generator provenance

## Algorithm and workload

Generate algebraic types, values and expressions using an immutable
continuation-passing environment, seeded random choices and infinite name
streams. Render the header, declarations and generated test program as three
source chunks. Hash and print each chunk on every one of 100 repetitions.
This workload generates Haskell text; it does not execute the generated test.

## History, authorship, revision and aliases

Use nofib REVISION, real/hpg.
The retained hpg.tex manual names N. D. North of the National Physical
Laboratory; MAIL identifies Nick North and the early distribution history.
Retain the 1991/1992 Crown Copyright module/manual notices individually.
The pinned version is 1.20 dated 92/07/20. Historical correspondence is not
treated as an additional general licence grant. README.nofib records the
disabled random-number debug printing; upto still forces each chosen integer.

## Known variants

hpg-lazy memoizes finite types, values, expressions and environment lists.
hpg-strict materializes those finite fields eagerly. Both keep lazy control
for infinite RNG/name streams, candidate continuations and prefix-consumed
Cartesian index enumeration. Unselected continuations do not run. Source
Integer/Float/Double tags in generated values retain their original Int-valued
payload; they are not replaced by another generator or arithmetic workload.

## Translation and adaptations

Preserve the eight-field immutable environment, random-consumption order,
weighted/rejected choices, lambda push/pop, declaration insertion and printing.
Even a one-candidate function list consumes a random draw. Preserve initial
seeds (9807,65,32975), including the unnormalized initial third seed; emit the
initial combined value before advancing seeds.

RNG operations round after every binary32 operation, with truncation at the
same points as the source. The reused finite-binary32 helper's selected
zero/normal domain covers these bounded calculations. All selected counters,
numeric payloads, seed products and names fit signed 31-bit integers; modular
64-bit hashing and its signed rendering are explicit.

Candidate continuations are suspended as control. Cartesian enumeration
retains the source nested-product algorithm, re-evaluating suffix products
at the original positions. The portable control loop discards completed
empty branches without retaining a chain of deferred administrative steps.
Finite attributes retain their selected policy. No product sharing,
algorithm replacement, input reduction or guard increase was used to obtain
agreement on the large case. Preserve ShowS composition, split_str at 70
characters, Haskell punctuation, numeric tags, character escapes and spaces.

## Profiles and validation

All profiles retain 100 source repetitions. Parameters are:
smoke nt=8, dt=4, nv=10, dv=6, de=6;
normal 40,5,60,6,6; large 80,8,100,8,8.
These are the original FAST/NORM/SLOW options, with default seeds and Main
module name. The manifest records three independent chunk digests per profile.
All generated chunks are retained as full reference files. Default limits
apply unless a later override is recorded explicitly.

Private GHC observations agree on all 18 complete chunks (three profiles,
three chunks, two policies), including the 121341-byte large declaration
chunk and 221465-byte large test chunk. All 10000 observed binary32 RNG words
agree exactly. The original 100-repetition smoke driver passes locally.
Earlier failed translation attempts and unchanged guard interruptions remain
preliminary evidence; they are not large-workload limit failures.
Public host/profile, count and repository acceptance gates remain pending.

## Runtime questions and literature

Continuation construction, captured environments, recursive types, weighted
choices, symbolic output and retained sharing are source-based diagnostic
questions. The source manual hpg.tex and included module documentation are the
benchmark-specific account. The RNG's reference is
[Wichmann and Hill (1982)](https://academic.oup.com/jrsssc/article/31/2/188/6985277).
Its bibliographic context does not establish a Rune performance result.
'''
texts['fluid']=r'''# Fluid provenance

## Algorithm and workload

Compute a Taylor-Galerkin/pressure-correction step for the supplied finite
element channel model. Retain persistent binary radix tries, assembly,
minimum-degree ordering, elimination trees, generalized-envelope storage,
column Cholesky factorization, substitution and Jacobi iterations. Render
and hash the complete source result on each repetition.

## History, authorship, revision and aliases

Use nofib REVISION, real/fluid.
Dated 1991/1992 source headings identify XZ; Input_proc.hs also records XA.
Their initials are retained without inventing full names or a sole author.
The program, chan.hed/fluid.stdin, runtime_files/chan8.dat and historical res8
retain their actual headings; no broader program/dataset licence or additional
dataset authorship is inferred. The selected channel model contains eight
elements, 25 velocity nodes and nine pressure nodes. The historical reference
to a 200-element problem does not supply a second dataset in this snapshot.

## Known variants

fluid-lazy memoizes finite numeric/list fields and fluid-strict materializes
them eagerly. Both retain memoized trie/array/control roots and the explicit
Norm_pack forcing flags. Preserve the selected header's monitoring=false,
one main step and two maximum Jacobi iterations. Monitoring and two-step
controls are independent correctness fixtures. The historical res8 file is
retained separately from modern GHC-derived expected output.

## Translation and adaptations

Keep Float semantics through binary32 rounding after every arithmetic
operation, including subnormals and the original 1e-40 small constant.
Retain source operation association, zero-skipping multiplication, source
norm/guard order, stopping tests and default/undefined sparse-array behavior.
Control delays keep unused final backward-substitution updates and
out-of-block diagonal expressions unevaluated.

Sparse arrays remain persistent radix tries with source Null coalescing,
stable partition/update/accumulation order and sparse association traversal.
Selected indices and counters fit signed 31-bit integers. The hash is explicit
modular 64-bit. Norm_pack shares its object and memoized deep-forcing result.
Do not replace the source solver, matrix representation or tolerance tests.

The numeric input adapter is scoped to the reviewed decimal fixtures; it
does not implement every Haskell Read syntax. It preserves the independent
takeval/dropval parsing passes. All parsed source fields agree exactly with
GHC. Input files are read eagerly into SML strings. The header remains shared;
the dataset is opened/read afresh on each repetition as in the source loop.
The bounded driver preserves nonpositive counts as zero work.

Float formatting ports the pinned GHC.Float binary32 floatToDigits and
FFGeneric/Nothing behavior, using portable IntInf support. Preserve ShowS
character output, original spellings and complete result forcing. The driver
checks each complete output hash and adds a verified-count summary to the
source's empty stdout.

## Inputs, validation and limits

Smoke/normal/large retain 35/350/1750 repetitions, the unchanged fluid.stdin
header and chan8.dat. These profiles repeat the same model; they do not
claim mesh-size or memory scaling. The source's complete per-repetition
output has 814 bytes, SHA-256
4905e148b32fa11477a11852bc99f08f047cd2db42888a502fd069a0832fa6d3,
and modular digest 9DCE0361F540E943. Default profile limits apply.

Private checks cover 260 complete trie/default/value observations, 960 exact
binary32 matrix/product/tolerance observations, 36 minimum-degree orders,
complete parsed mesh/reordering/factorization/substitution observations,
10015 exact GHC Float Show cases, and ten complete simulation outputs.
Both policies match source output with monitoring, two steps and tolerance
stopping. The original 35-repetition driver passes locally. Public host/profile,
count and repository acceptance gates are pending; no host success is inferred
from these local checks.

## Runtime questions and literature

Sparse traversal, persistent updates, graph ordering, normalization, floating
point boxing/rounding, IntInf formatting and I/O are source-based diagnostic
questions. The supplied main-step limit skips some convergence checks; retain
that workload rather than claiming broader convergence coverage.
[Liu (1990)](https://epubs.siam.org/doi/abs/10.1137/0611010) provides background on
elimination trees and sparse factorization. Original source comments identify
the implementation's generalized-envelope approach. The pinned GHC base source
and full licence accompany formatting support under shared/upstream.
'''
descriptions={
 'parser':'Parse and render Haskell modules using layout, higher-order combinators and a dynamic fixity environment.',
 'reptile':'Generate and hash a scripted MGR tiling-editor protocol with exact rational geometry.',
 'hpg':'Generate and hash seeded Haskell types, values and expressions through continuation-passing functions.',
 'fluid':'Solve and hash the supplied finite-element flow model using sparse tries, Cholesky and Jacobi methods.'}
for family,text in texts.items():
 for policy in ['lazy','strict']:
  name=family+'-'+policy;d=suite/name
  (d/'PROVENANCE.md').write_text(text.replace('REVISION',revision))
rows=list(csv.DictReader((suite/'manifest.tsv').open(),delimiter='\t'));fields=list(rows[0])
tags={'parser':'application,parsing,higher-order,allocation-lifetimes,demand-sharing',
      'reptile':'application,state-machine,rational-arithmetic,lists-streams,allocation-lifetimes',
      'hpg':'application,program-generation,continuations,pseudo-random,allocation-lifetimes',
      'fluid':'application,numerical,sparse-data,graph-ordering,allocation-lifetimes'}
for row in rows:
 for family in texts:
  if row['benchmark']in[family+'-lazy',family+'-strict']:
   row['tags']=tags[family]+','+row['benchmark'].split('-')[-1]+'-finite-data'
with(suite/'manifest.tsv').open('w',newline='')as f:
 w=csv.DictWriter(f,fieldnames=fields,delimiter='\t',lineterminator='\n');w.writeheader();w.writerows(rows)
f=suite/'README.md';lines=f.read_text().splitlines(keepends=True)
start=next(i for i,l in enumerate(lines)if l.startswith('| Name | Source |'))
end=start+1
while end<len(lines)and lines[end].startswith('|'):end+=1
add=[]
for family in texts:
 for policy in ['lazy','strict']:
  name=family+'-'+policy
  add.append('| ['+name+'](#'+name+') | [nofib](https://gitlab.haskell.org/ghc/nofib/-/tree/'+revision+'/real/'+family+') | '+descriptions[family]+' |\n')
lines[end:end]=add
s=''.join(lines)
for family in texts:
 for policy in ['lazy','strict']:
  name=family+'-'+policy
  s+='\n\n## '+name+'\n\nSee the [complete provenance]('+name+'/PROVENANCE.md) for the workload,\nsource history, variants, translation, input profiles, result checks and references.\nPublic host/profile validation for this import wave is pending.\n'
f.write_text(s)
f=Path('docs/plans/benchmarks.md');s=f.read_text().replace('Status: **in progress**, 2026-10-18.','Status: **in progress**, 2026-10-19.',1).replace('The current catalogue has 495 programs and 1437 profiles.','The current catalogue has 503 programs and 1461 profiles.',1)
s=s.replace('M4 still has anna, fluid, hpg, parser, reptile and veritas; M8 closes the\ninventories, evidence, documentation and maintenance procedures.',
'''M4 now registers parser, reptile, hpg and fluid with complete independent
reference checks; their public host/profile, count and acceptance gates are
pending. Anna and veritas remain unported. M8 closes the inventories,
evidence, documentation and maintenance procedures.''')
f.write_text(s)
print('Wrote eight complete provenance sections and linked catalogue entries; M4 remains in progress.')

from pathlib import Path
suite=Path('examples/benchmarks')
body="""### Algorithm and workload

Complete the seven source equations for a geometric group using term matching,
substitution, unification, recursive path ordering, critical-pair generation,
rule deletion and normalization. Retain association lists, immutable term trees,
rule numbering, list concatenation/order and the improved completion recursion.
Both source programs produce the same ordered 24-rule canonical system.

### History, authorship, notices and naming

Xavier Leroy, projet Cristal, INRIA Rocquencourt. Individual headers state
Copyright 1996 INRIA and Q Public License version 1.0, with terms/equations/
orderings/kb source revisions dated 1999 and kbmain dated 2005.
Pinned Sandmark revision 5605805954a00497ed197c930641cddd580e1507,
benchmarks/kb/kb.ml and kb_no_exc.ml. These individual notices take precedence
over assumptions based on the collection's top-level license.

Keep both original files unchanged under kb/upstream. The Rune SML97 translation
is distributed in separate files with original authorship/notices retained.
The canonical QPL-1.0 text is included; its official SPDX source revision and
identity are recorded in the evidence. Historical compiler licensing is retained
only as context; no additional compiler-specific exception is inferred.

The established upstream names kb and kb_no_exc are distinct from the classic
knuth-bendix and knuth-bendix-smlnj programs. Document their related algorithm,
without claiming identical source workloads or replacing the classic names.
No external dataset is required; the geometric group equations are source data.

### Differences between the executable variants

kb uses Failure exceptions for matching and top-level reduction; its pretty_term
and pretty_close are complete stubs. kb_no_exc returns option values from matching
and top-level reduction, while retaining exceptions in deeper rewriting,
unification and completion. Its name does not mean all exception use is removed.

The second source also traverses term structure in its printer despite stub
print functions. Preserve that separate traversal and its infix-arity checks.
Do not attribute every performance difference solely to exceptions versus
options. The exact original output remains empty for both programs.

### Portable translation and runtime behavior

All computation, fixed equations, checks and consumers use SML97.
Shared term/unification, ordering, completion and input modules retain a single
implementation. Separate rewriting modules preserve ordinary versus optional
matching and reduction, including the source membership-then-association lookup
rather than silently combine two traversals into one.

A shared completion functor receives the selected rewriting/printer module.
This module boundary is a translation choice: compiler specialization/inlining
can affect its runtime cost. Record it when interpreting comparisons.
The code retains the source fold-left paired traversal, right-recursive
partition, nested handler scopes, list ordering, variable standardization,
critical-pair namespace offsets and failure categories.

Source integer fields and selected rule/variable counters fit portable signed
int. There is no arbitrary precision substitution, floating arithmetic, random
input, parallel facility or FFI. Optional OCaml GC-stat output belongs to
measurement adapters rather than the portable kernel.

Original kb_complete returns unit after printing the completed rules. The port
returns the already-computed list after preserving the same printer traversal.
Validate its complete canonical serialization, including every rule number,
variable count and term. This is an explicit additional result consumer; it
does not replace completion with a cached rule set.

### Profiles and correctness

| Profile | Completion repetitions |
|---|---:|
| Smoke | 1 |
| Normal | 100 |
| Large | 1000 |

Normal retains the source count; smoke reduces it and large selects ten times
the source repetitions. Every iteration computes a fresh completion over the
source's shared immutable input equations, validates all completed rules and
reports repetitions:checked-rules. No completed-result cache is used.

Unmodified OCaml runs finish both 100-iteration programs with empty stdout.
Export-only observers expose all completed records; their complete canonical
text is byte-identical across variants. Final-source normal Rune calibration
passes both variants. Full SML large repetitions remain unrecorded.

The 1285-check target compares full original rule text and count, checks every
final rule's orientation and irreducible right side, normalizes every input
equation, and verifies all 576 ordered final critical-pair combinations for each
variant. It also covers substitution/unification, occurs/arity checks, path
replacement, repeated/conflicting variables, source standardization, zero
iterations and corrupted-result rejection. Rune and all six native hosts pass
the private target; canonical matrices/counts are recorded with the import wave.

### Literature and diagnostic questions

[Knuth and Bendix, Simple Word Problems in Universal Algebras (1970)](https://doi.org/10.1016/B978-0-08-012975-4.50028-X)
provides completion context.
[Dershowitz, Orderings for Term-Rewriting Systems (1982)](https://www.math.tau.ac.il/~nachumd/papers/Orderings4TRS.pdf)
describes recursive path orderings and termination criteria.
The retained Leroy source establishes this benchmark's concrete algorithm.
Investigate structural equality, association-list lookup, exception/option
propagation, printer traversal, list allocation and higher-order specialization.
These are source-based questions; the finite critical-pair checks and measured
configurations do not establish a general theorem or a performance explanation.
"""
f=suite/'README.md';text=f.read_text();pos=text.index('\n## ',text.index('| [almabench]'))
table=''
for name in ['kb','kb_no_exc']:
 table+=f'| [{name}](#{name}) | [Sandmark Knuth–Bendix](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/kb) | Complete the source geometric group rules using {"exception-based"if name=="kb"else"optional"} matching and validate the full canonical system. |\n'
 (suite/name/'PROVENANCE.md').write_text('# '+name+' provenance\n\n'+body)
text=text[:pos].rstrip()+'\n'+table+text[pos:]
for name in ['kb','kb_no_exc']:text+='\n## '+name+'\n\n'+body
f.write_text(text)

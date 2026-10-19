# treejoin-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/treejoin/Main.hs`, relation files 27000.1/27000.2
and the retained MAIL. The 1993 submission is from kh@dcs.gla.ac.uk; the full
individual author/licence and dataset notice are not specified, recorded as gaps.
Original source, data, build settings and mail are retained with SHA256 identities.

Keep the unbalanced persistent binary-tree representation, boundary keys,
insertion/duplicate-key rules, key lookup and right-before-left join accumulation.
The left relation is keyed by its first field; its third field looks up the first
field of the right relation. Joined values have the original five fields. Both
variants instantiate one algorithm with eager or memoized suspension adapters.
The lazy adapter delays numeric accumulation, tree roots/branches and stored
fields: unmatched records leave unused fields unforced. The strict adapter
forces these operations eagerly; allocation, work order and retention differ.
No balanced tree, hash join or alternative relational algorithm is substituted.

SML reads complete file byte strings instead of Haskell lazy file characters;
numeric/tree demand is preserved after that input representation change. Inputs
are positive ASCII integers fitting supported widths. Profiles take the original
first 125/2000/all27000 records from both files without reordering or regeneration.
Subsets retain their origin but change size/selectivity; they contain 0/28/2700
matches. Large preserves the original complete workload and build heap settings
remain recorded separately. No universal large SML execution is claimed.

The full sorted five-field join is checked against original GHC with a read-only
observer and independent dictionary-based relational joins. Every result field
is consumed rather than merely printing forceTree's unit result. The added
rendering/validation is included. Demand tests verify unmatched fields remain
unforced, lookup boundaries and duplicate rejection. Dynamic insertion, search,
structural sharing and forcing are source hypotheses until measured. References:
original submission/mail and the nofib survey; historical timing tables are
provenance, not current comparative measurements.

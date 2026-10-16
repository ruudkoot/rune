# Last Piece board search

Recorded 2026-10-16. Both variants pass all 56 smoke/normal cases across Rune's
four engines at both levels and all six managed native hosts. All twenty
semantic/negative checks pass all ten configurations twice, with Rune O0/O2
and native defaults. Eight normal count samples agree; existing budgets are
unchanged and these new profiles are unbudgeted. Six serial native smoke
samples validate MLton, SML/NJ and Poly/ML adapters. Counts and single-sample
diagnostics remain separate from headline timings.

The unmodified original reproduces its complete 300-byte fixture and three
solutions. Prefix calls and an independent bitmask model agree on complete
boards/output for 0/2/8/13 remaining pieces, including the source's reversed
skipped-prefix choice ordering. Full input visits 103513 search states; original
tree statistics report 59488 failures and three solutions. The eight-piece
reference has 76 states, 46 failures and one solution.

The persistent map retains containers0.6.7's specialized size-balanced rotations,
not a different balanced-tree algorithm. All 256 insertion-prefix shapes agree
with original containers. Fresh-key insertion makes omitted pointer-identity
shortcuts inapplicable to the workload. Candidate/remaining-piece sharing,
lazy child search, source offset/anchor preconditions and sex transitions remain.
The strict variant eagerly constructs the finite result tree. Both reproduce
all three full original boards in bounded Rune preflights.

Smoke is a valid two-piece subproblem with other pieces preplaced from the
reviewed first solution. Normal is the fixed full puzzle. No artificial larger
board/piece set is introduced. SML builds its inputs from exact embedded data.
The used-domain renderer preserves every source byte, including indented blank
lines; it does not claim the complete external pretty API. Wrong/truncated/
extra output is rejected before a result or measurement is accepted.

Pinned dependency sources/notices, witness data, independent model, state/map
references, source identities and all raw results are retained. No prerequisite
compiler/runtime feature or universal larger-instance validation is introduced
or claimed. M3 remains in progress.

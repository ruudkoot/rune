# pretty-strict provenance

Selected evaluation: strict metadata fields, CharSeq nodes and output.

## Algorithm and workload

Construct a higher-order document containing the -42/@/string header, comma-space
line and a hanging label followed by repeated xxxxx words. Pretty functions take
width and vertical context and return text, last-line length, emptiness and fit
metadata. A separate CharSeq tree stores append/indent/newline/string/character
nodes; flatten it with an indentation worklist, then append the Main newline.
Preserve this metadata-driven layout and tree traversal rather than replacing
the benchmark with direct construction of its known output string.

## History, authorship, revision and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/pretty/Main.hs,
Pretty.hs, CharSeq.hs, Makefile and pretty.stdout. The selected headers state
no author or separate redistribution notice. Retain the files and comments
about historical nhc/hbc behavior without inventing attribution or a license.
Explicit pretty-lazy/strict names distinguish evaluation variants. This is the
pinned flag-based implementation, not a replacement modern pretty library.

## Known behavior and variant differences

The source uses ppCat, which keeps all repeated words beside each other. Width80
does not wrap its default 50 words; the hang decision chooses a new indented
line. Tabs represent each complete group of eight indentation columns. Empty
string differs from nil; trailing spaces, the final newline, and raw embedded
newlines remain observable. ppNest applies only in vertical context. Retain the
source's horizontal contexts for both ppHang candidates, including its TODO.

The lazy variant memoizes whole pretty results, individual metadata fields,
CharSeq nodes and character output. Fit/emptiness tests can avoid unused child
results or layout alternatives. The strict variant evaluates finite metadata,
CharSeq and output nodes eagerly. Both retain a memoized cyclic word-input
stream with a finite take boundary: forcing an infinite strict producer is
not substituted for the source input. Complete output bytes agree.

## Portable SML translation and representation

SML97 implements the required document combinators, append/indent worklist,
short-circuit flags and character lists. Field delays preserve where-bound
sharing and non-demand; ordinary strict Boolean function calls would force too
much. Source constructors whose nil/indent simplifications were commented out
remain unsimplified. Selected ASCII literals use SML char lists; no Unicode
workload is claimed. Source negative integer spelling becomes '-' in output,
while bounded counts/widths fit even 31-bit Int.

The port covers the benchmark's required APIs and adds source combinators used
by edge tests. Unused PprStyle and numeric-formatting exports remain in the
retained upstream files, without claiming a complete general-purpose library.
Each invocation constructs the document/results anew; only constant constructor
cells and immutable input values are shared. Checking consumes every byte and
EOF and reports width:words:bytes rather than writing the formatted document to
stdout. Reference I/O and validation costs are measured work.

## Profiles, checks and diagnostic questions

Smoke width20/10 words uses the source ppShow/take interface. Normal preserves
width80/50 words and the pinned 343-byte output. Selected large width80/5000
words has a complete 30043-byte original/independent reference. The driver bounds
width to0..65535 and words to0..5000. No universal size argument or acquired data
is introduced.

Unmodified GHC output agrees with the fixture. Parameterized original calls and
an independent main-document layout model agree at empty, one-word, fit-boundary,
smoke/normal/large inputs. Eleven original combinator edge layouts agree with
independent expected bytes. Tests cover unused alternatives, negative-width
short circuiting, shared child metadata/text, nil indentation demand, and exact
spaces/tabs/newlines. Changed bytes/whitespace, truncation and extra output fail.

Source-based questions include closure allocation, metadata selection, lazy
record sharing, eager alternative construction, CharSeq traversal, worklist
retention and output lists. They remain hypotheses until source/measurement
analysis establishes them. Standard reports compare identical SML; Haskell is
an original correctness reference. Large execution is claimed only when
recorded. The maintained nofib source and suite measurement literature provide
context; a general pretty-printing paper does not specify these exact flags,
TODO behaviors or output bytes.

# maillist provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/maillist/Main.hs`.

## Algorithm and history

Paul Hudak, January 1992, is credited in the header. The original source,
LaTeX style explanation, Makefile, runtime files and stdout fixtures are
retained with SHA256 identities. Individual program/dataset licence terms
are unspecified. The pinned inputs contain synthetic Name/Address/City/Country
labels, rather than a newly acquired mailing list.

Preserve blank-line paragraph splitting, a leading blank paragraph, four-line
entry padding/truncation, 35-character warning threshold, 30-label pages, three
nine-label long blocks and one three-label short block. Preserve exact braces,
spacing, backslashes, line endings and final document footer. This is the original
mailing-label layout, not a replacement templating or table algorithm.

## Translation and runtime behavior

Portable SML97 TextIO supplies openOut/openAppend/output/close operations.
Every original appendFile operation still opens/appends/closes separately;
no buffered whole-document substitution removes the file-I/O workload. Each
iteration rereads the input and overwrites a fixed output.tex in the fresh
program directory. This replaces the original input-name.tex path while
preserving output identity and repeated creation/appending work.

Command prompts, conversion notices and exceptional interactive filename
retry are replaced by fixed checked arguments and controlled result streams.
Long-line/truncated-entry messages are counted and consumed instead of printing
their contents. Every complete output file is read back and compared with a
reviewed fixture, adding one read/validation per repetition. Actual byte counts
and diagnostic counts contribute to the reported result. These adapter/check
costs are included. Paragraph allocation, append-call overhead, process/runtime
I/O and output copying are source-derived hypotheses until measured.

## Inputs and validation

Profiles retain original FAST/NORM/SLOW files: 30/3626/10043 bytes.
Smoke runs once; normal/large preserve the original 100 iterations. The inputs
use ASCII and lines of maximum length 8. Complete GHC output and an independent
30-label page formatter agree for all three fixtures: 630/5227/14298 output bytes.
No warnings occur in these original profiles. Boundary checks additionally
cover leading blanks, entry truncation, padding and long lines. Large SML
execution is not universally claimed. References: original Hudak description,
retained LaTeX style and nofib application survey.

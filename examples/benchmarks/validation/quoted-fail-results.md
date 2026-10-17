# Quoted correctness exceptions

The measurement classifier now recognizes the quoted Fail payload emitted by
Poly/ML's General.exnMessage alongside bare and colon-prefixed messages.
An explicit incorrect-result marker remains distinct from an unrelated runtime
failure, and every rejected case supplies no accepted timing.

The regression uses the actual Graph500 output form and controls for bare,
colon, quoted-correctness and quoted-runtime messages. Existing end-to-end
numerical/runtime exception checks, four-compiler statistics checks,
instrumentation rejection and matrix-worker isolation all pass.

Full DEBUGINFOD_URLS= make JOBS=4 check exits zero. Its catalogue contained
1114 profiles because the next linear-solver imports were registered in the
same worktree; their broader program validation is recorded separately.
The classifier change affects status labels, with no benchmark or measurement
arithmetic change. Complete targeted and acceptance transcripts are retained.

Historical Graph500 samples keep the original recorded category, while their
reviewed disposition table identifies the explicit incorrect result. The fix
changes future reports and does not rewrite raw historical observations.

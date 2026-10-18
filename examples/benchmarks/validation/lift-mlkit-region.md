# Lambda-lifter auxiliary ML Kit region crash

The first auxiliary test program traversed seven fixed input ASTs using
List.app need and List.app strict. Managed ML Kit 4.7.23 crashed during
region/effect analysis, reporting cannot subtract effects, Mul: diffef failed
and instantiate.doSubst or diffef failed. Both attempts compiled no runnable
test, so their 128 assertions are incomplete rather than failed or passed.
The other eighteen groups pass all 64 checks.

The benchmark kernels and both complete 4000-iteration application pilots
compile and validate on that host. Replacing only the fixture traversal with
seven explicit calls per policy also compiles and passes the same 64 checks.
This narrows the observed trigger to that auxiliary caller's region-analysis
context; it is not a minimized proof of a specific faulty compiler pass.

The public tests use common explicit fixed calls and keep synthetic fixtures
outside the benchmark kernel. All twenty final Rune/host groups pass every
assertion, including ML Kit. Earlier valid source, full compiler diagnostics,
passing normal applications and the equivalent-call probe remain archived.
No expected output, algorithm, host-specific source or runtime setting is
changed. No issue was posted.

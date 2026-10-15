# Acceptance debugger environment, 2026-10-15

The initial full acceptance invocation reached the native debug tests, then
waited in LLDB with its target stopped under ptrace. This environment configured
`DEBUGINFOD_URLS=https://debuginfod.ubuntu.com`. Its transcript is retained in
[the interrupted run](oct15-heaps-ansi-arrays-debugger-wait.log); terminating the
waiting debugger made that invocation exit 2. It is not a passing acceptance run.

A bounded fresh LLDB probe with the original breakpoint/program and an empty
DEBUGINFOD_URLS returned immediately and stopped at nqueens.sml:12. A separate
probe changing ASLR alone timed out after 30 seconds. These observations isolate
a useful environment setting; no compiler or debugger-test source was changed.

The first complete baseline rerun used:

```sh
DEBUGINFOD_URLS= make JOBS=4 check
```

It exited 0 before the final ANSI demand correction, grep imports and routine
expansion. [The baseline transcript](oct15-heaps-ansi-arrays-acceptance.log) records
675 catalogue profiles, routine benchmark correctness/negative metadata checks,
331 language fixtures per compiler, performance budgets, bootstrap and agreement
for 498 programs across seven compiler builds. runedoc and runeopt builds also
agree. GDB and LLDB both run; the debugger checks are enabled.

After the final ANSI continuation correction, grep import and routine expansion,
`DEBUGINFOD_URLS= make JOBS=4 check` was rerun and exited 0 with 681 profiles and
16 routine workloads. [Its final transcript](oct15-benchmarks-681-acceptance.log)
also records 498 matching bytecode comparisons and matching runedoc/runeopt
builds. This is the acceptance result for the final imported sources.

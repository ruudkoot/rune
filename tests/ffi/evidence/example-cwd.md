# Example inventory in isolated working directories — 2026-10-23

The interrupted final run `20261023-130556-3104841` failed
`laws/MONO_ARRAY2@LargeIntArray2` before its first law. The new example catalog
performed relative filesystem lookups during `Oracles` initialization, although
the law controller starts in an isolated working directory with
`RUNE_TEST_ROOT` pointing to the repository. The original failed receipt remains
preserved; it reported 18 passes, two skips and one failure before interruption.

Filesystem enumeration and directory tests now use `Sh.fromRoot`; the catalog
still returns slash-separated repository-relative logical paths. Its audit
also switches into a private empty directory, checks that the complete program
list remains identical and relative, and restores the original directory.

Focused validation with the complete revised runner and frozen final VM:

- Normal repository audit and external isolated-CWD audit: PASS, identical
  classification, ten standalone examples and the mock `.build` project.
- Exact previously failing `laws-one MONO_ARRAY2.rbc LargeIntArray2`, launched
  from an isolated directory using the original run's law bytecode: PASS,
  all six laws, 100 cases each.
- Actual mock-project position check: PASS with nonempty disassembly and
  application source positions.

Artifacts and streams are retained under `build/example-cwd/` and
`tests/out/example-cwd*/` in the isolated SDL worktree. The repair changes test
filesystem lookup only; compiler/runtime/Basis sources and earlier host
bytecode-agreement results are unchanged.

# Circuit input inventory review

Recorded 2026-10-16. SCS passes the filename stem runtime_files/inverter through
FAST/NORM/SLOW arguments; Main.hs appends .in when opening the file. Literal
argument discovery alone therefore missed runtime_files/inverter.in. The
fixture scanner now includes .in data files. A source-based regression checks
this exact stem case.

All 46 inventory tests pass, and all 861 entries reproduce from the five clean
pinned trees. The reviewed regeneration changes only the SCS input list, adding
real/scs/runtime_files/inverter.in. Program dispositions, source digests,
members and revisions remain unchanged. This is an audit correction; SCS
remains scheduled for import.

The retained input has SHA-256 `278f904780567d932229b6dc04ab5bfe0d211d008d38828311a17e4a296a1256`. Original program/data and
authorship/notice inspection remain required at import.

[Raw checks](inventory-oct16-circuit-input.log); [reviewed field change](inventory-oct16-circuit-input.json).

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 901 catalogue
profiles, bounded routine correctness and all compiler comparisons.
[Complete transcript](oct16-circuit-inventory-901-acceptance.log).

# Integrated Runeffi release acceptance — 2026-10-23

State: **complete for the specified delivery, with the limitations below**.
Implementation is delivered in the isolated `runeffi` branch/worktree, based on
refreshed `origin/master` commit `e875edca96ac5a15af83986b633c7f74a95aa144`.
The original checkout and human notes are unchanged.

## Source identity and applicability

The runtime/Basis implementation is frozen at `18c353b49`. The complete
binding-source snapshot is `ddba4faad`; subsequent functional repairs are
`49d5113a6` (test inventory filesystem lookup) and `0e7f4cbfd` (complete SDL
source installation/distribution and derived indexes), `9fc0c929c` (native
debug oracles), `662b19fff` (Windows installer/interactive launcher paths),
and `19ae987e0` (strict host-defect judges and the unchanged MLKit control).
Final follow-ups are `e7f79b72e` (Windows installer/uninstaller guards),
`7b393bcce` (the parent-controlled POSIX test child), `ddf5e0032` (canonical
Win32 sources under `lib/ffi`, moved byte-for-byte), and `7997c95a4`
(regenerated POSIX documentation).
The final cumulative validation worktree is `runeffi-check-final`, source
`1a3ffbb40`. A direct tree comparison verifies that compiler/runtime/library,
header/policy, build/install and test implementation inputs match delivery;
documentation and acceptance records evolve separately. Earlier failed runs
retain their own snapshots and results.

Final source applicability checks compare all 591 production blobs in the
host-suite manifest with the delivery files: every blob is unchanged. All
32 canonical Win32 generated files match their preceding locations byte for
byte. The only later Basis fixture change has its own focused host and
portability receipt below. These comparisons establish source applicability;
they do not replace the recorded executions.

Independent frozen worktrees keep long checks from reading changing binaries
or source. Every receipt states its own source, commands, tools and execution
kind. Earlier component snapshots remain historical records. The final
performance, optional-runtime, packaging and host reports qualify their
applicability explicitly; their results are not inferred from source inspection.

## Milestone evidence

| Milestone | Delivered gate and primary receipts |
| --- | --- |
| M0 | Contracts, research, original-source provenance, ABI and concrete inventories: [baseline](m0.md) |
| M1 | Reusable SML C frontend and unmodified-header/compiler comparisons: [frontend](m1.md) |
| M2 | Separate declarations/layout/policy, diagnostics and coverage: [binding model](m2.md) |
| M3 | Optional generic runtime bridge and scalar/pointer C oracles: [foundation](m3.md) |
| M4 | Target layouts, memory/text/ownership/errors and generated adapters: [layout](m4.md), [runtime marshalling](m4-runtime.md), [promoted variadics](variadic.md) |
| M5 | Bounded owner-thread callback entry in all delivered engines, GC/reentry and lifecycle guards: [callbacks](m5.md), [portable images](m5-images.md) |
| M6 | Deterministic generator, raw/public sources, publication faults/races, virtual caching and host agreement: [generator](m6.md), [Windows CLI](windows-generator.md), [final bootstrap/runtime](final-runtime.md) |
| M7 | All 53 SDL operations plus three driver support operations, complete three-target sources and real GUI/REPL runs: [SDL](m7.md), [generated sets](sdl-generated.md), [final GUI](sdl-final-gui.md) |
| M8 | Native 32/64-bit Windows kernel/user/GDI inventory, creation/nested callbacks, drawing/text and actual REPL: [native Win32](m8.md), [final Windows](final-runtime.md) |
| M9 | Same application and shared contracts on native/SDL/mock, deterministic traces and four rejected mutants: [providers](m9.md), [driver](m9-sdl-driver.md), [planted faults](win32-mutants.md) |
| M10 | Pinned dependencies, portability, installation, optional builds, measurements and cumulative acceptance: records below |

## Integrated checks

| Gate | Actual result |
| --- | --- |
| Final cumulative `make check JOBS=8` | **19,696 PASS, 3 documented SKIP, zero failures**, 1,770.7 seconds wall / 13,102.9 seconds CPU; source `1a3ffbb40`, run `20261023-160520-21671`; [commands, identities and exact skips](release.json) |
| Combined strict VM/Windows/portability profile | **10,197 PASS**, zero failures/skips; nested portability Basis **2,406 PASS**; [source and scope](integrated-vm-profile.md) |
| Final Windows FFI/shims/SDL/native Win32 | **15 PASS**, zero failures/skips; 1,278.2 seconds; [receipt](final-runtime.md) |
| Final model/generator hosts and generated-fixture ASan/UBSan | **22 PASS**, zero failures/skips; 340.6 seconds; documented MLKit expected-failure classification retained; [receipt](final-runtime.md) |
| Final Basis host matrix | **3,198 PASS**, **168 documented SKIP**, zero failures; 4,216.8 seconds; [receipt and all skip reasons](final-host-acceptance.md) |
| Full ordinary-library host suite | **217 strict runner passes**; 170 default native programs pass and 34 have documented explanations; separate unchanged MLKit control **32/32 PASS**; [actual outcomes](final-host-acceptance.md) |
| Repaired POSIX fixture follow-up | **46 runner passes / 2 existing NA skips** in the focused host matrix; eight portability runs **77/77 assertions each**; [source delta and causal limits](posix-stop-followup.md) |
| Final `FFI=no` | Fresh build/bootstrap plus **58 focused commands PASS**, including both interpreters/JIT modes, `SYS=none`, fresh REPL APIs and native execution; [receipt](final-noffi.md) |
| Linux32/AArch64/PowerPC64 FFI | Native32 and explicit QEMU execution of C oracles, both interpreters, AArch64 JIT tiers, raw variadics, callback status and generated public contracts; [receipt](m10-linux-portability.md) |
| Final dependency prefixes | All seven native/headless/Windows prefixes built and verified; four actual Windows admission probes exit zero; [receipt](dependencies-final.md) |
| Generator bootstrap | **All seven compiler variants** emit byte-identical delivered 868,680-byte generator; **747 input hashes** unchanged; [receipt](final-generator-seven-hosts.md) |
| Actual REPL use | Scalar public/raw, SDL and native Win32 retained resources survive later declarations and collections; final variadic/status APIs also execute; [scalar](scalar-repl.md), [SDL](sdl-final-gui.md), [final APIs](final-runtime.md) |
| Performance | Five paired 50,000-operation samples per interpreter/JIT mode; **315 raw observations / 63 distributions**, source/binary freeze and zero-live-resource checks pass; [final reports](performance-final.md) |
| Final packaging/relocation | **25 successful Linux commands**, **14/14 actual Windows commands**, exact 204 source assets, moved-prefix native/REPL/relink calls and guarded uninstall; [receipt and archive scope](final-packaging.md) |
| Installed delivered GUI examples | Nine original source/build files unchanged; mock, real Linux SDL, SDL hello rendering/normal close and actual installed Windows32/64 native GUI PASS; [receipt and later installer guards](installed-examples.md) |
| Canonical Win32 library follow-up | **32 files / 3,800,012 bytes unchanged**, both profiles regenerate and strictly check, all five derived library indexes build, both archives retain 204 exact assets, actual installed Windows GUI and cleanup **10/10 PASS**; [receipt](win32-canonical.md) |
| Completed metadata packaging | Both current fixture archives contain all **204 exact source assets**, all five generated library indexes build, seven frozen runtime/compiler/image hashes stay unchanged, and completion updates alter no declaration or binding policy; [final receipt](final-status-packaging.json) |

The 168 matrix skips comprise 102 intentional Rune-only extension absences on
other hosts and 66 documented SML/NJ32 dependency/width limitations. Rune's own
extension suites run. The documented Poly/ML Unix load defect retains its
expected-failure judge. These categories are separate from a missing required
tool or an unexecuted native runtime check.
The 34 explained ordinary-library outcomes comprise 19 host bugs, 13 absent
host facilities and two recorded flaky failures. They remain failed native
program outcomes, even though the configured acceptance judge passes them.

The cumulative suite's three skips are the two existing native interrupt
limitations and the optional pinned GMP dependency, which is not installed
in this validation tree. They are distinct from the separate host-matrix
skips. Before the full run, documentation consistency passes **11/11** and
all five canonical SDL/Win32 generated sets pass their strict checks.

After completion metadata is promoted, the delivery tree again passes
documentation consistency **11/11** and strict verification of all five
generated sets. Checks of **22 documents / 132 local links**, all **87**
vendored SDL and **1,906** pinned SDK files, and the 26 requirement owners
pass. The only non-documentation changes after the full validation snapshot
are four completion-metadata JSON files; reviewed declarations, policies and
runtime sources remain unchanged. The final JSON receipt records this scope.

## Limits and retained failures

[Integrated regression findings](integrated-regressions.md) retain the failed
first full suite, interrupted initial matrix and isolated-directory startup
failure. Focused fixes and later runs do not relabel those attempts. Historical
GUI stress timeouts also remain recorded; the completed bounded GUI collection
run has its own explicit interval, collection count and successful receipt.

The delivered capability matrix is [documented separately](../../../docs/ffi/capabilities.md).
Audio/GPU, foreign-thread SML entry, other foreign-language backends and future
direct native linking remain outside the delivery. Physical AArch64/PowerPC64
hardware and GUI execution there are not claimed. Upstream libffi/SDL test
suites and a fresh remote CI run are not implied by local acceptance. No branch,
pull request, archive or binary has been published.

The classic Windows installer explicitly refuses paths beyond its copy-tool
limits and requires PowerShell for read-only validation. Its launchers can
move; the absolute uninstall manifest requires restoration to the original
prefix. Native Windows `.build` examples use documented relative paths.
These tested boundaries are recorded with the installed examples.

Native resources remain process-local. Image version 15 records the identity
high-water floor; users must recreate version-14 images. Package receipts
distinguish source/fixture archive tests from production all-architecture binary
release checks. Native allocator metadata/libffi closure/JIT memory costs are
outside the performance payload measurement and remain unquantified.

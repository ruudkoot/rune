# Final Runeffi installation and relocation acceptance — 2026-10-23

The frozen runtime/Basis source `ddba4faad9fa5f8540367f1067be35d1b561936d`
passes enabled installation acceptance in the isolated
`/home/ruud/rune/.worktrees/runeffi-package-final` worktree. The final checks
include the packaging repair `3b2f63a77` and Windows launcher repair
`c241e040d`. No runtime, Basis, compiler bytecode, VM or REPL image changed.
All 68 recorded runtime source hashes still match the original build record.

The [JSON receipt](final-packaging.json) embeds the independent artifact
snapshot, command arguments, output/error text, witness scripts, source-asset
hashes and retained failures. Its Linux command series has 25 successful
commands and one failed tracing-tool attempt followed by its successful retry.
The final Windows series passes all 14 commands. Focused permanent packaging
and Windows regression scenarios also pass. Documentation consistency passes
11/11 with one worker; its command and event path are in the JSON receipt.

## Packaging defects repaired

The source installer initially returned success while omitting the complete
generated SDL source tree. Distribution initially refused the missing derived
MANIFEST of a committed immutable SDL set. The repaired Make targets generate
those indexes; installers and both archive formats retain complete source sets,
including virtual `.build` pointers, signatures, C shims, dependency manifests
and declaration provenance. A planted regression fails with the old builder
and passes with the repaired builder. All 204 tracked files under `ffi` and
`lib/ffi/sdl` match their source bytes in both archives and every tested
installation. This includes all 48 committed SDL generated assets.

After deleting only the three derived SDL indexes, this command regenerates
them with the independently built and accepted FFI-disabled compiler/VM:

```
make -j2 FFI=no BOOTHOST=nofi-bootstrap manifests JOBS=2
```

No libffi-enabled VM or runtime rebuild is needed for those indexes. The
derived MANIFESTs remain ignored build outputs.

Calling the original Windows installer from another directory exposed an
independent argument-parsing bug: plain `SHIFT` replaced `%0`, changing the
meaning of `%~dp0`. The same bug broke installed `rune.cmd -i`. `SHIFT /1`
preserves the launcher path. The permanent Windows distribution scenario now
installs from outside the archive and uses a neighbouring stub to verify
interactive argument forwarding.

## Linux installed source tree and archive

The actual source installation was moved to a path containing spaces before
execution. Its current generator creates and checks the scalar fixture, then
the installed compiler consumes its generated virtual build entrypoint.
Both stack and register VMs execute public and raw calls returning **42**,
with collection stress 7, heap verification and zero live resources after
closing sessions. The installed `runeopt` produces a native executable with
the same result and cleanup.

The installed REPL restores the current image, exposes `prepareVariadic` and
`callbackStatus`, creates a callback, observes/reset-checks its zero fault
status, releases it, and invokes the generated public API returning 42. The
documented 14 non-Basis support files are obtained with `--basis-deps`.
All three installed SDL target entrypoints compile. A strict installed
generator check also validates the actual committed native SDL set using
installed original headers, profile, sidecar, constants and typed field shims.

Retained static-libffi headers, archive, notices, provenance and pinned source
archive survive relocation. The actual retained runtime rebuild succeeds from
the moved tree; captured compiler arguments refer to the relocated headers
and archive and contain no original libffi prefix. That rebuilt VM executes
the current public/raw fixture with stress and verification, returning 42.
Its SHA256 is
`c5aa727d0ebdbe284c32bb5517abc5fbe852a09d7b5e2c6691ecc97af2808b36`.

The Linux archive is also installed and moved independently. Its generator
help/inspect and actual x86-64 VM calls pass. Both source and archive
uninstallations preserve an unrelated file in `bin` while removing owned files.

## Actual Windows32 and Windows64 archive installations

The final archive is installed sequentially using actual current `i686` and
`x86_64` Windows VMs in private prefixes with spaces. Every installer is
invoked from outside its archive directory, with `--no-register` and
`RUNE_INSTALL_PAUSE=1`; `registered=0` is asserted. No registry, user PATH or
start-menu integration is requested.

Each width passes installation, installed `runeffi.cmd --help`, generator
inspection matching the Linux generator's JSON for that target, current
installed REPL API availability, `rune.cmd -i` from another directory, and
uninstallation preserving an unrelated marker. All 204 source assets match
at both widths. The exact installed VM bytes match these payloads:

| Payload | SHA256 |
| --- | --- |
| Windows64 VM | `ce28be2b4110a56b53923253e0a3a700f2537549204cdcf1c86ac5245d7acfbf` |
| Windows32 VM | `01fa91e108b1025a7fcbc4d35c164f189e491b33631ec3469aa390d5d6efe0da` |
| Shared current REPL image | `e7b2fbdb2ff8730307adcacda8b9bb7b66d5bc433cb1af3d8fccbd2ab954ba51` |

## Limits and failed attempts

These are local acceptance archives built with `make-dist --fixture`.
The Linux x86-64 and both Windows payloads are actual frozen binaries;
other Linux architecture slots deliberately reuse the x86-64 fixture map.
This is **not** six-architecture production distribution acceptance or a
published release. The native VM retains its existing system GMP dependency.
Separate portability, GUI, dependency and global regression receipts apply.

The original asset omission, missing-MANIFEST failure and negative fixture
are retained. The first tracing wrapper used a relative GCC argument zero;
GCC then could not locate `cc1`. Correcting only the tracing wrapper to pass
the absolute compiler path allowed the identical product rebuild to pass.

The first Windows outside-directory install failed to find VERSION. Running
temporarily from inside the archive passed 12 checks but did not satisfy the
contract. Independent native probes then demonstrated `%0` changing under
plain `SHIFT`, and actual installed `rune -i` failed with Windows error 9009
(observed subprocess status 49). The final 14 checks run without that CWD
workaround and pass. Earlier probe-log setup errors, a too-short private-prefix
cleanup timeout, and an initial focused scenario missing its archive-producing
prerequisite are recorded as harness attempts, not clean product acceptance.
The owned probe prefix was subsequently removed outside the restricted
sandbox. No failed attempt is counted as a passing final check.

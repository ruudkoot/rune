# Installed GUI examples outside the checkout — 2026-10-23

**PASS.** The unchanged delivered examples execute from external application
trees using relocated installations, installed libraries and installed/copied
generated assets. This closes the explicit M10 installed-example gate in
addition to the [scalar packaging acceptance](final-packaging.md).
The [JSON receipt](installed-examples.json) retains source/artifact hashes,
every command, dependency reports, window automation and failed attempts.

The runtime/Basis and binding sources are the same frozen `18c353b49` /
`ddba4faad` delivery used by the previous final receipts. All 68 runtime
source hashes and the copied compiler, VMs and image remain unchanged.
Installer-only safety follow-up `ed4c57f87` is validated separately below;
these results do not turn the ongoing/frozen cumulative suite into a check
of later installer source.

## Actual examples

All nine copied application/entrypoint/build files match the repository bytes.
The two application source SHA256 values are:

| Original source | SHA256 |
| --- | --- |
| `examples/win32/app.sml` | `a59e868cd661b0f2751d24a028ed3af2eeca0772c73a0ba80af559b1714c6b17` |
| `examples/sdl/hello.sml` | `8262751e50093f259b053335c9f0f04827941a0db63c573afc087f6d09b12df6` |

The Linux source installation moves to an owned `/tmp` prefix with spaces
before compilation. A local `ffi` link points to its installed `ffi-assets`;
all compiler dependency paths resolve within the installed/application tree.
The application has no source or execution dependency on the checkout.

- The exact Win32 application passes through the pure mock.
- The same source passes on a real SDL desktop with both stack and register
  interpreters, collection stress 101 and heap verification. Both print
  `PASS shared Win32 application: 0` after three timer events and cleanup.
  Register execution performs 1,854 verified collections; stack performs
  1,856. No dummy/headless video override is used.
- The unchanged SDL hello builds through its original entrypoint. An external
  X11 helper observes its real mapped 640×360 window and distinct rendered
  pixels: background `0x181c24`, rectangle `0x5ab4e6`. The helper sends the
  ordinary `WM_DELETE_WINDOW` client message. The application consumes its
  quit event, executes its renderer/window/SDL cleanup and exits zero with
  empty stderr. No source edit, process kill or synthetic in-process SDL
  event is used to claim this pass. This run explicitly selects real X11.

Both actual Windows32 and Windows64 archive installations also move before
compilation/execution. Their installed compilers compile the unchanged
`app.sml`, `native-main.sml` and `native.build`. Public libraries are loaded
from the installed prefix; FFI fragments/generated sources are copied from
that installation and checked byte-for-byte. Dependency reports contain no
checkout inputs. The target shim DLLs are copied into the external client
directory; their original generated C hash matches both installed sets.

Each native Windows register interpreter runs the actual GUI with collection
stress 101 and heap verification, draws with GDI, processes the three timer
events, closes and prints the same success marker. Windows64 explicitly
disables JIT; Windows32 has no JIT claim. These are real system GUI calls,
not SDL or mock execution. Both installations use `--no-register` and verify
`registered=0`; no registry, PATH or start-menu change is requested.

Supported-location uninstalls preserve unrelated `bin` markers. Windows
prefixes are restored to their recorded original location before cleanup;
the legacy absolute uninstall manifest is explicitly qualified below.

## Windows installer safety follow-up

The deeper first prefix exposed XCOPY returning success with only **7 of 13**
Win32 generated-set files. Source files were intact; six longer target names
were missing, including `native.build` and declaration provenance. A read-only
PowerShell preflight now rejects unsupported source/target file lengths
(260 or more UTF-16 code units), directory lengths over 248, enumeration
errors and an unavailable preflight tool **before creating the target**.
The limits follow Microsoft's
[Windows path-length contract](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=powershell).
This is explicit refusal, without changing system long-path settings or
promising extended CMD path support.

Moving a Windows prefix also exposed an old uninstall loop: its manifest
contains absolute original names, while the directory-cleanup boundary used
the moved prefix. Native CMD reports zero after failed `rmdir` in the probe,
so testing only ERRORLEVEL did not stop the walk. The owned looping process
was identified and stopped after 404.6 seconds, and retained files were
restored to their original location for supported cleanup.

Uninstall now validates every canonical manifest entry and its self-record
before registry changes or deletion. A moved/out-of-prefix manifest rejects
without removing installed files. Directory cleanup checks existence,
handles missing owned directories and has explicit drive-root/depth bounds.
Windows launchers remain movable; uninstall requires the original prefix.
No relocatable uninstall feature or Windows `.build` path redesign is claimed.

The final actual `distribution/windows-installer` scenario passes against
the repaired templates. It checks long target/source and missing-PowerShell
refusal without a new prefix, exact generated bytes and DISTMANIFEST tracking,
moved-prefix refusal, out-of-prefix manifest refusal with both installed and
outside files preserved, interactive argument forwarding, missing owned
directory cleanup and normal uninstall. Three independent actual Windows
preflight negatives also pass. Documentation consistency passes **11/11**.

## Compatibility and retained attempts

The current Windows `.build` resolver requires relative forward-slash paths;
drive-qualified absolute project/virtual paths failed in the initial attempts.
The successful command runs from the copied `examples/win32` directory:

```
INSTALLED_RUNE --library ffi/win32/native --target=registers \
  --build native.build --path WIN32_GENERATED=generated/32 -o OUTPUT
```

Use `generated/64` for Windows64. The existing `../../ffi` fragment tree is
an exact copy of installed `ffi-assets`. All source/build files remain unchanged.
Long unresolved relative spellings also exceeded CMD-era file access limits;
the successful entrypoint keeps those spellings short.

The receipt retains those compatibility failures, the original partial copy
and stopped uninstall, and local witness repairs: resolving relative Basis
names under installed `basis`, supplying the documented model library,
omitting register-only flags from the stack VM, ignoring generated client
cache files during source-asset comparison, and a continuation variable-name
collision. Successful final commands do not relabel these attempts.

# Original Microsoft SDK inputs

Install **Windows SDK 10.0.22621.0** from the
[Microsoft SDK archive](https://developer.microsoft.com/en-us/windows/downloads/sdk-archive/).
Select the desktop C/C++ headers and libraries. Accept and retain the
installer's Microsoft licence. This repository does not redistribute those
headers or infer redistribution rights from win32metadata's MIT licence.

Set `RUNEFFI_WINDOWS_SDK` to the versioned `Include/10.0.22621.0` directory.
Its `um`, `shared` and `ucrt` directories are the include roots. On WSL an
ordinary installation is below
`/mnt/c/Program Files (x86)/Windows Kits/10/Include/10.0.22621.0`.
That path is an acquisition example, never a generated-code dependency.
`source.json` lists relative original paths and their SHA-256 hashes;
validate the installed bytes before generation. Different versions or
modified bytes require an explicit source-manifest change and fresh tests.

Use `Windows.h` as the entry header. Targets define `_WIN32`, with `_WIN64`
and `_M_AMD64` for x86-64, or `_M_IX86` for x86; the target manifest fixes
widths independently of generator-host types. Required Microsoft extension
and SAL handling belongs to the SML frontend. MinGW headers are useful for
independent native ABI probes but never replace these generator inputs.

The SDK also includes original compiler-runtime headers. Install the
Visual Studio 2022 C++ tools **14.40.33807** and select their `include`
directory as `RUNEFFI_MSVC_INCLUDE`. `compiler-source.json` hashes its 153
original C headers; these also remain external under the Microsoft licence.
The compiler profile uses `_MSC_VER=1940`. The SDK and compiler include
roots are separate dependencies and both must match before regeneration.

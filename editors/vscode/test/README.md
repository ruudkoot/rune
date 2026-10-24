# Editor test isolation

`editor.cjs` downloads the selected VS Code build into the worktree and
uses a private user-data directory, extensions directory and workspace.
Its default version is the minimum supported 1.106.0;
`VSCODE_TEST_VERSION=1.143.1` selects that release explicitly. Profiles
separate settings; operating-system isolation is an additional test layer.

For Linux isolation, use a private copy of the Rune project in a bubblewrap
mount/user/PID/network/IPC namespace, read-only editor/runtime files and a
private Xvfb display. Do not map the host home, Windows drives, WSL interop
socket or desktop display. Keep test profiles and output in a dedicated
writable directory. The 1.143.1 acceptance recipe and its mount policy are
retained in `build/lsp-debug/acceptance`; see
[the debugging record](../../../docs/plans/language-server-debug.md).

## Windows Sandbox

`windows-sandbox-launch.ps1` starts a prepared test case minimized, captures
its process identities and closes only those processes after the guest
has saved its evidence. The guest does not shut Windows down, avoiding
the Sandbox shutdown notification. An existing Sandbox is left alone.
Ownership uses a fresh guest handshake and PID plus process creation time;
the host saves this proof outside the guest's writable mapping.

Prepare a case directory containing `input`, an empty `output`, and
`rune.wsb`. Its two mappings must be the input directory read-only at
`C:\Inputs` and the output directory writable at `C:\Results`. Networking
and clipboard redirection must be disabled. Example configuration:

```xml
<Configuration>
  <vGPU>Disable</vGPU>
  <Networking>Disable</Networking>
  <AudioInput>Disable</AudioInput>
  <VideoInput>Disable</VideoInput>
  <PrinterRedirection>Disable</PrinterRedirection>
  <ClipboardRedirection>Disable</ClipboardRedirection>
  <ProtectedClient>Enable</ProtectedClient>
  <MemoryInMB>4096</MemoryInMB>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Temp\RuneLspSandbox\input</HostFolder>
      <SandboxFolder>C:\Inputs</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
    <MappedFolder>
      <HostFolder>C:\Temp\RuneLspSandbox\output</HostFolder>
      <SandboxFolder>C:\Results</SandboxFolder>
      <ReadOnly>false</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Inputs\run.ps1</Command>
  </LogonCommand>
</Configuration>
```

See Microsoft's [configuration reference](https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file)
for the supported settings. The newer headless `wsb` CLI requires Windows
11 24H2 or later; this launcher also supports the older desktop client.

The prepared inputs are:

| File | Contents |
|---|---|
| `code.tar` | An official portable Windows VS Code build, with `Code.exe` at the archive root. |
| `extension.vsix` | The package under test. |
| `fixture.tar` | Rune sources under `checkout/`, including generated library `MANIFEST`s, `build/config.sml` and `bin/rune.rbc`; compiled `project-replay.rbc`, `semantic-tests.rbc` and `distribution-tests.rbc` at the archive root. |

The launcher copies the guest script and editor suite from this directory
into the input before starting. The guest checks the full Rune project,
semantic protocol suite, packaged Basis/library workflow and editor
providers, including restart and error repair. All source edits use the
guest's private copy; both project and extension paths contain spaces and Unicode. Rune is
absent from the guest's `PATH`.

From a Windows PowerShell terminal in the worktree:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File editors/vscode/test/windows-sandbox-launch.ps1 -CaseDirectory C:\Temp\RuneLspSandbox
```

`-LifecycleOnly` performs a short handshake, minimization and cleanup
check without running Code. The output includes `result.json`, logs and
`lifecycle.json`; the latter records observed minimized windows and
confirmation that owned processes exited. The guest's version record is
read from the actual portable Code manifest.

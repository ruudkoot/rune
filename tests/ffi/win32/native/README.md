# Native Win32 acceptance

`bin/rune-win32-check contract 32|64` runs the shared contract and focused
native ownership/callback cases. `app 32|64` runs the unchanged shared GUI
application. These modes generate adapters from the pinned original SDK,
compile their fields with the MSVC ABI, and link them using MinGW.

`repl 32|64` starts actual Windows REPL sessions with the native provider:

```sh
make bin/rune-win32-check bin/rune-repl.img
bin/rune-win32-check repl 32
bin/rune-win32-check repl 64
```

Run outside a restricted sandbox so Windows processes can start. The Windows
VMs require libffi, and the pinned SDK/MSVC include roots must be available as
for `contract`. Optional `RUNE_WIN32_REPL_IMAGE`, `RUNE_WIN32_REPL_VM32` and
`RUNE_WIN32_REPL_VM64` select frozen compatible artifacts; their defaults are
`bin/rune-repl.img`, `bin/runevm32.exe` and `bin/runevm.exe`.

The coordinator asks the compiler for `--basis-deps` on `repl.build`, loads
the resulting additional library paths in that order, then the generated
raw signature/structure and layout signature/structure, the native provider
configuration, and `repl-setup.sml`. The built-in Basis is already in the
REPL image. The complete source order is retained as `repl-sources` beside
each command receipt. Files are ordinary REPL file arguments; subsequent
declarations use the existing repeated `-e` option.

The setup registers a class and its window-procedure closure. Later entries
declare a new function and datatype, replace a closure the procedure calls,
allocate and collect. Sending a message through the retained procedure calls
the later function, creates another window while the first native call is
suspended, collects in that nested callback, sends another message, and
destroys the nested window. Further entries repeat creation/destruction and
check propagation of an exception declared after registration. Each session
checks all six creation/destruction pairs and zero live foreign resources
after unregistering the class and closing the provider.

Every session uses heap verification and GC stress 101. Windows32 runs the
register interpreter and explicitly reports its unavailable JIT backend.
Windows64 additionally forces baseline and optimizing JIT calls with
`--jit-calls=1`.

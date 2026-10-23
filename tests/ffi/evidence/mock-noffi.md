# Shared application without native FFI — 2026-10-23

Final frozen-source acceptance, including the current API and freshly built
artifacts, is recorded in [final-noffi.md](final-noffi.md). The older component
receipt below is retained as historical evidence.

The unchanged `examples/win32/app.sml` compiles against `Win32Mock` with the
FFI-disabled release checkout's own compiler and runs on its FFI-disabled
register VM under collection stress 101 and heap verification. It opens no
SDL library, native DLL or display and prints:

```text
PASS shared Win32 application: 0
```

The compiler/runtime snapshot is `5f616d0b0`; library/application sources
come from the frozen integration tree `dd0f0e7d8` through `--lib` and the
absolute build-file path. The successful compile uses the documented
`--library ffi/win32/mock` option. An initial local invocation omitted it
and failed with an unbound `WIN32` signature; adding the documented option
passed without a source change. This is component evidence, separate from
the final cumulative release suite.

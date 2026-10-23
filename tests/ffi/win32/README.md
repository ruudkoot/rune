# Shared Win32 GUI contract tests

`contract.sml` defines `Win32ContractFn`, using only the public `WIN32`
signature and `test/unit`. The exact same test source is instantiated against
native Windows, SDL and mocks. Platform entrypoints perform provider startup
and shutdown; the functor exports its lazy `tests` tree.

```sml
structure Contract = Win32ContractFn
  (structure Win32 = Win32 val name = "shared")
structure ContractMain = Main
  (struct val name = "win32/contract" val tests = Contract.tests end)
val () = ContractMain.main ()
```

The suite compares typed observations rather than OS event streams or pixels.
It filters its own application messages, discards unused copies, consumes
posted quit status while tolerating unrelated external events, and gives every
class a unique name. Fixture cleanup attempts all registered object actions,
windows and the class, including exceptional returns. A body exception retains
priority. Creation-time handles are remembered before the constructor returns
so creation veto and callback-exception paths can be checked and cleaned.

The eleven groups cover clocks/errors/modules, creation and nested sends,
message copying/filtering/discard/single use, paint output and exception
cleanup, GDI lifetime/state/stock guards, timers/cancellation, callback
exceptions, failed creation, unsupported selections/stale windows, default
close/destruction and signed quit status. Provider-specific tests additionally
cover raw ABI facts and capability limits outside this common surface.

`sdl-driver.sml` independently tests the SDL projection using real SDL calls
and SML observation hooks, without handwritten native call descriptors. Run
`make test-win32-sdl-driver` with a provisioned native SDL library (or set
`RUNE_SDL_NATIVE_LIBRARY`). The GUI tier is `test-win32-sdl-driver-gui` and
requires desktop access. The test helper reads `ffi/sdl/support.json`, generates
all required constants and adapters, and checks both interpreters under GC
stress plus baseline and optimizing JIT modes.

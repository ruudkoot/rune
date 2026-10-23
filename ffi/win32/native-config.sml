(* Explicit adapter path; system libraries are resolved by the Windows loader. *)
structure NativeWin32Config : WIN32_NATIVE_CONFIG =
struct
  val adapters=case OS.Process.getEnv "RUNE_WIN32_ADAPTER_LIBRARY" of
    SOME path=>path | NONE=>raise Fail "set RUNE_WIN32_ADAPTER_LIBRARY to the generated target shim DLL"
  val session=Win32GeneratedRaw.openSession{libraries=["kernel32.dll","user32.dll","gdi32.dll",adapters]}
  val prepare=Win32GeneratedRaw.prepare session
  val sizeOf=Win32GeneratedLayout.sizeOf
  val offset=Win32GeneratedLayout.offset
  val constant=Win32GeneratedLayout.constant
  fun close()=Win32GeneratedRaw.closeSession session
end
structure Win32Native=Win32NativeFn(NativeWin32Config)

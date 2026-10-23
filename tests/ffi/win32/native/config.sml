(* Faults are private to this native fixture configuration, never primitives. *)
structure NativeWin32Faults =
struct
  exception Injected
  val pending=ref(NONE:(string * int) option)
  fun arm(name,skip)=pending:=SOME(name,skip)
  fun beforePrepare name=case !pending of SOME(selected,skip)=>
      if selected<>name then () else if skip>0 then pending:=SOME(selected,skip-1)
      else (pending:=NONE;raise Injected)
    | NONE=>()
end
structure NativeWin32Config : WIN32_NATIVE_CONFIG =
struct
  val session=Win32GeneratedRaw.openSession{libraries=["kernel32.dll","user32.dll","gdi32.dll",hd(CommandLine.arguments())]}
  fun prepare name=(NativeWin32Faults.beforePrepare name;Win32GeneratedRaw.prepare session name)
  val sizeOf=Win32GeneratedLayout.sizeOf
  val offset=Win32GeneratedLayout.offset
  val constant=Win32GeneratedLayout.constant
  fun close()=Win32GeneratedRaw.closeSession session
end

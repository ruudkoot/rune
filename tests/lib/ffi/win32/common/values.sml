(* libraries: test/unit *)
structure Win32ValuesTests =
struct
  structure SignatureCheck : WIN32_VALUES = Win32Values
  fun test name body=Test.it name(fn()=>Expect.that(name,body()))
  val tests=Test.describe "ffi/win32/common/values"
    [test "low word zero"(fn()=>Win32Values.lowWord 0w0=Word16.fromInt 0),
     test "low word unsigned boundary"(fn()=>Win32Values.lowWord 0wxFFFFFFFFFFFFFFFF=Word16.fromInt 65535),
     test "high word discards pointer-width upper bits"(fn()=>Win32Values.highWord 0wxFEDCBA9876543210=Word16.fromInt 30292),
     test "low word preserves low bits"(fn()=>Win32Values.lowWord 0wxFEDCBA9876543210=Word16.fromInt 12816),
     test "RGB byte order"(fn()=>Win32Values.rgb{red=0wx12,green=0wx34,blue=0wx56}=0wx563412),
     test "RGB zero"(fn()=>Win32Values.rgb{red=0w0,green=0w0,blue=0w0}=0w0),
     test "RGB maximum"(fn()=>Win32Values.rgb{red=0w255,green=0w255,blue=0w255}=0wxFFFFFF),
     test "red ignores upper flags"(fn()=>Win32Values.red 0wxFEDCBA98=0wx98),
     test "green ignores upper flags"(fn()=>Win32Values.green 0wxFEDCBA98=0wxBA),
     test "blue ignores upper flags"(fn()=>Win32Values.blue 0wxFEDCBA98=0wxDC),
     test "x LPARAM signed minimum"(fn()=>Win32Values.xFromLParam (Int64.fromLarge(32768:IntInf.int))= ~32768),
     test "x LPARAM negative one"(fn()=>Win32Values.xFromLParam (Int64.fromLarge(~1:IntInf.int))= ~1),
     test "x LPARAM signed maximum"(fn()=>Win32Values.xFromLParam (Int64.fromLarge(32767:IntInf.int))=32767),
     test "y LPARAM signed minimum"(fn()=>Win32Values.yFromLParam (Int64.fromLarge(2147483648:IntInf.int))= ~32768),
     test "y LPARAM ignores high pointer bits"(fn()=>Win32Values.yFromLParam (Int64.fromLarge(4294934528:IntInf.int))= ~1),
     test "y LPARAM signed maximum"(fn()=>Win32Values.yFromLParam (Int64.fromLarge(2147418112:IntInf.int))=32767),
     test "macro signature"(fn()=>SignatureCheck.lowWord 0w0=Word16.fromInt 0)]
end
structure Win32ValuesMain=Main(struct val name="ffi/win32/common/values" val tests=Win32ValuesTests.tests end)
val ()=Win32ValuesMain.main()

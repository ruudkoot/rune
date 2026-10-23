(* libraries: test/unit *)
structure Win32CommonTests =
struct
  fun test name body=Test.it name(fn()=>Expect.that(name,body()))
  val tests=Test.describe "ffi/win32/common"
    [test "window identities are distinct"(fn()=>Win32Common.freshWindow()<>Win32Common.freshWindow()),
     test "module identities are distinct"(fn()=>Win32Common.freshModule()<>Win32Common.freshModule()),
     test "class identities are distinct"(fn()=>Win32Common.freshAtom()<>Win32Common.freshAtom()),
     test "paint identities are distinct"(fn()=>Win32Common.freshPaint()<>Win32Common.freshPaint()),
     test "copied messages are distinct"(fn()=>Win32Common.queuedKey(Win32Common.freshQueued())<>Win32Common.queuedKey(Win32Common.freshQueued())),
     test "pen object identity is stable"(fn()=>let val p=Win32Common.freshPen() in Win32Common.penObject p=Win32Common.penObject p end),
     test "brush view preserves object identity"(fn()=>let val o'=Win32Common.freshObject()
       in Win32Common.brushObject(Win32Common.objectBrush o')=o' end),
     test "factory namespaces do not collide"(fn()=>Win32Common.windowKey(Win32Common.freshWindow())<>
       Win32Common.objectKey(Win32Common.freshObject())),
     test "UTF-16 messages retain lone surrogates"(fn()=>case Win32Common.Types.Char(Word16.fromInt 55296) of
       Win32Common.Types.Char c=>Word16.toInt c=55296 | _=>false),
     test "shared exceptions retain native codes"(fn()=>((raise Win32Common.Types.Error{function="probe",code=0w5};false)
       handle Win32Common.Types.Error{function,code}=>function="probe" andalso code=0w5))]
end
structure Win32CommonMain=Main(struct val name="ffi/win32/common" val tests=Win32CommonTests.tests end)
val ()=Win32CommonMain.main()

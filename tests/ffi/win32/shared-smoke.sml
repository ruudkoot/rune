(* libraries: test/unit *)
structure Win32ModelSmoke =
struct
  structure W=Win32Mock
  val trace=ref([]:W.Types.message list)
  fun procedure(_,message)=(trace:=message:: !trace;W.Types.Default)
  val module=W.Kernel.getModuleHandle NONE
  val class=W.User.registerClassEx{name="model-smoke",instance=module,style=0w3,procedure=procedure}
  val window=W.User.createWindowEx{class=class,instance=module,title="mock",style=0wxCF0000,extendedStyle=0w0,
    x=0,y=0,width=320,height=200,parent=NONE}
  val ()=W.User.destroyWindow window
  val ()=W.User.unregisterClass(class,module)
  val ()=if length(!trace)=4 then print "PASS shared Win32 mock creation/destruction\n" else raise Fail "lifecycle"
end

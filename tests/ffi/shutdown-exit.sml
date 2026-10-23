(* Process exit may occur inside a callback, with native callers suspended.
   The provider destructor verifies entry is disabled and retained context
   memory is still valid; vm_exit must preserve those active VM roots. *)
val provider=RuneForeign.openLibrary(hd(CommandLine.arguments()))
fun prepare name result arguments=RuneForeign.prepare{
  symbol=RuneForeign.symbol(provider,name),abi=0,result=result,arguments=arguments}
val register=prepare "rf_shutdown_register" RuneForeign.Void [RuneForeign.Pointer,RuneForeign.Pointer]
val expectExit=prepare "rf_shutdown_expect_exit" RuneForeign.Void []
val apply=prepare "rf_shutdown_apply" RuneForeign.SInt32 []
val memory=RuneForeign.allocate 0w4
val bytes=Word8Array.array(4,0w0)
val ()=PackWord32Little.update(bytes,0,0w1234)
val ()=RuneForeign.write(memory,0w0,Byte.bytesToString(Word8Array.vector bytes))
val callback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.Pointer,RuneForeign.SInt32],
  failure=RuneForeign.ByArgument{index=1,cases=[(0w129,RuneForeign.Signed 0),(0w1,RuneForeign.Signed ~1)],default=RuneForeign.Signed ~77},
  function=fn _=>OS.Process.exit OS.Process.success}
val _=RuneForeign.invoke(register,[RuneForeign.Address(SOME callback),RuneForeign.Address(SOME memory)])
val _=RuneForeign.invoke(expectExit,[])
val _=RuneForeign.invoke(apply,[])
val ()=raise Fail "callback exit returned"

(* Existing native-code execution uses the same generic dynamic bridge. *)
val library=RuneForeign.openLibrary(hd(CommandLine.arguments()))
val symbol=RuneForeign.symbol(library,"gen_add")
val prepared=RuneForeign.prepare{symbol=symbol,abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.SInt32,RuneForeign.SInt32]}
val answer=RuneForeign.invoke(prepared,[RuneForeign.Signed(Int64.fromInt 20),RuneForeign.Signed(Int64.fromInt 22)])
val ()=if #bytes answer="\042\000\000\000\000\000\000\000" then () else raise Fail "wrong native scalar result"
val ()=List.app RuneForeign.release[prepared,symbol,library]
val ()=if RuneForeign.live()=0w0 then print "PASS relocated native FFI runtime\n" else raise Fail "live native resources"

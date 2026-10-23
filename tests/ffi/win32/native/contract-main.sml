structure NativeSharedContract=Win32ContractFn(structure Win32=Win32Native val name="native")
val nativeSharedSummary=Suite.run{args=[],print=fn message=>(TextIO.output(TextIO.stdErr,message);TextIO.flushOut TextIO.stdErr)}NativeSharedContract.tests
val ()=Win32Native.close()
val ()=if RuneForeign.live()=0w0 then print "PASS native contract resources closed\n" else raise Fail "native contract resources"
val ()=if #failed nativeSharedSummary=0 then () else OS.Process.exit OS.Process.failure

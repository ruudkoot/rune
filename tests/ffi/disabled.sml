val () = if RuneForeign.available () then raise Fail "FFI should be disabled" else ()
val () = if List.exists(fn n=>n= #pointerBytes(RuneForeign.target()))[4,8] then () else raise Fail "disabled target facts"
val facts=RuneForeign.abiFacts()
val ()=if #charBits facts=8 andalso List.length(#scalars facts)=10 then () else raise Fail "disabled C ABI facts"
val () = if RuneForeign.live () = 0w0 then () else raise Fail "disabled registry"
val failed = ((ignore (RuneForeign.openLibrary "missing-library"); false)
  handle RuneForeign.Error {number, ...} => number <> 0)
val callbackFailed = ((ignore(RuneForeign.callback{abi=0,result=RuneForeign.SInt8,arguments=[],
  failure=RuneForeign.Default(RuneForeign.Signed 0),function=fn _=>RuneForeign.Signed 1});false)
  handle RuneForeign.Error {number,...}=>number<>0)
val ()=if callbackFailed andalso RuneForeign.live()=0w0 then Runtime.collect()
  else raise Fail "disabled callbacks must reject without resources"
val () = if failed then print "PASS foreign disabled: deterministic availability error\n" else raise Fail "missing unavailable error"

val () = if RuneForeign.available () then raise Fail "FFI should be disabled" else ()
val () = if List.exists(fn n=>n= #pointerBytes(RuneForeign.target()))[4,8] then () else raise Fail "disabled target facts"
val () = if RuneForeign.live () = 0w0 then () else raise Fail "disabled registry"
val failed = ((ignore (RuneForeign.openLibrary "missing-library"); false)
  handle RuneForeign.Error {number, ...} => number <> 0)
val () = if failed then print "PASS foreign disabled: deterministic availability error\n" else raise Fail "missing unavailable error"

open Foreign
val library = loadLibrary (valOf (OS.Process.getEnv "RUNEFFI_FIXTURE"))
fun symbol name = getSymbol library name
fun check true = () | check false = raise Fail "Poly/ML comparison"
val echo = buildCall1 (symbol "rf_i64", cInt64Large, cInt64Large)
val () = check (echo ~9223372036854775808 = ~9223372036854775808)
val pairType = cStruct2 (cInt32, cDouble)
val pair = buildCall2 (symbol "rf_make_pair", (cInt32, cDouble), pairType)
val (integer, fraction) = pair (39, 3.5)
val () = check (integer = 39 andalso Real.== (fraction, 3.5))
val copy = buildCall1 (symbol "rf_copy", cString, cPointer)
val free = buildCall1 (symbol "rf_free", cPointer, cVoid)
val allocations = buildCall0 (symbol "rf_allocations", (), cUlong)
val pointer = copy "owned"
val () = check (allocations () = 1)
val () = free pointer
val () = check (allocations () = 0)
val callback = buildClosure2 (fn (_, n) => n + 20, (cPointer, cInt), cInt)
val register = buildCall2 (symbol "rf_set_callback", (cFunction, cPointer), cVoid)
val invoke = buildCall1 (symbol "rf_invoke", cInt, cInt)
val () = register (callback, Memory.null)
val () = check (invoke 22 = 42)
(* Unregister using the raw pointer conversion; release the retained closure
   only once C no longer holds it. *)
val unregister = buildCall2 (symbol "rf_set_callback", (cPointer, cPointer), cVoid)
val () = unregister (Memory.null, Memory.null)
val () = check (invoke 22 = ~1)
val () = print "PASS ffi/research/polyml: scalar, struct, owned string, retained callback\n"

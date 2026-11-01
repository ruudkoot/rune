(* A tuple cast to a function and called in a function, where its register
   is declared ptr: tier 2 trusts that for the closure, so that no kind is
   tested, and still tests the function index it reads, so that the call
   stops with "bad function index" and goes nowhere (the linting roadmap's
   D8; tests/runner/oracles.sml, call-index) *)
fun call (f : int -> int) = f 3 + 1
val () = print (Int.toString (call (RuneDynamic.cast (1000000, 0))) ^ "\n")

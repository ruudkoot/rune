(* A tuple cast to a function and called in a function, where its register
   is declared ptr: tier 2 trusts that for the closure, so that no kind is
   tested, and still tests the function index it reads, so that the call
   goes nowhere (the linting roadmap's D8; tests/runner/oracles.sml,
   call-index). An index out of range in a call of one argument goes to the
   general path since D15's C (the haskell98 roadmap), which tests the kind
   and stops with "expected closure in call" *)
fun call (f : int -> int) = f 3 + 1
val () = print (Int.toString (call (RuneDynamic.cast (1000000, 0))) ^ "\n")

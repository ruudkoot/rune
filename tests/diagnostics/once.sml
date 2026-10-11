(* A declaration that fails the check of free type variables is reported
   once: not again where each later top-level declaration ends, as the
   recovery of errors did (docs/plans/repl.md, M8). *)
fun f 0 = raise Fail "z" | f n = f (n - 1);
val y = f 2;
val z = 1;

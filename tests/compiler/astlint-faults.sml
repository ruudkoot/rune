(* AstLint's negative tests (the linting roadmap's M12; tests/runner/
   tools.sml, compiler/astlint-faults): a program with a datum of every
   kind AstLint reads, which RUNE_ASTLINT_FAULT=KIND corrupts one kind at a
   time, as AstLint reads it -- each must stop the compile with its rule's
   message, and none the program itself. Compiled without the Basis
   (--no-prelude), so that the first datum of a kind is the program's *)
datatype t = A | B of int
fun f (B _) = 1
  | f A = 0
fun g [] = raise Match
  | g (x :: _) = x
val 'a id = fn (x : 'a) => x
fun h {a, ...} = a + 1
val n = f (B 2) + g [3] + h {a = 4, b = "x"} + #1 (5, 6)
val m = id n
structure S : sig val v : int end = struct val v = 1 end
functor F (X : sig type u val w : int end) = struct val y = X.w end
structure R = F (struct type u = int -> int val w = 2 end)

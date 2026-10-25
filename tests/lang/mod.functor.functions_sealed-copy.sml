(* --functors=functions with the expansion: a datatype of F's body over a
   structure F seals (I :> S), F applied in G's body, and G, whose result
   hides the instance, applied at two types. The expansion makes one copy
   of F's datatype for both applications of G, so --lint after expand finds
   a constructor's argument of the one type where the other is wanted (at
   -O1 and -O2, whole and in units). It prints right; with I not sealed, or
   G's result not ascribed, the lint is clean (found by the generated
   functor programs, docs/testing.md) *)
signature S = sig type t val mk : int -> t val obs : t -> int end
functor F (X : S) : S = struct
  structure I :> S = X
  datatype t = C of I.t | N
  fun mk n = if n = 0 then N else C (I.mk n)
  fun obs N = ~1 | obs (C v) = I.obs v
end
functor G (X : S) : sig val probe : int -> int end = struct
  structure J = F (X)
  fun probe n = J.obs (J.mk n)
end
structure P = G (struct type t = int * int fun mk n = (n, n * 10) fun obs (a, b) = a + b end)
structure Q = G (struct type t = real fun mk n = real n fun obs r = Real.floor r * 7 end)
val () = print (String.concatWith " " (List.map (fn n => Int.toString (P.probe n) ^ "/" ^ Int.toString (Q.probe n)) [0, 1, 2]) ^ "\n")

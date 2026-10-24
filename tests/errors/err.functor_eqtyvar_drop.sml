(* Rule 54, as tests/lang/mod.functor_eqtyvar (the deviation Functors,
   corner (c)), with an argument whose t drops its parameter: F's signature
   has same : ''a * ''a -> bool, so S.same (1.5, 2.5) needs real to admit
   equality. Refused in every mode: a compile retypes the copy of the body
   by the signature where a type of the argument drops a parameter *)
functor F (X : sig eqtype 'a t val mk : 'a -> 'a t end) =
struct fun same (a, b) = X.mk a = X.mk b end
structure S = F (struct type 'a t = int fun mk _ = 0 end)
val b = S.same (1.5, 2.5)
val _ = print (if b then "true\n" else "false\n")

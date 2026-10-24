(* The equality of a type variable lost by a functor's application: the
   corner (c) of the deviation Functors (docs/language.md), until functors
   are compiled once (docs/plans/functors-units.md, M3 and M7).
   The Definition REJECTS it. In the body X.t is a type name that admits
   equality, of arity 1, so `X.mk a = X.mk b` needs 'a X.t to admit
   equality, which it does where 'a does (Section 4.4): F's signature
   (rule 86) has same : ''a * ''a -> bool. Rule 54 types S.same by it,
   whatever the argument's t -- here ref, under which every 'a ref admits
   equality -- so S.same (1.5, 2.5) needs real to admit equality.
   A compile ACCEPTS it and prints false, a deviation: the copy of the body
   that the application elaborates for its code has same : 'a * 'a -> bool,
   and its retyping by the signature does not compare the equality of type
   variables. --typecheck-only, which makes no copy, REJECTS it, as the
   Definition does (.typecheck-error). *)
functor F (X : sig eqtype 'a t val mk : 'a -> 'a t end) =
struct fun same (a, b) = X.mk a = X.mk b end
structure S = F (struct type 'a t = 'a ref fun mk x = ref x end)
val b = S.same (1.5, 2.5)
val _ = print (if b then "true\n" else "false\n")

(* The equality of a type variable through a functor's application, which
   a compile lost while it typed an application by a copy of the body
   (docs/plans/functors-units.md, corner (c), closed by M7).
   The Definition REJECTS it, and so does every mode now. In the body X.t
   is a type name that admits equality, of arity 1, so `X.mk a = X.mk b`
   needs 'a X.t to admit equality, which it does where 'a does (Section
   4.4): F's signature (rule 86) has same : ''a * ''a -> bool. Rule 54
   types S.same by it, whatever the argument's t -- here ref, under which
   every 'a ref admits equality -- so S.same (1.5, 2.5) needs real to admit
   equality. The copy of the body that a compile elaborated for its code
   had same : 'a * 'a -> bool, and printed false. *)
functor F (X : sig eqtype 'a t val mk : 'a -> 'a t end) =
struct fun same (a, b) = X.mk a = X.mk b end
structure S = F (struct type 'a t = 'a ref fun mk x = ref x end)
val b = S.same (1.5, 2.5)
val _ = print (if b then "true\n" else "false\n")

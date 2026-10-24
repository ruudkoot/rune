(* A word constant and operator of a functor's body settled by its client:
   the corner (a) of the deviation Functors (docs/language.md), until
   functors are compiled once (docs/plans/functors-units.md, M3 and M7).
   The Definition REJECTS it. Appendix E gives 0w1 and + the default type
   word in `fun inc w = w + 0w1`, the body's declaration (rule 86): the
   functor's signature has inc : word -> word, rule 54 types T.inc by it,
   and the annotation Word8.word is a type error.
   A compile ACCEPTS it, a deviation that changes what it computes: the copy
   of the body that the application elaborates for its code takes inc at
   Word8.word, where 0w255 + 0w1 wraps to 0 (at word it is 256, 100 in
   hexadecimal). --typecheck-only, which makes no copy, REJECTS it, as the
   Definition does (.typecheck-error). *)
functor F () = struct fun inc w = w + 0w1 end
structure S = struct
  structure T = F ()
  val x : Word8.word = T.inc 0w255
end
val _ = print (Word8.toString S.x ^ "\n")

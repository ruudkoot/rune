(* A word constant and operator of a functor's body, which a compile left
   to its client while it typed an application by a copy of the body
   (docs/plans/functors-units.md, corner (a), closed by M7).
   The Definition REJECTS it, and so does every mode now. Appendix E gives
   0w1 and + the default type word in `fun inc w = w + 0w1`, the body's
   declaration (rule 86): the functor's signature has inc : word -> word,
   rule 54 types T.inc by it, and the annotation Word8.word is a type
   error. The copy of the body took inc at Word8.word, where 0w255 + 0w1
   wrapped to 0 (at word it is 256). *)
functor F () = struct fun inc w = w + 0w1 end
structure S = struct
  structure T = F ()
  val x : Word8.word = T.inc 0w255
end
val _ = print (Word8.toString S.x ^ "\n")

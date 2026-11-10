(* A generator of Core programs (the haskell98 roadmap, D55, its second
   generator): well-typed lazy programs in Pałka's shape, a function from a
   list of `Int` to another, made of `map`, `take`, `let`, `letrec`, `case`
   and forcing, applied to a partial list, one with a bottom for an element
   or its tail, and its result printed to twenty elements.

   A program it makes passes CoreLint and runs to an outcome, a value or a
   bottom, so that the text, the check, the interpreter and, later, the VM
   can be held to each other on what nobody wrote by hand.

   Area: Languages *)
signature CORE_GEN =
sig
  (* `program seed` is the program of `seed`: the same for the same seed. *)
  val program : int -> Core.program
end

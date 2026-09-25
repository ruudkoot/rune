(* dump: -O0 --dump-after=stack *)
(* -O0: the stages with no optional pass. A function of a pair is its
   argument taken apart and the primitive applied, the parts kept on the
   stack where they are used once, in order. *)
fun add (a, b) = a + b

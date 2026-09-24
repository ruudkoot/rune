(* dump: --dump-after=mid *)
(* Lambda made Mid: the top level split into definitions -- a function, a
   value, and a pattern binding done for its effect, which sets its
   globals; a match's rules as join points without parameters; what follows
   an expression that branches (the handle) a join point with its value as
   the parameter, which the handled expression jumps to out of the handler's
   region, and the handler too; a polymorphic function abstracting over its
   type variables, and each use giving the types it is used at. *)
fun first (x, _) = x
val (a, b) = (first (1, "one"), first ("two", 2))
fun len [] = 0
  | len (_ :: rest) = 1 + len rest
exception E of int
fun safe n = 1 + ((if n = 0 then raise E n else n) handle E k => k)
val total = safe 0 + len [a]

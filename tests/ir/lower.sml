(* dump: --passes= --dump-after=lower *)
(* Mid made Low: each function its blocks in SSA; a closure made
   explicitly, capturing y (env 0); a call of a function of the top level a
   known call (callk), which passes no closure, while the closure adder
   returns is called through it (call); count calls itself in tail
   position, so it is a loop: its entry jumps to its head (b1), whose
   parameter is the argument, and its call of itself jumps back there; a match on a constructor one iftag; the handle a
   push, its region, and the handler's block, whose parameter is the
   exception; the value of the if the parameter of the block after it. *)
fun adder y = fn x => x + y
fun count (n, acc) = if n = 0 then acc else count (n - 1, acc + 1)
fun first [] = 0
  | first (x :: _) = x
val safe = (first [] div 0) handle Div => ~1
val pick = (if safe > 0 then adder 1 else adder 2) 3

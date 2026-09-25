(* dump: --passes= --dump-after=lower *)
(* Mid made Low: each function its blocks in SSA; a closure made
   explicitly, capturing y (env 0), and the recursive function reading
   itself (self); a match on a constructor one iftag; the handle a push,
   its region, and the handler's block, whose parameter is the exception;
   the value of the if the parameter of the block after it. *)
fun adder y = fn x => x + y
fun count (n, acc) = if n = 0 then acc else count (n - 1, acc + 1)
fun first [] = 0
  | first (x :: _) = x
val safe = (first [] div 0) handle Div => ~1
val pick = (if safe > 0 then adder 1 else adder 2) 3

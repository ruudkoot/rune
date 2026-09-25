(* dump: --passes=shake,workers,simplify --dump-after=simplify *)
(* Workers and wrappers: count and swap take tuples they only take apart,
   so each gets a worker of two parameters (g1, g2), which every call calls
   -- count's own call of itself too, in tail position -- and a wrapper,
   the function as it was, for a use as a value: swap's is kept (g3),
   count's, which nothing names, goes. The simplifier then finds the fields
   where the tuples are made, and makes none. first uses its tuple whole,
   and keeps it. apply is curried: its worker (g5) takes f and x, and apply
   swap (3, 4), given both, calls it with swap's wrapper and the pair,
   making no partial application; its wrapper goes too. *)
fun count (n, acc) = if n = 0 then acc else count (n - 1, acc + 1)
fun swap (a, b) = (b, a)
fun first (p : int * int) = (#1 p, p)
fun apply f x = f x
val r = (count (10, 0), swap (1, 2), apply swap (3, 4), first (5, 6))

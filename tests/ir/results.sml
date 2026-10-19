(* dump: --passes=shake,workers,simplify,results --dump-after=lower *)
(* Results in globals (performance M8): `div2` returns a pair made there,
   and every call takes its fields, so it returns the first and sets a
   global to the second (setglobal), which the call reads at once (slot):
   the pair is not made. `find` returns an option made there, to calls that
   only ask its constructor and take its argument: it returns the tag as a
   nullary constructor's, and the argument in a global, which the program
   sets to () before anything runs. *)
datatype 'a option = NONE | SOME of 'a
fun div2 (n : int) = (n div 2, n mod 2)
fun find (k : int, l : (int * int) list) =
  case l of
    [] => NONE
  | (k', v) :: rest => if k = k' then SOME v else find (k, rest)
fun f n = let val (q, r) = div2 n in q + r end
fun g n = case find (n, [(1, 10), (2, 20)]) of NONE => 0 | SOME v => v
val r = (f 7, g 2, g 3)

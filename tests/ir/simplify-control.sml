(* dump: --passes=shake,simplify --dump-after=simplify *)
(* Control the simplifier makes branches of: in f, andalso and orelse leave
   a join point that tests its parameter, which two of the jumps give a
   constant -- so it is a join point for each branch (j1, j2), those jumps
   go straight to theirs, and the one that gives c is put where it is as a
   test of c; in g, the raise in the handler's region is a jump to the
   handler, which is a join point, and the handler of the region jumps to
   it too. *)
exception E
fun f (a, b, c) = if a andalso (b orelse c) then 1 else 2
fun g x = (if x = 0 then raise E else x + 1) handle E => 7
val r = (f (true, false, true), g 3)

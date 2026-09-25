(* dump: --passes=shake --dump-after=shake *)
(* A global bound to another is the other at every use, at the types the
   use gives it (M12): T.g, an alias of S.f through two structures, is S.f
   where it is called, and the aliases, which nothing uses then, go. *)
structure S = struct fun f (x : 'a) = [x] end
structure T = struct val g = S.f end
structure U = struct val h = T.g end
val y = U.h 2
val z = U.h "two"

(* Traces under --functors=functions (the review of M6, finding 4): the
   copy the expansion gives an application leaves the frames its call
   leaves at -O0, at every level -- the functor's function (functor F)
   called where the application is, and the body's functions named by the
   functor (F.leaf), in a copy as in the function -- and a definition of
   the top level makes no tail call, a copy's or not. *)
fun show ({function, file, line, ...} : Runtime.frame) =
  print (function ^ " " ^ file ^ ":" ^ Int.toString line ^ "\n")
fun trace () = (List.app show (Runtime.trace ()); print "--\n")

signature S = sig val n : int end
functor F (X : S) = struct
  fun leaf k = (trace (); k + X.n)
  fun deep k = leaf (k + 1) + 1
  val v = deep 0
  val w = leaf 1
end
structure A = F (struct val n = 1 end)

(* an application in a body, expanded in the copy of that body *)
functor G (Y : S) = struct
  structure B = F (struct val n = Y.n + 1 end)
  val u = B.deep 2
end
structure C = G (struct val n = 3 end)

fun top k = A.leaf k
val t = top 5
val () = print (Int.toString (A.v + A.w + C.u + t) ^ "\n")

fun boom k = if k > 0 then raise Fail ("boom " ^ Int.toString k) else k
functor H (X : S) = struct
  val () = print "H\n"
  val v = boom X.n + 1
end
structure D = H (struct val n = 7 end)

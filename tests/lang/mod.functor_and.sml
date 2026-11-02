(* Functors declared together, whose bodies have records of the same slots --
   none, where a parameter has types alone: neither names the other's
   parameter. *)
signature S = sig type t end
functor F (X : S) = X and G (Y : S) = Y
signature V = sig val x : int end
functor H (X : V) = struct val a = X.x end and K (Y : V) = struct val a = Y.x + 1 end
functor L (X : S) = struct type u = X.t end and M (Y : S) = struct type v = Y.t end
structure A = H (struct val x = 1 end)
structure B = K (struct val x = 2 end)
structure C = F (struct type t = int end)
structure D = G (struct type t = int end)
structure E = L (struct type t = int end)
structure I = M (struct type t = int end)
val y : C.t = 3
val z : D.t = 4
val u : E.u = 5
val v : I.v = 6
val () = print (Int.toString (A.a + B.a + y + z + u + v) ^ "\n")

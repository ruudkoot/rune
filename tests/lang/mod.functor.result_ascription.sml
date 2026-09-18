signature S = sig type t val x : t val show : t -> string end
functor Tr (V : sig val v : int end) : S where type t = int =
struct type t = int val x = V.v val show = Int.toString val secret = 0 end
functor Op (V : sig val v : int end) :> S =
struct type t = int val x = V.v fun show n = Int.toString (n + 1) end
structure A = Tr (val v = 1)
structure B = Op (val v = 2)
val () = print (A.show (A.x + 1) ^ " " ^ B.show B.x ^ "\n")

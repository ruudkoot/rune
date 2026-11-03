(* A virtual functor's applications are typed by its signature alone: each
   makes a new set, though the argument is the same *)
signature ORD = sig type t val compare : t * t -> order end
signature SET = sig type elem type set val empty : set val add : set * elem -> set end
functor Set = _virtual (O : ORD) : SET where type elem = O.t
structure Key = struct type t = int val compare = Int.compare end
structure A = Set (Key)
structure B = Set (Key)
val s = A.add (B.empty, 1)

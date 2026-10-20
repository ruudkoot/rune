(* rule 54: an application is typed by the functor's signature, in which d
   was fixed at the declaration as not admitting equality, since t is a
   plain type of the parameter; that the argument's t is int changes
   nothing (docs/plans/functors.md, What the Definition says) *)
functor F (type t) = struct datatype d = D of t end
structure S = F (type t = int)
val b = S.D 1 = S.D 1
